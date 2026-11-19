"""Fail when a change to the Claude Code plugin's files leaves its version unchanged.

Claude Code updates an installed plugin only when `version` in .claude-plugin/plugin.json changes.
Usage: python3 .github/scripts/check_plugin_version.py --base <commit> --head <commit> [--repo <dir>]
"""

import argparse
import json
import subprocess
import sys

MANIFEST = ".claude-plugin/plugin.json"
PLUGIN_DIRS = (".claude-plugin/", "hooks/")
PLUGIN_FILES = (".mcp.json",)


def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], check=True, capture_output=True, text=True,
                          encoding="utf-8", stdin=subprocess.DEVNULL).stdout


def plugin_changes(repo, base, head):
    names = git(repo, "diff", "--name-only", "--no-renames", f"{base}..{head}").splitlines()
    return [n for n in names if n.startswith(PLUGIN_DIRS) or n in PLUGIN_FILES]


def version(repo, ref):
    if not git(repo, "ls-tree", "--name-only", ref, "--", MANIFEST).strip():
        return None
    text = git(repo, "show", f"{ref}:{MANIFEST}")
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"FAIL {MANIFEST} at {ref[:12]} is not valid JSON: {exc}")
    return data.get("version") if isinstance(data, dict) else None


def main(argv=None):
    try:
        return check(argv)
    except subprocess.CalledProcessError as exc:
        print(f"FAIL git {' '.join(exc.cmd[3:])}: {exc.stderr.strip()}")
        print("Check that both commits are fetched (actions/checkout with fetch-depth: 0).")
        return 1


def check(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--repo", default=".")
    args = parser.parse_args(argv)
    merge_base = git(args.repo, "merge-base", args.base, args.head).strip()
    changed = plugin_changes(args.repo, merge_base, args.head)
    if not changed:
        print("OK   no plugin files changed")
        return 0
    # Against the branch point the pull request must change it; against the base tip the merge must.
    before, base, after = (version(args.repo, ref) for ref in (merge_base, args.base, args.head))
    if isinstance(after, str) and after not in (before, base):
        print(f"OK   plugin version {base} -> {after}")
        return 0
    print(f"FAIL these plugin files changed, but `version` in {MANIFEST} is {after!r}, not a new string:")
    print("\n".join(f"  {n}" for n in changed))
    print("Change `version` too, or Claude Code will not update installed copies of the plugin.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
