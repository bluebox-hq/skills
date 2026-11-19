# JSON and nudges.yaml reading for bluebox-hook.sh; mode is fields, nudge, mcp or declined, and input comes folded into short lines.

BEGIN {
    d = 0; instr = 0; esc = 0; skip = 0; uni = ""; buf = ""; part = ""
    hex = "0123456789abcdef"
    want["session_id"]; want["hook_event_name"]; want["source"]; want["cwd"]
    yaml = ENVIRON["BLUEBOX_YAML"]; project = ENVIRON["BLUEBOX_PROJECT"]
    if (mode == "nudge") {
        while ((getline line < yaml) > 0) yamlline(line)
        close(yaml)
    }
}

{
    n = split($0, ch, "")
    for (i = 1; i <= n; i++) {
        if (instr && !esc && uni == "") {
            # Jump to the next quote or backslash; concatenating char by char is quadratic in awk.
            if (!match(substr($0, i), /["\\]/)) { if (!skip) part = part substr($0, i); break }
            if (!skip) part = part substr($0, i, RSTART - 1)
            i += RSTART - 1
        }
        feed(ch[i])
    }
    if (instr && !skip) { buf = buf part; part = "" }
}

END { if (mode == "nudge") pick() }

function feed(c) {
    if (instr) {
        if (uni != "") {
            uni = uni c
            if (length(uni) == 5) { part = part codepoint(substr(uni, 2)); uni = "" }
        } else if (esc) {
            esc = 0
            if (c == "u") uni = "u"
            else if (c == "n" || c == "r" || c == "t" || c == "b" || c == "f") part = part " "
            else part = part c
        } else if (c == "\\") esc = 1
        else if (c == "\"") { instr = 0; if (!skip) str(buf part); buf = part = "" }
        return
    }
    if (c == "\"") { instr = 1; buf = part = ""; skip = unwanted() }
    else if (c == "{") { d++; type[d] = "o"; key[d] = ""; wantkey[d] = 1 }
    else if (c == "[") { d++; type[d] = "a"; key[d] = 0 }
    else if (c == "}" || c == "]") { if (d > 0) d-- }
    else if (c == ",") { if (type[d] == "o") wantkey[d] = 1; else key[d]++ }
    else if (c == ":") wantkey[d] = 0
}

# Printable ASCII stays; anything else becomes a space, which no keyword or allowed value contains.
function codepoint(h,    v, k) {
    v = 0
    for (k = 1; k <= 4; k++) v = v * 16 + index(hex, tolower(substr(h, k, 1))) - 1
    return (v >= 32 && v < 127) ? sprintf("%c", v) : " "
}

# A top-level value no mode reads is skipped without being copied.
function unwanted() {
    if (d != 1 || type[1] != "o" || wantkey[1]) return 0
    return mode == "fields" ? !(key[1] in want) : mode == "nudge" ? key[1] != "prompt" : 0
}

function str(s) {
    if (d > 0 && type[d] == "o" && wantkey[d]) { key[d] = s; return }
    if (mode == "fields" && d == 1 && (key[1] in want)) { gsub(/[\t\r\n]/, " ", s); print key[1] "\t" s }
    else if (mode == "nudge" && d == 1 && key[1] == "prompt") prompt = s
    else if (mode == "mcp" && key[d] == "url" && bluebox(s) &&
             ((d == 3 && key[1] == "mcpServers") ||
              (d == 5 && key[1] == "projects" && samepath(key[2], project) && key[3] == "mcpServers")))
        print key[d - 1]
    else if (mode == "declined" && d == 4 && type[4] == "a" && key[1] == "projects" && samepath(key[2], project) &&
             key[3] == "disabledMcpjsonServers")
        print s
}

function bluebox(u,    host) {
    u = tolower(u)
    if (!match(u, /^https?:\/\/[^\/?#]+/)) return 0
    host = substr(u, index(u, "//") + 2, RLENGTH - index(u, "//") - 1)
    sub(/^.*@/, "", host)
    sub(/:[0-9]*$/, "", host)
    return host == "bluebox.ai" || host ~ /\.bluebox\.ai$/
}

function samepath(a, b) {
    a = tolower(a); b = tolower(b)
    gsub(/\\/, "/", a); gsub(/\\/, "/", b)
    sub(/\/+$/, "", a); sub(/\/+$/, "", b)
    return a == b
}

function trim(s) {
    sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s)
    if (s ~ /^".*"$/ || s ~ /^'.*'$/) s = substr(s, 2, length(s) - 2)
    return s
}

function yamlline(line,    k, parts, j) {
    if (match(line, /^[ \t]*-[ \t]*moment:/)) {
        moments++; order[moments] = trim(substr(line, RLENGTH + 1)); kwn[moments] = 0
    } else if (moments && match(line, /^[ \t]*text:/)) {
        text[moments] = trim(substr(line, RLENGTH + 1)); gsub(/\\"/, "\"", text[moments])
    } else if (moments && match(line, /^[ \t]*keywords:[ \t]*\[/)) {
        k = substr(line, RLENGTH + 1); sub(/\][ \t\r]*$/, "", k)
        kwn[moments] = split(k, parts, ",")
        for (j = 1; j <= kwn[moments]; j++) kw[moments, j] = words(trim(parts[j]))
    }
}

function words(s) {
    s = tolower(s); gsub(/[^a-z0-9]+/, " ", s)
    return " " s " "
}

function pick(    p, m, j) {
    p = words(prompt)
    for (m = 1; m <= moments; m++) {
        if (text[m] == "" || index(shown, " " order[m] " ")) continue
        for (j = 1; j <= kwn[m]; j++)
            if (kw[m, j] ~ /[a-z0-9]/ && index(p, kw[m, j])) { print order[m] "\t" text[m]; return }
    }
}
