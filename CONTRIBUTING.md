# Contributing

## Skills are read-only

The skills under `skills/` are maintained in the Bluebox source and copied to this repository on every Bluebox release. Each copy replaces `skills/` entirely, so **pull requests that change files under `skills/` are not accepted**: the change would be lost on the next release.

To suggest a change to a skill, please [open an issue](https://github.com/bluebox-hq/skills/issues/new) instead. The Bluebox team picks it up and makes the change at the source.

## What you can contribute

Everything outside `skills/` lives only in this repository and welcomes pull requests. For anything beyond a small docs fix, please open an issue first.

## Plugin changes need a new version

Claude Code updates an installed plugin only when `version` in `.claude-plugin/plugin.json` changes. A pull request that changes `.claude-plugin/`, `hooks/` or `.mcp.json` must also change `version` to a value that is not on `main`; a CI check enforces this. Each Bluebox release sets `version` to its own release number.

## Publishing

[PUBLISHING.md](PUBLISHING.md) explains how the Bluebox team publishes the MCP server to the MCP Registry and how the plugins reach each marketplace.

## Reporting issues

To report a bug, suggest a new skill or request a change to an existing one, please [open an issue](https://github.com/bluebox-hq/skills/issues/new).

## License

All contributions are licensed under Apache-2.0.
