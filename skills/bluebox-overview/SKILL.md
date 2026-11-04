---
name: bluebox-overview
description: Teaches a coding agent what Bluebox is, when to invoke it, and how to phrase requests so the agent picks the right Bluebox skill — investigation, instrumentation, or monitoring.
compatibility: Installed into coding agents by `bluebox setup`; compatible with Claude Code, Cursor, Windsurf, GitHub Copilot, Kiro, OpenCode, and Codex.
metadata:
  version: '1.5'
---

# Bluebox Overview

Bluebox is an observability agent that connects your codebase, CI/CD pipeline, and Dynatrace observability data. It runs AI-driven agents that investigate production incidents, instrument services, and verify deployments — without requiring manual context switching between your IDE, dashboards, and runbooks.

## Reaching Bluebox

Before your first Bluebox call, pick one path, in this order:

1. **MCP.** You have a Bluebox MCP server's `ask` tool. Send each `bluebox ask` below to it, each flag as the parameter of the same meaning. To scope to a service, call `list_services` with the git origin as `repository_url`; if that finds none or rejects the origin, call it with `search` set to the service name. Pass the match's `entity_id`. For `--task-id`, read the report with `get_investigation` first. While `status` is `running`, call `get_ask_result` with the `conversation_id`: another `ask` starts a second run. Record `meta.window` and `conversation_id` with each verdict.
2. **CLI.** `bluebox ask --help` exits 0. Run the commands as written.
3. **Neither.** Stop and tell the user in one line how to connect: the Bluebox plugin or [MCP server](https://docs.bluebox.ai/mcp-server), or the [CLI](https://docs.bluebox.ai/cli). Never invent an answer.

Scripts, hooks and CI gates keep the CLI, because they cannot call an MCP tool.

## When to use Bluebox

Reach for Bluebox when you need to:

- **Investigate a production incident** — Bluebox gathers Dynatrace problems, logs, traces, and metrics, correlates them with recent code changes, and delivers a structured root-cause diagnosis.
- **Instrument a service** — Bluebox detects your language and deployment model, then sets up repo-local OpenTelemetry for server-side traces. Metrics and logs are optional follow-up scope; RUM, AppSec, infrastructure monitoring, synthetics, SLOs, dashboards, and alerts require separate setup paths.
- **Verify a deploy** — Bluebox compares service health after a deploy with the period before it and names any regression. It reports what it finds; it does not roll back or change anything.

## Example prompts

### Investigation
- "investigate the latest production error"
- "check why the checkout service is slow"
- "analyze the most recent deployment"
- "why did the payment service start throwing 5xx errors after today's release?"

### Instrumentation
- "add OpenTelemetry to this service"
- "instrument the API endpoints"
- "set up distributed tracing for the orders service"

### Deploy verification and monitoring
- "verify the deploy didn't degrade P99 latency"
- "compare the checkout service's error rate before and after today's deploy"
- "which SLOs and alerts cover the search service, and is any of them burning?"

Bluebox reads existing SLOs, alerts, and dashboards; it does not create them on request. Set those up in your observability backend.

## Learning more about Bluebox

The prompts above ask Bluebox to act **on the user's own services**. When the user instead asks a conceptual or how-to question **about Bluebox itself** — what it does, how to set it up, how its concepts work, or how it handles their data — answer it by running `bluebox ask` yourself and relaying what it returns:

```bash
bluebox ask "<question>"
```

For example:

- `bluebox ask "what is Bluebox and how does it work?"`
- `bluebox ask "how does Bluebox handle my data and privacy?"`
- `bluebox ask "what's the difference between Chat and Investigations?"`

Rule of thumb: run `bluebox ask` yourself for **questions about Bluebox**, and use the investigation, instrumentation, and monitoring prompts above for **Bluebox acting on the user's infrastructure**.

## Setup

With the CLI and no skills or connection yet, run `bluebox setup` and follow its instructions. With neither the MCP server nor the CLI, see **Reaching Bluebox**.
