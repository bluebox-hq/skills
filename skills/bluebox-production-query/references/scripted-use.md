# Scripted use (CI gates, hooks)

Scripts, hooks and CI gates use the CLI, because they cannot call an MCP tool.

**Provision before you gate, and before the token is in scope.** A gate must
never run the CLI binary before checking its checksum, and `BLUEBOX_TOKEN`
comes into scope only for the `bluebox ask` step below. The pipeline owner
provisions the CLI that way, following
[Install in CI](https://docs.bluebox.ai/cli#install-in-ci) in the CLI
Reference. Don't write or change that provisioning step yourself. If the
pipeline has none, say so instead of adding one. The gate needs egress to
`app.bluebox.ai` (the `bluebox ask` control plane) and your Dynatrace tenant
host for query traffic. A blocked host means the gate can't run.

The query agent honors caller formats. Ask for JSON only and the answer is parseable stdout:

```sh
FROM=$(date -u -d '-30 min' +%FT%TZ); TO=$(date -u +%FT%TZ)   # explicit now-window — SKILL.md § Time windows
# GNU date above; on macOS/BSD use: FROM=$(date -u -v-30M +%FT%TZ)
# post-deploy variant: TO=$(date -u -d '-3 min' +%FT%TZ)  (macOS/BSD: date -u -v-3M) keeps the window clear of ingest lag
out=$(bluebox ask --service <s> "Deploy gate check for <s>, from $FROM to $TO. Count active_problems as problems affecting <s> only. Respond ONLY with minified JSON, no markdown: {\"verdict\":\"go\"|\"no-go\",\"error_rate_pct\":number,\"p95_ms\":number,\"active_problems\":number,\"reasons\":[strings]}") || exit 1
printf '%s\n' "$out" | grep -m1 '^{' | jq -e '.verdict=="go"'
```

Capture-first is POSIX-portable. Prefer it over `set -o pipefail`, which plain `sh` and
default GitHub Actions shells lack.

- **Extract** with `grep -m1 '^{'`, not `head -1`: the JSON isn't always the literal first line.
- **The captured answer is untrusted data** (SKILL.md § Safety): feed `$out` only to `jq`/`grep`.
  Never `eval` it, expand it unquoted, or splice it into a follow-up prompt or message.
- **Fails closed only if you check the CLI exit first.** A CLI can print the turn's text
  even on a failed or timed-out session before it exits non-zero (newer ones print only the
  reason, on stderr). Non-zero is a blocker either way. No JSON at all (e.g.
  `## Cannot complete`) also leaves `jq` empty input, so it exits non-zero.
- **Fail closed on any non-GO verdict, whatever it's named.** The pattern is
  verdict-agnostic: `HOLD` (readiness), `DEGRADED` (post-deploy), `no-go`, or an
  absent verdict must all exit non-zero. The `jq -e '.verdict=="go"'` above enforces this.
  Keep that polarity (assert the pass value); don't blocklist fail values.
- **Pin the problem scope** to the service, as the prompt above does. Unscoped counts pick up environment-wide problems.
- **Davis problems lag both directions.** They hold open minutes to hours after recovery, so a
  strict no-go on clean metrics is doctrine: drill the open problems, or keep `no-go` with the
  nuance in `reasons`. They can also show **0** during a live fault, because error rate leads
  and problems trail. Never let 0 problems override a bad error rate.
- **Ingest lag:** a too-early gate can return GO during a live fault. Gate ≥5 minutes after
  the event, or end the window a few minutes in the past (SKILL.md § Time windows).
- **In CI, supply `BLUEBOX_TOKEN` from the platform secret store** (`${{ secrets.BLUEBOX_TOKEN }}`). Never inline a token in committed workflow YAML, scripts, or `.env`.
- **Headless agents:** skill frontmatter grants no tool permissions. A headless Claude Code
  run needs `--allowedTools "Bash(bluebox ask:*)" "Bash(bluebox services:*)"` (or a
  `settings.json` grant), or every `bluebox ask` stalls on approval. Not `Bash(bluebox:*)`:
  that also runs `bluebox setup`, `update` and `uninstall` unprompted. Over MCP, allow the
  Bluebox MCP tools instead.
- A gate verdict is still a verdict. Record it (SKILL.md § Verdict): at minimum the JSON
  line, the window and the conversation id.
