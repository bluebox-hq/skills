# Publishing

How the Bluebox team publishes this repository to plugin marketplaces and registries.

## MCP Registry and GitHub MCP Registry

[server.json](server.json) describes the Bluebox MCP server for the official [MCP Registry](https://registry.modelcontextprotocol.io) as `ai.bluebox/mcp`. The [GitHub MCP Registry](https://github.com/mcp) lists servers from the MCP Registry.

The server sets no headers, so clients sign in to Bluebox through OAuth.

The `ai.bluebox` namespace comes from the `bluebox.ai` domain. To publish, the registry checks a signature against the public key at `https://bluebox.ai/.well-known/mcp-registry-auth`, which the Bluebox website serves. Treat that file like the private key: whoever can change it can publish under `ai.bluebox/*`. The earlier entry, `io.github.bluebox-hq/bluebox`, is deleted (see [The old entry](#the-old-entry)).

### Publish from CI

[publish-mcp.yml](.github/workflows/publish-mcp.yml) publishes `server.json` when someone pushes an `mcp-v*` tag. First it validates `server.json` and checks that the tagged commit is on `main` and that the tag matches `version` in `server.json`. Then the publish job waits for a reviewer of the `mcp-registry-publish` environment, signs in with the domain key and publishes.

Set up once, before the first tag:

1. In **Settings → Environments**, create `mcp-registry-publish`, add required reviewers and turn on **Prevent self-review**. Under **Deployment branches and tags**, allow only tags that match `mcp-v*`. If a workflow names an environment that doesn't exist, GitHub creates it on the first run without protection rules.
2. Add the private key to that environment as the secret `MCP_REGISTRY_PRIVATE_KEY`, in hex (see [Rotate the signing key](#rotate-the-signing-key)).

To release:

1. Bump `version` in `server.json` (for example to `1.0.2`) and merge the change to `main`. The registry rejects a version that is already published.
2. Tag that commit on `main` and push the tag:

   ```bash
   git tag mcp-v1.0.2 && git push origin mcp-v1.0.2
   ```

3. A reviewer approves the job in **Actions**. Before approving, check that the run's commit is the tagged commit on `main` and that `validate` and `check-tag` passed. The run uses the workflow file from the tagged commit, so a tag on any other commit can run a different workflow.
4. Check that the new version is live:

   ```bash
   curl -s "https://registry.modelcontextprotocol.io/v0.1/servers?search=ai.bluebox/mcp"
   ```

5. First publish only: email `partnerships@github.com` and ask them to list `ai.bluebox/mcp` on github.com/mcp. GitHub curates that list. After the first listing, new versions sync automatically.

The skills sync replaces only `skills/`, so it never changes `server.json` or pushes an `mcp-v*` tag. Both workflows install `mcp-publisher` through [install-mcp-publisher](.github/actions/install-mcp-publisher/action.yml). When you update it, change `MCP_PUBLISHER_VERSION` and `MCP_PUBLISHER_SHA256` there together.

`mcp-publisher status` changes the lifecycle state of a published server, so never run it to check a publish. Use it only on purpose, as for [the old entry](#the-old-entry).

If the sign-in fails, `https://bluebox.ai/.well-known/mcp-registry-auth` is missing or doesn't match the private key. If `publish` fails with HTTP 403, the name isn't under `ai.bluebox/`; the comparison is case-sensitive.

### The old entry

`io.github.bluebox-hq/bluebox` is the server's earlier name. Every version of it has the status `deleted`, with the message "Moved to ai.bluebox/mcp", so registry search and listings no longer return it. To see its current state without changing it:

```bash
curl -s "https://registry.modelcontextprotocol.io/v0.1/servers?search=io.github.bluebox-hq/bluebox&include_deleted=true"
```

The record stays in the registry. This command set the current state:

```bash
mcp-publisher status --status deleted --all-versions --yes \
  --message "Moved to ai.bluebox/mcp" io.github.bluebox-hq/bluebox
```

To undo it, run the command again with `--status deprecated`, or with `--status active` and no `--message`. The registry rejects `--message` with `active`.

This needs a sign-in to the `io.github.bluebox-hq` namespace: `mcp-publisher login github-oidc` from a GitHub Actions workflow in a `bluebox-hq` repository, or `mcp-publisher login github --token` by an owner of the `bluebox-hq` organization, with a classic token that has the `read:org` scope. The registry keeps granting that namespace to any workflow in a `bluebox-hq` repository, so write access to those repositories still means publish access to the old name.

### Rotate the signing key

1. Generate a new Ed25519 key pair in a temporary folder, outside any checkout:

   ```bash
   dir=$(mktemp -d) && openssl genpkey -algorithm Ed25519 -out "$dir/key.pem"
   ```

2. Put the public key on the website. The file at `https://bluebox.ai/.well-known/mcp-registry-auth` holds one line, `v=MCPv1; k=ed25519; p=<public key>`, where the public key is:

   ```bash
   openssl pkey -in "$dir/key.pem" -pubout -outform DER | tail -c 32 | base64
   ```

3. Replace the `MCP_REGISTRY_PRIVATE_KEY` environment secret with the private key in hex:

   ```bash
   openssl pkey -in "$dir/key.pem" -outform DER | tail -c 32 | xxd -p -c 64
   ```

4. Store `key.pem` in the team's password manager, then delete `$dir`. Never commit the private key.

After step 2, wait 10 minutes before you publish with the new key. The website caches the file for that long, so until then the registry may still see the old public key.

### Publish by hand

Use this only if the workflow can't run. You need the private key from the password manager.

1. Install `mcp-publisher` (`brew install mcp-publisher`, or a release binary from [modelcontextprotocol/registry](https://github.com/modelcontextprotocol/registry/releases)).
2. Bump `version` in `server.json` and merge the change to `main`.
3. On an up-to-date `main`, read the key without echoing it, then validate, sign in and publish:

   ```bash
   read -rs MCP_REGISTRY_PRIVATE_KEY
   mcp-publisher validate
   mcp-publisher login http --domain bluebox.ai --private-key "$MCP_REGISTRY_PRIVATE_KEY"
   mcp-publisher publish
   unset MCP_REGISTRY_PRIVATE_KEY
   ```

   `read -rs` keeps the key out of your shell history.

4. Check the result as in step 4 above.

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
| Cursor | `.cursor-plugin/plugin.json` | Submit once at <https://cursor.com/marketplace/publish>. |
| Devin | `.devin-plugin/plugin.json`, `skills/` | Install from this repository now (`devin plugins install bluebox-hq/skills`). Marketplace: open a pull request to [CognitionAI/devin-marketplace](https://github.com/CognitionAI/devin-marketplace) that adds `{"source": "url", "url": "https://github.com/bluebox-hq/skills.git", "sha": "<full commit sha>"}` to `optionalPlugins` in `.devin-plugin/plugin.json`, then run `python3 scripts/validate.py --fix` and `python3 scripts/validate.py --fetch`. The pin is a full commit SHA, so open a pull request that bumps it after each release. |
| Google Antigravity | `.antigravity-plugin/plugin.json`, `mcp_config.json` | Install by URL now (`agy plugin install https://github.com/bluebox-hq/skills`). Marketplace: Google's interest form. The Marketplace needs a higher `version` in `.antigravity-plugin/plugin.json` for every update. |
| Kiro | `POWER.md`, `mcp.json` | Install by repository URL now. A directory listing at <https://kiro.dev/powers/submit> needs a root `plugin.json` in the Agent Plugins format, plus privacy policy and support links in the README. Cursor and the OpenAI plugin format would read a root `plugin.json` too, so a Kiro listing needs its own layout. |
