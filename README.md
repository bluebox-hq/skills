# Bluebox skills

Agent skills that connect your coding agent to [Bluebox](https://bluebox.ai), the observability agent for AI-native development. With them, your agent checks production before it plans a change, picks up a Bluebox investigation's root cause, and adds OpenTelemetry to your services.

The skills work with Claude Code, Cursor, GitHub Copilot, Codex, OpenCode, Windsurf, Kiro, and other agents that read the [Agent Skills](https://agentskills.io) format.

## Skills

| Skill | What it does |
|---|---|
| [bluebox-overview](skills/bluebox-overview/SKILL.md) | Explains Bluebox to your agent and which Bluebox skill fits a request. |
| [bluebox-production-query](skills/bluebox-production-query/SKILL.md) | Gets production context (error rates, latency, callers, active problems) before your agent designs or ships a change. |
| [bluebox-investigation-context](skills/bluebox-investigation-context/SKILL.md) | Loads the root cause and evidence of the Bluebox investigation that filed a GitHub issue, so your agent builds the fix on it. |
| [bluebox-otel-instrumentation](skills/bluebox-otel-instrumentation/SKILL.md) | Adds OpenTelemetry to a service or repository and sends its telemetry to Bluebox. |
| [bluebox-otel-instrumentation-guided](skills/bluebox-otel-instrumentation-guided/SKILL.md) | The same instrumentation as a step-by-step flow. Install it together with `bluebox-otel-instrumentation`. |

## Before you start

You need a Bluebox account. The skills use the [Bluebox MCP server](https://docs.bluebox.ai/mcp-server) when your agent has it, and the [`bluebox` CLI](https://docs.bluebox.ai/cli) otherwise. The [Bluebox docs](https://docs.bluebox.ai) show how to set up either.

**If you use `bluebox setup`, you already have these skills.** It installs them into your agents and keeps them up to date. You don't need this repository.

## Install

In your project, run:

```bash
npx skills add bluebox-hq/skills
```

It asks which skills to install and for which agents. To choose without the questions, for example in a script or when your coding agent runs the install, name them:

```bash
npx skills add bluebox-hq/skills --skill '*' --agent claude-code cursor
```

Name one or more skills after `--skill` to install only those; `bluebox-otel-instrumentation-guided` needs `bluebox-otel-instrumentation` too. Add `-g` to install for your user instead of the current project. Prefer `--agent` over `--all`: `--all` installs for every agent `skills` supports and adds a skills folder for each to your project.

## Plugins

Claude Code, Codex, the ChatGPT desktop app, Cursor, Devin, Google Antigravity and Kiro can install Bluebox as one plugin instead. The plugin also connects your agent to the [Bluebox MCP server](https://docs.bluebox.ai/mcp-server). In Kiro, the plugin is a power with the MCP server only; see [Kiro](#kiro). You sign in to Bluebox in your browser the first time the agent connects, so you don't need an access token.

Install the skills with one tool only. If you use the plugin, don't also install the skills with `npx skills` or `bluebox setup`, or your agent loads each skill twice.

If you added a `bluebox` MCP server by hand before, Claude Code and Codex keep using it and skip the plugin's. Remove it first with `claude mcp remove bluebox` or `codex mcp remove bluebox`.

### Claude Code

```bash
claude plugin marketplace add bluebox-hq/skills
claude plugin install bluebox@bluebox
```

To sign in, run `/mcp` in Claude Code, select `plugin:bluebox:bluebox` and log in to Bluebox. To get updates, turn on auto-update for the `bluebox` marketplace under `/plugin` → **Marketplaces**, or run `claude plugin update bluebox@bluebox`.

### Codex

```bash
codex plugin marketplace add bluebox-hq/skills
codex plugin add bluebox@bluebox
```

Codex opens the Bluebox sign-in when you install the plugin. If you skip it, run `codex mcp login bluebox`. To update, run `codex plugin marketplace upgrade bluebox`.

### ChatGPT

- **ChatGPT desktop app (Work mode):** add the marketplace with `codex plugin marketplace add bluebox-hq/skills`, restart the app, then install **Bluebox** from the `Bluebox` source in the Plugins Directory.
- **ChatGPT web and mobile:** install Bluebox from the ChatGPT plugin directory once it's listed. Until then, add only the MCP server: open [ChatGPT Plugins](https://chatgpt.com/plugins), select **+** → **Add custom MCP server**, enter `https://app.bluebox.ai/v1/mcp` with OAuth, and select **Create as a plugin**. Your workspace policies decide whether custom MCP servers are allowed.

### Cursor

Clone this repository into your local plugins folder:

```bash
git clone https://github.com/bluebox-hq/skills.git ~/.cursor/plugins/local/bluebox
```

Clone it there directly. Cursor rejects a symlink in `~/.cursor/plugins/local` that points outside that folder.

Reload Cursor, then sign in to the `bluebox` MCP server in Cursor's MCP settings. To update, run `git pull` in the clone.

### Devin

```bash
devin plugins install bluebox-hq/skills
```

In Devin Cloud, select **Add plugin → From repository** and enter `bluebox-hq/skills`. Devin opens the Bluebox sign-in when a session first uses the `bluebox` MCP server.

### Google Antigravity

```bash
agy plugin install https://github.com/bluebox-hq/skills
```

Antigravity opens the Bluebox sign-in when it first connects to the `bluebox` MCP server.

### Kiro

Kiro installs Bluebox as a power: the MCP server plus a guide for the agent ([POWER.md](POWER.md)). Open the **Powers** panel, select **Add Custom Power**, choose **Import power from GitHub** and enter `https://github.com/bluebox-hq/skills`. Kiro opens the Bluebox sign-in when it first connects. The power doesn't include the skills. To add them, run `npx skills add bluebox-hq/skills --skill '*' --agent kiro-cli`.

## Update and remove

```bash
npx skills update
npx skills remove bluebox-production-query
```

Install each skill with one tool only. To switch to `bluebox setup`, first remove the copies you installed here (add `-g` for a user install), then run `bluebox setup`:

```bash
npx skills remove bluebox-investigation-context bluebox-otel-instrumentation bluebox-otel-instrumentation-guided bluebox-overview bluebox-production-query
```

Name the skills instead of using `--all`, which removes every skill in your agents' skills folders, not only these.

## License

[Apache-2.0](LICENSE)
