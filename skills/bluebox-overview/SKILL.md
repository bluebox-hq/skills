---
name: bluebox-overview
description: Teaches a coding agent what Bluebox is, when to invoke it, and how to phrase requests so the agent picks the right Bluebox skill — investigation, instrumentation, or monitoring.
compatibility: Installed into coding agents by `bluebox setup`; compatible with Claude Code, Cursor, Windsurf, GitHub Copilot, Kiro, OpenCode, and Codex.
metadata:
  version: '1.6'
---

# Bluebox Overview

Bluebox is an observability agent that connects your codebase, CI/CD pipeline and Dynatrace data.

## Reaching Bluebox

Use the Bluebox MCP tools if you have them, passing each `bluebox ask` flag as the `ask` parameter of the same meaning. Else, if `bluebox ask --help` exits 0, run the commands as written. Else, or when an `ask` fails on sign-in, stop and tell the user in one line how to connect: the [MCP server](https://docs.bluebox.ai/mcp-server) or the [CLI](https://docs.bluebox.ai/cli). Never invent an answer or a verdict.

## What to use

| Need | Example | Handled by |
|---|---|---|
| Production context for a change | "what's the checkout service's p99 latency?" | `bluebox-production-query` |
| Incident root cause | "why did payments start throwing 5xx after today's release?" | `bluebox-production-query` |
| An existing investigation's findings | a ticket with a `bluebox-task-id` marker | `bluebox-investigation-context` |
| Instrument a service | "add OpenTelemetry to this service" | `bluebox-otel-instrumentation` |
| Check a deploy, or its SLOs and alerts | "did today's deploy degrade P99 latency?" | `bluebox-production-query` |
| A question about Bluebox itself | "what's the difference between Chat and Investigations?" | `bluebox ask "<question>"` |

For a question about Bluebox itself (what it does, setup, concepts, data handling), run `bluebox ask` yourself and relay its answer. Do not answer from general knowledge.

## Boundaries

- You cannot start a Bluebox investigation. Read one with `get_investigation`, or ask.
- Bluebox reads existing SLOs, alerts and dashboards. It never creates or changes them, and never rolls back a deploy.
- Instrumentation scope: `bluebox-otel-instrumentation`.
- Before you post findings in public, strip internal hostnames and tenant names.
- With the CLI but no skills or connection yet, run `bluebox setup`.
