# Bluebox hooks for Claude Code on Windows without Git Bash: the same behavior as bluebox-hook.sh, in PowerShell 5.1 or later.
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false
$stdout = New-Object System.IO.StreamWriter ([Console]::OpenStandardOutput()), $utf8
$stderr = New-Object System.IO.StreamWriter ([Console]::OpenStandardError()), $utf8
$stdout.AutoFlush = $true
$stderr.AutoFlush = $true
$raw = (New-Object System.IO.StreamReader ([Console]::OpenStandardInput()), $utf8).ReadToEnd()
$here = Join-Path $env:CLAUDE_PLUGIN_ROOT 'hooks'

if (@('false', '0', 'no', 'off') -contains "$env:CLAUDE_PLUGIN_OPTION_HOOKS_ENABLED".ToLowerInvariant()) { exit 0 }

# String leaves as (path, value): top-level ones, or those under $leafKey or in an array named in $listKeys; control characters become spaces.
function Get-JsonStrings([string]$text, [string]$leafKey, [string[]]$listKeys) {
    $type = @{}; $key = @{}; $wantKey = @{}; $d = 0
    $leaves = New-Object System.Collections.Generic.List[object]
    foreach ($m in [regex]::Matches($text, '"[^"\\]*(?:\\.[^"\\]*)*"|[{}\[\],:]|[^\s{}\[\],:"]+')) {
        $t = $m.Value
        switch -CaseSensitive ($t[0]) {
            '{' { $d++; $type[$d] = 'o'; $key[$d] = ''; $wantKey[$d] = $true; continue }
            '[' { $d++; $type[$d] = 'a'; $key[$d] = 0; continue }
            '}' { if ($d -gt 0) { $d-- }; continue }
            ']' { if ($d -gt 0) { $d-- }; continue }
            ',' { if ($type[$d] -eq 'o') { $wantKey[$d] = $true } else { $key[$d]++ }; continue }
            ':' { $wantKey[$d] = $false; continue }
            '"' {
                $isKey = $d -gt 0 -and $type[$d] -eq 'o' -and $wantKey[$d]
                # The string goes on the left: an array index there would be a failed int conversion per token.
                if ($isKey -or ($leafKey -and $leafKey -ceq $key[$d]) -or ($listKeys -and $type[$d] -eq 'a' -and $listKeys -ccontains $key[$d - 1]) -or
                    (-not $leafKey -and -not $listKeys -and $d -eq 1)) {
                    $s = $t.Substring(1, $t.Length - 2)
                    if ($s.IndexOf('\') -ge 0) { $s = [regex]::Unescape($s) -replace '[\x00-\x1f]', ' ' }
                    if ($isKey) { $key[$d] = $s }
                    else { $leaves.Add(@{ Path = @(for ($i = 1; $i -le $d; $i++) { [string]$key[$i] }); Value = $s }) }
                }
            }
        }
    }
    , $leaves
}

function Invoke-Git {
    $ErrorActionPreference = 'Continue'
    $out = & $script:git @args 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    @($out)
}

# "<up to two names>[ and N more]", the same as names() in bluebox-hook.sh.
function Join-Names($names) {
    $seen = New-Object System.Collections.Generic.List[string]
    foreach ($n in $names) { if ($n -cmatch '^[A-Za-z0-9._-]+$' -and -not $seen.Contains($n)) { $seen.Add($n) } }
    $shown = @($seen | Select-Object -First 2 | ForEach-Object { if ($_.Length -gt 40) { $_.Substring(0, 40) } else { $_ } })
    $s = $shown -join ', '
    if ($seen.Count -gt 2) { $s += " and $($seen.Count - 2) more" }
    $s
}

function Get-Skills([string]$dir) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return '' }
    $shipped = Join-Path $env:CLAUDE_PLUGIN_ROOT 'skills'
    # Only folders named like a skill this plugin ships are copies of it.
    $names = [string[]]@(Get-ChildItem -LiteralPath $dir -Directory -Filter 'bluebox-*' |
        Where-Object { Test-Path -LiteralPath (Join-Path $shipped $_.Name) -PathType Container } | ForEach-Object { $_.Name })
    [Array]::Sort($names, [StringComparer]::Ordinal)
    Join-Names $names
}

function Test-Bluebox([string]$url) {
    if ($url -notmatch '^https?://([^/?#]+)') { return $false }
    $hostName = ($Matches[1].ToLowerInvariant() -replace '^.*@', '') -replace ':[0-9]*$', ''
    $hostName -eq 'bluebox.ai' -or $hostName.EndsWith('.bluebox.ai')
}

function Get-PathKey([string]$p) { ($p.ToLowerInvariant() -replace '\\', '/').TrimEnd('/') }

# A scalar the way bluebox-hook.awk's trim() reads it: unquoted, 'single' or "double".
function Get-YamlValue([string]$v) {
    $v = $v.Trim()
    if ($v -match '^"(.*)"$' -or $v -match "^'(.*)'$") { $v = $Matches[1] }
    $v
}

