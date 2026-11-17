# Publishing

How the Bluebox team publishes this repository to plugin marketplaces and registries.

## MCP Registry and GitHub MCP Registry

[server.json](server.json) describes the Bluebox MCP server for the official [MCP Registry](https://registry.modelcontextprotocol.io) as `io.github.bluebox-hq/bluebox`. The [GitHub MCP Registry](https://github.com/mcp) lists servers from the MCP Registry.

The server sets no headers, so clients sign in to Bluebox through OAuth.

### Publish from CI

[publish-mcp.yml](.github/workflows/publish-mcp.yml) publishes `server.json` when someone pushes an `mcp-v*` tag. It signs in with GitHub OIDC, so it needs no stored secret and no owner's token. First it validates `server.json` and checks that the tagged commit is on `main` and that the tag matches `version` in `server.json`. Then the publish job waits for a reviewer of the `mcp-registry-publish` environment.

Set up once, before the first tag: in **Settings → Environments**, create `mcp-registry-publish`, add required reviewers and turn on **Prevent self-review**. Under **Deployment branches and tags**, allow only tags that match `mcp-v*`. If a workflow names an environment that doesn't exist, GitHub creates it on the first run without protection rules.

The reviewer guards this workflow only, not the namespace. The registry gives an OIDC token from any GitHub Actions workflow in a `bluebox-hq` repository the right to publish anything under `io.github.bluebox-hq/*`, and it doesn't check the repository, branch or environment. So anyone who can push a workflow to a `bluebox-hq` repository can publish. Give write access to `bluebox-hq` repositories only to people you'd trust to publish.

To release:

1. Bump `version` in `server.json` (for example to `1.0.1`) and merge the change to `main`. The registry rejects a version that is already published. Skip this step for the first publish, which uses `1.0.0`.
2. Tag that commit on `main` and push the tag:

   ```bash
   git tag mcp-v1.0.1 && git push origin mcp-v1.0.1
   ```

3. A reviewer approves the job in **Actions**.
4. Check that the new version is live:

   ```bash
   curl -s "https://registry.modelcontextprotocol.io/v0.1/servers?search=io.github.bluebox-hq/bluebox"
   ```

5. First publish only: email `partnerships@github.com` and ask them to list `io.github.bluebox-hq/bluebox` on github.com/mcp. GitHub curates that list. After the first listing, new versions sync automatically.

The skills sync replaces only `skills/`, so it never changes `server.json` or pushes an `mcp-v*` tag. Both workflows install `mcp-publisher` through [install-mcp-publisher](.github/actions/install-mcp-publisher/action.yml). When you update it, change `MCP_PUBLISHER_VERSION` and `MCP_PUBLISHER_SHA256` there together.

Don't run `mcp-publisher status` to check a publish. It changes the lifecycle state of the published server.

If `publish` fails with HTTP 403, the name doesn't match the namespace. The name must start with `io.github.bluebox-hq/`, and the comparison is case-sensitive.

### Publish by hand

Use this only if the workflow can't run. You need to be an **owner** of the `bluebox-hq` GitHub organization: the registry grants the `io.github.bluebox-hq/*` namespace only to org owners, and membership isn't enough.

1. Install `mcp-publisher` (`brew install mcp-publisher`, or a release binary from [modelcontextprotocol/registry](https://github.com/modelcontextprotocol/registry/releases)).
2. Bump `version` in `server.json` and merge the change to `main`.
3. On an up-to-date `main`, validate, sign in and publish:

   ```bash
   mcp-publisher validate
   mcp-publisher login github --token "$GITHUB_TOKEN"
   mcp-publisher publish
   ```

   Sign in with a personal access token. The browser login (`login github` without `--token`) can't publish to an organization namespace yet ([modelcontextprotocol/registry#1468](https://github.com/modelcontextprotocol/registry/issues/1468)). The token must let the registry read your org role: a classic token with the `read:org` scope, or a fine-grained token for `bluebox-hq` with **Members: Read**. A 403 here can also mean the token can't read your org role.

4. Check the result and, on the first publish, email GitHub as in steps 4 and 5 above.

## OpenAI plugin directory (ChatGPT and Codex)

ChatGPT and Codex share one plugin directory. Submit a ZIP at <https://platform.openai.com/plugins> (**Upload new or existing plugin**). Organization owners can submit; other members need **Apps Management Write**, and the organization needs individual or business verification.

### Build the ZIP

The ZIP holds only the Codex package: the manifest, the MCP config, the skills and the icons. Leave out the other clients' files.

```bash
git archive --format=zip -o bluebox-openai.zip HEAD .codex-plugin .mcp.json skills assets LICENSE
```

Run it from a clean checkout of the commit you want to submit.

### Before you submit

1. **Domain verification.** The portal shows a challenge token. Serve it as plain text, the token only, at `https://app.bluebox.ai/.well-known/openai-apps-challenge`, or on an eligible parent domain.
2. **MCP server.** Connect `https://app.bluebox.ai/v1/mcp` with **OAuth**. A plugin can connect only one MCP server. The portal rejects server headers, so don't add a token.
3. **Review materials.** A reviewer test account that works without MFA, email codes or magic links, with sample data. Add 5 positive and 3 negative test cases, a video walkthrough of the test cases, and release notes.
4. **Version.** Bump `version` in `.codex-plugin/plugin.json` for every new ZIP.

After publication, OpenAI scans the MCP server daily. New or changed tools stay unavailable until OpenAI approves them. Changes to skills or metadata need a new ZIP.

## Plugin marketplaces

The plugin files need no publish step. Each client reads them from this repository:

| Client | Files | Listing |
|---|---|---|
| Claude Code | `.claude-plugin/`, `.mcp.json` | Self-hosted now (`claude plugin marketplace add bluebox-hq/skills`). Directory listing: submit the repository in the developer portal at <https://claude.ai/directory/manage>. New versions arrive by GitHub push webhook or a scheduled check, and the directory scans each one before it goes live. |
| Codex and ChatGPT desktop | `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`, `.mcp.json`, `skills/` | Self-hosted now: `codex plugin marketplace add bluebox-hq/skills`. The ChatGPT desktop app (Work mode) shows the same marketplace as a source in its Plugins Directory. `codex plugin marketplace upgrade` reinstalls the plugin when this repository has new commits, so skill updates reach Codex users without a `version` bump. Bump `version` for each new OpenAI directory ZIP. |
| ChatGPT web and mobile | The submission ZIP (see [OpenAI plugin directory](#openai-plugin-directory-chatgpt-and-codex)) | Only listed plugins reach web and mobile: there is no install from GitHub. Until the listing, users can add just the MCP server as a custom MCP server at <https://chatgpt.com/plugins>. |
| Cursor | `.cursor-plugin/plugin.json`, `mcp.json` | Submit once at <https://cursor.com/marketplace/publish>. |
| Devin | `.devin-plugin/plugin.json`, `skills/` | Install from this repository now (`devin plugins install bluebox-hq/skills`). Marketplace: open a pull request to [CognitionAI/devin-marketplace](https://github.com/CognitionAI/devin-marketplace) that adds `{"source": "url", "url": "https://github.com/bluebox-hq/skills.git", "sha": "<full commit sha>"}` to `optionalPlugins` in `.devin-plugin/plugin.json`, then run `python3 scripts/validate.py --fix` and `python3 scripts/validate.py --fetch`. The pin is a full commit SHA, so open a pull request that bumps it after each release. |
| Google Antigravity | `.antigravity-plugin/plugin.json`, `mcp_config.json` | Install by URL now (`agy plugin install https://github.com/bluebox-hq/skills`). Marketplace: Google's interest form. The Marketplace needs a higher `version` in `.antigravity-plugin/plugin.json` for every update. |
| Kiro | `POWER.md`, `mcp.json` | Install by repository URL now. A directory listing at <https://kiro.dev/powers/submit> needs a root `plugin.json` in the Agent Plugins format, plus privacy policy and support links in the README. Cursor and the OpenAI plugin format would read a root `plugin.json` too, so a Kiro listing needs its own layout. |
