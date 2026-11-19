# Contributing

## Skills are read-only

The skills under `skills/` are maintained in the Bluebox source and copied to this repository on every Bluebox release. Each copy replaces `skills/` entirely, so **pull requests that change files under `skills/` are not accepted**: the change would be lost on the next release.

To suggest a change to a skill, please [open an issue](https://github.com/bluebox-hq/skills/issues/new) instead. The Bluebox team picks it up and makes the change at the source.

## What you can contribute

Everything outside `skills/` lives only in this repository and welcomes pull requests. For anything beyond a small docs fix, please open an issue first.

## Plugin changes need a new version

Claude Code updates an installed plugin only when `version` in `.claude-plugin/plugin.json` changes. A pull request that changes `.claude-plugin/`, `hooks/`, `assets/` or `.mcp.json` must also change `version`; a CI check enforces this. Add build metadata to the version on `main`, for example `0.1526.0` becomes `0.1526.0+1`, then `0.1526.0+2`. A `-1` suffix would be a semver pre-release, which sorts below `0.1526.0`. A release number would collide with a later Bluebox release, which sets `version` to its own release number.

## Claude Code hooks

The plugin's hooks live in [hooks/](hooks/): `bluebox-hook.sh` runs on macOS, Linux and Windows with Git Bash, and `bluebox-hook.ps1` runs on Windows without it. Keep the two in step. `hooks/nudges.yaml` copies the nudges from the Bluebox source, so to change one, please open an issue, as for a skill.

To run the tests, which need Python 3.8 or later and git:

```bash
python3 -m unittest -v tests/hooks/test_hooks.py
```

They run each case in every shell they find (`sh`, `pwsh`, and on Windows `powershell`). Set `HOOK_RUNNERS` to pick, for example `HOOK_RUNNERS=sh`.

## Publishing

[PUBLISHING.md](PUBLISHING.md) explains how the Bluebox team publishes the MCP server to the MCP Registry and how the plugins reach each marketplace.

## Reporting issues

To report a bug, suggest a new skill or request a change to an existing one, please [open an issue](https://github.com/bluebox-hq/skills/issues/new).

## License

All contributions are licensed under Apache-2.0.
