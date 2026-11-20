#!/bin/sh
# Bluebox hooks for Claude Code: the bluebox CLI's hook commands when it has them, else this script, which makes no network call.
LC_ALL=C
export LC_ALL
here=$(dirname "$0")
tab=$(printf '\t')
input=$(cat)

case $(printf '%s' "${CLAUDE_PLUGIN_OPTION_HOOKS_ENABLED:-true}" | tr 'A-Z' 'a-z') in
false | 0 | no | off) exit 0 ;;
esac

json() {
	printf '%s\n' "$input" | fold -b -w 2048 | BLUEBOX_YAML="$here/nudges.yaml" awk -v mode="$1" -v shown="${2-}" -f "$here/bluebox-hook.awk"
}

event='' source='' session='' cwd=''
while IFS=$tab read -r k v; do
	case $k in
	hook_event_name) event=$v ;;
	source) source=$v ;;
	session_id) session=$v ;;
	cwd) cwd=$v ;;
	esac
done <<EOF
$(json fields)
EOF

case $event in
SessionStart)
	sub=session-start
	[ "$source" = startup ] || exit 0
	;;
UserPromptSubmit) sub=prompt ;;
*) exit 0 ;;
esac

if command -v bluebox >/dev/null 2>&1 && tmp=$(mktemp -d 2>/dev/null); then
	# A hook stopped at its timeout still removes the folder, once the CLI exits.
	trap 'rm -rf "$tmp"' EXIT
	trap 'exit 1' HUP INT TERM
	printf '%s' "$input" | bluebox hooks "$sub" >"$tmp/out" 2>"$tmp/err"
	code=$?
	# Every released CLI without the hooks command prints exactly this line.
	if [ "$code" -ne 1 ] || [ "$(sed -n 1p "$tmp/err" | tr -d '\r')" != "unknown command: hooks" ]; then
		cat "$tmp/out"
		cat "$tmp/err" >&2
		# Exit 2 would block the prompt, which a hook that only adds notes must never do.
		[ "$code" -eq 2 ] && code=1
		exit "$code"
	fi
	rm -rf "$tmp"
	trap - EXIT HUP INT TERM
fi

[ -n "$cwd" ] && [ -d "$cwd" ] || cwd=$PWD
command -v git >/dev/null 2>&1 || exit 0
[ "$(git -C "$cwd" rev-parse --is-inside-work-tree 2>/dev/null)" = true ] || exit 0