try {
    $fields = @{}
    foreach ($leaf in (Get-JsonStrings $raw)) { $fields[$leaf.Path[0]] = $leaf.Value }

    switch -CaseSensitive ($fields['hook_event_name']) {
        'SessionStart' { $sub = 'session-start'; if ($fields['source'] -cne 'startup') { exit 0 } }
        'UserPromptSubmit' {
            $sub = 'prompt'
            # Claude Code submits its own background-task notices as prompts.
            if ("$($fields['prompt'])".TrimStart(' ', "`t", "`r", "`n").StartsWith('<task-notification>', [StringComparison]::Ordinal)) { exit 0 }
        }
        default { exit 0 }
    }

    $cli = Get-Command bluebox -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cli) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $cli.Path
        $psi.Arguments = "hooks $sub"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = $utf8
        $psi.StandardErrorEncoding = $utf8
        # .NET Framework writes a UTF-8 console's BOM into the child's stdin; the same code page with no BOM leaves the console as it was.
        $savedInput = $null
        try {
            $current = [Console]::InputEncoding
            if ($current.CodePage -eq 65001 -and $current.GetPreamble().Length) { $savedInput = $current; [Console]::InputEncoding = $utf8 }
        } catch { $savedInput = $null }
        try { $p = [System.Diagnostics.Process]::Start($psi) }
        finally { if ($savedInput) { try { [Console]::InputEncoding = $savedInput } catch { $stderr.Write("Bluebox hook: $_`n") } } }
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()
        $in = New-Object System.IO.StreamWriter $p.StandardInput.BaseStream, $utf8
        $in.Write($raw)
        $in.Close()
        $p.WaitForExit()
        # Every released CLI without the hooks command prints exactly this line.
        if (-not ($p.ExitCode -eq 1 -and ($errTask.Result -split "`r?`n", 2)[0] -ceq 'unknown command: hooks')) {
            $stdout.Write($outTask.Result)
            $stderr.Write($errTask.Result)
            # Exit 2 would block the prompt, which a hook that only adds notes must never do.
            if ($p.ExitCode -eq 2) { exit 1 }
            exit $p.ExitCode
        }
    }

    $cwd = $fields['cwd']
    if (-not $cwd -or -not (Test-Path -LiteralPath $cwd -PathType Container)) { $cwd = (Get-Location).Path }
    $script:git = (Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Path
    if (-not $script:git) { exit 0 }
    if ((Invoke-Git -C $cwd rev-parse --is-inside-work-tree | Select-Object -First 1) -cne 'true') { exit 0 }

    $state = ''
    $session = "$($fields['session_id'])"
    if ($session -cmatch '^[A-Za-z0-9_-]{1,128}$' -and $env:CLAUDE_PLUGIN_DATA) {
        $state = Join-Path (Join-Path $env:CLAUDE_PLUGIN_DATA 'sessions') $session
    }
    $shown = @()
    if ($state -and (Test-Path -LiteralPath $state)) { $shown = @([IO.File]::ReadAllLines($state)) }
    function Add-Shown([string]$k) {
        if (-not $state) { return $false }
        try {
            [void](New-Item -ItemType Directory -Force -Path (Split-Path $state))
            [IO.File]::AppendAllText($state, "$k`n")
            $true
        } catch { $false }
    }

    if ($sub -eq 'prompt') {
        if (-not $state) { exit 0 }
        $words = { param($s) ' ' + ($s.ToLowerInvariant() -replace '[^a-z0-9]+', ' ') + ' ' }
        $prompt = & $words "$($fields['prompt'])"
        $nudges = New-Object System.Collections.Generic.List[object]
        foreach ($line in [IO.File]::ReadAllLines((Join-Path $here 'nudges.yaml'))) {
            if ($line -match '^\s*-\s*moment:(.*)$') { $n = @{ Moment = (Get-YamlValue $Matches[1]); Text = ''; Keywords = @() }; $nudges.Add($n) }
            elseif ($nudges.Count -and $line -match '^\s*text:(.*)$') { $n.Text = (Get-YamlValue $Matches[1]) -replace '\\"', '"' }
            elseif ($nudges.Count -and $line -match '^\s*keywords:\s*\[(.*)\]\s*$') {
                $n.Keywords = @($Matches[1] -split ',' | ForEach-Object { & $words ($_.Trim().Trim('"', "'")) })
            }
        }
        foreach ($n in $nudges) {
            if (-not $n.Text -or $shown -ccontains $n.Moment) { continue }
            foreach ($k in $n.Keywords) {
                if ($k -match '[a-z0-9]' -and $prompt.Contains($k)) {
                    # A nudge that can't be recorded would repeat on every prompt.
                    if (Add-Shown $n.Moment) { $stdout.Write("$($n.Text)`n") }
                    exit 0
                }
            }
        }
        exit 0
    }

    if ($env:CLAUDE_PLUGIN_DATA) {
        $sessions = Join-Path $env:CLAUDE_PLUGIN_DATA 'sessions'
        if (Test-Path -LiteralPath $sessions) {
            $cutoff = (Get-Date).AddDays(-8)
            Get-ChildItem -LiteralPath $sessions -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $cutoff } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $remotes = @(Invoke-Git -C $cwd remote)
    $remote = if ($remotes -ccontains 'origin') { 'origin' } else { $remotes | Select-Object -First 1 }
    $url = ''
    if ($remote) { $url = "$(Invoke-Git -C $cwd remote get-url $remote | Select-Object -First 1)" -replace '^([A-Za-z][A-Za-z0-9+.-]*://)[^/]*@', '$1' }
    # The remote goes to the model, so it is held to URL characters and 300 of them; that doesn't make it a real repo URL.
    if ($url -cmatch '^(file:|/|\.|.:[\\/])' -or $url -cmatch '[^A-Za-z0-9._~:/@%+-]' -or $url -notmatch ':' -or $url.Length -gt 300) { $url = '' }
    if ($url) { $lines.Add("Bluebox: when a task touches a live service, call the Bluebox MCP tool list_services with repository_url `"$url`", or with search set to the service name if that finds none.") }

    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
    $config = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $homeDir '.claude' }
    $project = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { $cwd }
    $label = if ((Get-PathKey $config) -eq (Get-PathKey (Join-Path $homeDir '.claude'))) { '~/.claude/skills' } else { "$config/skills" }
    if ($label.Length -gt 80) { $label = $label.Substring(0, 80) }
    $found = @()
    $s = Get-Skills (Join-Path $config 'skills')
    if ($s) { $found += "$s in $label" }
    if ((Get-PathKey (Join-Path $project '.claude')) -ne (Get-PathKey $config)) {
        $s = Get-Skills (Join-Path (Join-Path $project '.claude') 'skills')
        if ($s) { $found += "$s in .claude/skills" }
    }
    $found = $found -join '; '

    $claudeJson = if ($env:CLAUDE_CONFIG_DIR) { Join-Path $env:CLAUDE_CONFIG_DIR '.claude.json' } else { Join-Path $homeDir '.claude.json' }
    $projectKey = Get-PathKey $project
    $readJson = { param($f) if (Test-Path -LiteralPath $f -PathType Leaf) { [IO.File]::ReadAllText($f) } else { '' } }
    $userText = & $readJson $claudeJson
    $teamText = & $readJson (Join-Path $project '.mcp.json')
    $names = @(); $team = @(); $off = @()
    if ($teamText -match 'bluebox\.ai') {
        $team = @(foreach ($leaf in (Get-JsonStrings $teamText 'url')) {
            if ($leaf.Path.Count -eq 3 -and $leaf.Path[0] -ceq 'mcpServers' -and (Test-Bluebox $leaf.Value)) { $leaf.Path[1] }
        })
    }
    if ($userText -match 'bluebox\.ai' -or $team.Count) {
        foreach ($leaf in (Get-JsonStrings $userText 'url' @('disabledMcpServers', 'disabledMcpjsonServers'))) {
            $p = $leaf.Path
            if ($p.Count -eq 4 -and $p[0] -ceq 'projects' -and (Get-PathKey $p[1]) -eq $projectKey -and $p[2] -cin 'disabledMcpServers', 'disabledMcpjsonServers') {
                $off += $leaf.Value
            } elseif ((Test-Bluebox $leaf.Value) -and (($p.Count -eq 3 -and $p[0] -ceq 'mcpServers') -or
                ($p.Count -eq 5 -and $p[0] -ceq 'projects' -and (Get-PathKey $p[1]) -eq $projectKey -and $p[2] -ceq 'mcpServers'))) { $names += $p[-2] }
        }
    }
    # A server turned off in /mcp, or declined when the project asked, never loads, so it is no duplicate.
    $servers = Join-Names @($names | Where-Object { $off -cnotcontains $_ })
    $team = Join-Names @($team | Where-Object { $off -cnotcontains $_ })

    if (($found -or $servers -or $team) -and -not ($shown -ccontains 'duplicates')) {
        $from = @(); $fix = @()
        if ($found) { $from += "npx copies of the Bluebox skills ($found)"; $fix += 'delete the npx copies' }
        if ($servers) { $from += "a Bluebox MCP server configured by hand ($servers)"; $fix += 'remove that server with claude mcp remove' }
        # The project's .mcp.json is shared, so the fix leaves it alone.
        if ($team) { $from += "a Bluebox MCP server in this project's .mcp.json ($team)"; $fix += 'turn it off for yourself in /mcp' }
        $lines.Add("Bluebox: Bluebox is installed twice in this session, by this plugin and as $($from -join ' and '). To fix it, $($fix -join ' and '), or uninstall the bluebox plugin.")
        [void](Add-Shown 'duplicates')
    }
    foreach ($l in $lines) { $stdout.Write("$l`n") }
    exit 0
} catch {
    $stderr.Write("Bluebox hook failed: $_`n")
    exit 1
}