state=''
case $session in
'' | *[!A-Za-z0-9_-]*) ;;
*) [ ${#session} -le 128 ] && [ -n "${CLAUDE_PLUGIN_DATA-}" ] && state=$CLAUDE_PLUGIN_DATA/sessions/$session ;;
esac
shown() { [ -n "$state" ] && [ -f "$state" ] && grep -qx "$1" "$state"; }
mark() { [ -n "$state" ] && mkdir -p "${state%/*}" 2>/dev/null && { printf '%s\n' "$1" >>"$state"; } 2>/dev/null; }

if [ "$sub" = prompt ]; then
	[ -n "$state" ] || exit 0
	hit=$(json nudge " $([ -f "$state" ] && tr '\n' ' ' <"$state") ")
	[ -n "$hit" ] || exit 0
	# A nudge that can't be recorded would repeat on every prompt.
	mark "${hit%%"$tab"*}" && printf '%s\n' "${hit#*"$tab"}"
	exit 0
fi

[ -n "${CLAUDE_PLUGIN_DATA-}" ] && [ -d "$CLAUDE_PLUGIN_DATA/sessions" ] &&
	find "$CLAUDE_PLUGIN_DATA/sessions" -type f -mtime +7 -exec rm -f {} + 2>/dev/null

remote=$(git -C "$cwd" remote 2>/dev/null | grep -x origin || git -C "$cwd" remote 2>/dev/null | sed -n 1p)
url=''
[ -n "$remote" ] && url=$(git -C "$cwd" remote get-url "$remote" 2>/dev/null | sed -n 1p | sed -E 's#^([A-Za-z][A-Za-z0-9+.-]*://)[^/]*@#\1#')
# The remote goes to the model, so it is held to URL characters and 300 of them; that doesn't make it a real repo URL.
case $url in
'' | file:* | /* | .* | ?:[\\/]* | *[!A-Za-z0-9._~:/@%+-]*) url='' ;;
*:*) ;;
*) url='' ;;
esac
[ ${#url} -le 300 ] || url=''
[ -n "$url" ] && printf '%s\n' "Bluebox: when a task touches a live service, call the Bluebox MCP tool list_services with repository_url \"$url\" to find the services built from this repository."

# Prints "<up to two names>[ and N more]" for names on stdin, one per line.
names() {
	awk '/^[A-Za-z0-9._-]+$/ && !seen[$0]++ { n++; if (n <= 2) s = s (s ? ", " : "") substr($0, 1, 40) }
		END { if (n > 2) s = s " and " (n - 2) " more"; printf "%s", s }'
}
# Only folders named like a skill this plugin ships are copies of it.
skills() {
	for d in "$1"/bluebox-*; do [ -d "$d" ] && [ -d "$here/../skills/${d##*/}" ] && printf '%s\n' "${d##*/}"; done | names
}

# Claude Code on Windows reads the profile folder, even when Git Bash has a HOME of its own.
home=$HOME
[ -n "${USERPROFILE-}" ] && command -v cygpath >/dev/null 2>&1 && home=$(cygpath -u "$USERPROFILE" 2>/dev/null || printf '%s' "$HOME")
config=${CLAUDE_CONFIG_DIR:-$home/.claude}
project=${CLAUDE_PROJECT_DIR:-$cwd}
label=$config/skills
[ "$config" -ef "$home/.claude" ] && label='~/.claude/skills'
found=''
s=$(skills "$config/skills")
[ -n "$s" ] && found="$s in $(printf '%.80s' "$label")"
if ! [ "$project/.claude" -ef "$config" ]; then
	s=$(skills "$project/.claude/skills")
	[ -n "$s" ] && found="$found${found:+; }$s in .claude/skills"
fi
# Prints what mode $2 of bluebox-hook.awk finds in the JSON file $1.
read_json() {
	[ -f "$1" ] || return 0
	# Paths go through the environment: awk -v would read the backslashes in a Windows path as escapes.
	fold -b -w 2048 <"$1" | BLUEBOX_PROJECT=$project awk -v mode="$2" -f "$here/bluebox-hook.awk"
}
claude_json=${CLAUDE_CONFIG_DIR:-$home}/.claude.json
# Prints the "+name" servers in $1 that no "-name" line in $2 turns off.
loaded() {
	printf '%s\n' "$1" | BLUEBOX_OFF=$2 awk '
		BEGIN { n = split(ENVIRON["BLUEBOX_OFF"], s, "\n"); for (i = 1; i <= n; i++) if (s[i] ~ /^-/) off[substr(s[i], 2)] }
		/^[+]/ && !(substr($0, 2) in off) { print substr($0, 2) }' | names
}
user='' team=''
grep -qi 'bluebox\.ai' "$project/.mcp.json" 2>/dev/null && team=$(read_json "$project/.mcp.json" mcp)
{ [ -n "$team" ] || grep -qi 'bluebox\.ai' "$claude_json" 2>/dev/null; } && user=$(read_json "$claude_json" mcp)
# A server turned off in /mcp, or declined when the project asked, never loads, so it is no duplicate.
servers=''
[ -n "$user" ] && servers=$(loaded "$user" "$user")
[ -n "$team" ] && team=$(loaded "$team" "$user")

if { [ -n "$found" ] || [ -n "$servers" ] || [ -n "$team" ]; } && ! shown duplicates; then
	from='' fix=''
	[ -n "$found" ] && from="npx copies of the Bluebox skills ($found)" fix='delete the npx copies'
	[ -n "$servers" ] && from="$from${from:+ and }a Bluebox MCP server configured by hand ($servers)" fix="$fix${fix:+ and }remove that server with claude mcp remove"
	# The project's .mcp.json is shared, so the fix leaves it alone.
	[ -n "$team" ] && from="$from${from:+ and }a Bluebox MCP server in this project's .mcp.json ($team)" fix="$fix${fix:+ and }turn it off for yourself in /mcp"
	printf '%s\n' "Bluebox: Bluebox is installed twice in this session, by this plugin and as $from. To fix it, $fix, or uninstall the bluebox plugin."
	mark duplicates
fi
exit 0
