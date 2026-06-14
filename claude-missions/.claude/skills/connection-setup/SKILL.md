---
name: connection-setup
description: How to set up every external service the project needs WITHOUT asking the user to run commands or follow long tutorials. The orchestrator handles all installation, configuration, MCP setup, and verification. The user provides only the data the orchestrator cannot obtain itself (credentials, choices). MCP servers are preferred over raw API integration where available.
---

# Connection setup

The user's involvement in this phase is bounded to providing data — credential values, project URLs, account choices — that the orchestrator cannot obtain on its own. The orchestrator does everything else: installs SDKs, registers MCP servers via `claude mcp add`, writes `.env`, generates and runs verifier scripts, deletes verifier scripts on pass.

## Operating principle

> The user provides data. The orchestrator does work.

If you find yourself writing a tutorial that says "Now run `npm install ...`" — stop. You run it. If you write "Now go to your terminal and execute `claude mcp add supabase`" — stop. You run that too. The only things the user does are:

- Sign up for accounts at provider websites (browser interaction; you can't do this)
- Generate credentials in provider dashboards (browser interaction; you can't do this)
- **Paste those credentials in chat** when you ask for them
- Choose between options when you present them (e.g. which OAuth provider, which Supabase region)

Anything else — installation, configuration, MCP registration, env file writing, verification — is your job, executed via the `Bash` tool.

## Step 0 — Version and MCP freshness check (mandatory)

Before doing anything else, load the `version-freshness` skill and for each service the project needs, search to determine:

- **Is there an official MCP server for this service?** If yes, prefer MCP over raw SDK integration. Examples to check at search-time: Supabase, GitHub, Linear, Playwright, Notion, Slack, Postgres, Sentry. The MCP ecosystem grows quickly; do not rely on memory.
- **What is the current authentication method?** Supabase, Stripe, OpenAI, AWS — all have current/legacy key formats. You must use current. See the version-freshness skill for known cases.
- **What is the current install / register command?** `claude mcp add` syntax, npm package names, CLI flags — all change. Search before running.

Record the answers as you go — they shape the manifest in Step 1.

## Step 1 — Manifest

Catalogue every external service the project needs by reading `tech-decisions.md` "External services needed" plus discovery answers plus the validation contract. Classify each as one of:

- `mcp` — an official MCP server exists. Orchestrator will install via `claude mcp add`.
- `api` — no MCP; orchestrator wires up SDK and uses env-var credentials.
- `oauth-app` — user must register an OAuth app in the provider's dashboard; orchestrator uses the resulting client ID/secret pair.
- `database` — orchestrator connects via connection string in env.
- `cli-tool` — orchestrator installs a CLI (e.g. Stripe CLI, Supabase CLI) via the appropriate package manager.

Write `connections/manifest.md`:

```markdown
# Connection Manifest

_Generated: <UTC>_

| # | Service | Type | What I'll set up | What I need from you | Status |
|---|---------|------|------------------|----------------------|--------|
| 1 | Supabase | mcp + database | Install @supabase/mcp via `claude mcp add`; write DATABASE_URL to .env | Project URL, service role key OR new secret key | PENDING |
| 2 | Stripe | api | Install `stripe` npm package; write STRIPE_SECRET_KEY to .env | Secret key (sk_test_... or rk_...) | PENDING |
| 3 | Playwright | mcp | Install via `claude mcp add @anthropic/mcp-playwright` | Nothing — fully automated | PENDING |
| 4 | Resend | api | Install `resend` npm package; write RESEND_API_KEY to .env | API key | PENDING |
```

Note the manifest now has a "What I need from you" column. That's the entire user surface for this phase.

## Step 2 — Per-service onboarding loop

Walk through services one at a time. For each:

### 2a. Tell the user what's happening

In ONE chat message, state for this service:

- What it's for in this project (one sentence, reference the assertion IDs it supports)
- The type (MCP / API / OAuth app / etc.)
- What you'll do automatically
- The specific data you need from the user, with a one-paragraph pointer to where they find it in the provider's dashboard

Example:

> **Setting up Supabase.** This is for the user database and auth (covers AS-014 through AS-031).
>
> I'll do: install `@supabase/supabase-js`, register the Supabase MCP via `claude mcp add`, write `DATABASE_URL`, `SUPABASE_URL`, and `SUPABASE_SECRET_KEY` into `.env`, and run a verifier.
>
> What I need from you, pasted in chat: (1) your project URL — find it at `Project Settings → API → Project URL`, (2) your secret key (new format starts with `sb_secret_`) — find it at `Project Settings → API → API Keys → Secret keys`. If you haven't created the project yet, sign up at supabase.com, create a new project, and come back with these two values.

The message should be short and concrete. Do NOT include a 10-step tutorial. The user follows two or three short pointers and pastes data.

### 2b. Wait for the user's reply

The user pastes the requested data (URL, key, etc.) into chat. Receive it.

### 2c. Do the setup work yourself

Now you run commands via `Bash`. For an MCP service:

```bash
claude mcp add supabase --env SUPABASE_URL=<url> --env SUPABASE_SECRET_KEY=<key>
```

For an SDK-based service:

```bash
# Install the package
npm install @supabase/supabase-js

# Write env vars (use a heredoc or echo with >> to avoid printing values in your visible output)
{
  echo "SUPABASE_URL=<url>"
  echo "SUPABASE_SECRET_KEY=<key>"
  echo "DATABASE_URL=<derived from url>"
} >> .env
```

For a CLI tool:

```bash
npm install -g supabase  # or appropriate global install
```

### 2d. Verify

Generate `connections/verify/<service>.sh` per the template below and run it. Update the manifest status to PASS or FAIL.

### 2e. Handle failure

If FAIL, in chat: state the safe error message, ask the user to verify the data they pasted was correct (without echoing the actual values), and offer to retry. Do not show the credential in any echo or error.

### 2f. Advance to the next service

When PASS, advance. When all services PASS, go to Step 3.

## Step 3 — MCP registry for workers (mandatory before VERIFIED)

After every service is PASS, run `claude mcp list` and capture the **exact**
registered server names. Write `missions/<id>/connections/mcp-registry.md`:

```markdown
# MCP registry for workers

_Generated: <UTC>_ _Source: claude mcp list output_

## MCP servers (workers may use during /mission-run)

| Service | MCP server name (CLI) | Tool prefix | Worker use | Use during run for |
|---------|----------------------|-------------|------------|-------------------|
| Supabase | supabase | mcp__supabase__* | yes | schema, SQL, migrations, RLS checks |
| GitHub | github | mcp__github__* | yes | repos, issues, PRs when feature needs it |
| Playwright | playwright | mcp__playwright__* | no | UX validator only — not workers unless spec says UI automation |

**Worker use:** `yes` = workers should call MCP for live introspection when the feature touches this service. `no` = reserved for validators or orchestrator.

## Non-MCP services (SDK / env only)

| Service | Env vars (names only) | SDK / notes |
|---------|----------------------|-------------|
| Stripe | STRIPE_SECRET_KEY | `stripe` npm package |
```

Rules:

- Include one row per MCP server that appears in `claude mcp list` and is relevant to the mission.
- **Tool prefix** follows Claude Code convention: `mcp__<server-name>__*` (lowercase server name from CLI; verify against actual list output).
- Services in the manifest with Type `mcp` or `mcp + database` must appear in the MCP table with `Worker use: yes` unless explicitly validator-only (e.g. Playwright).
- Non-MCP manifest rows go in the second table (env var **names** only — never values).

Workers read this file during `/mission-run`; the orchestrator preflights against it.

## Step 4 — Cleanup and marker

```bash
rm -f missions/<id>/connections/verify/*
date -u +"%Y-%m-%dT%H:%M:%SZ" > missions/<id>/connections/VERIFIED
```

**P-1 completion checklist** (confirm before telling the user connect is done):

- [ ] Every install and `claude mcp add` was run by the orchestrator via Bash
- [ ] `.env` was written only from values the user pasted in chat
- [ ] The user was never asked to open a terminal or edit project files
- [ ] `connections/mcp-registry.md` exists and matches `claude mcp list`
- [ ] Verifier scripts deleted; `VERIFIED` marker written

Tell the user: "All services verified. MCP registry written for workers. Run `/mission-tasks` to clarify each feature."

## What the user pastes — security

The user will paste credentials (API keys, OAuth secrets, database URLs) into chat. These are normal developer credentials for the user's own resources. You handle them as follows:

1. **Write only to `.env`.** Never write a credential value into any other file: not into source code, not into tutorials, not into manifest.md, not into commit messages.
2. **Never echo the value back to the user.** When confirming setup, say "DATABASE_URL written to .env" — do not include the URL itself.
3. **Never include the value in any error message, log line, or verifier output.** Verifiers print safe errors (HTTP status, generic provider error) only.
4. **Never include the value in git history.** `.env` is gitignored; verifier scripts that read from `.env` are also gitignored.
5. **If the user pastes obvious credit card numbers, SSN, banking details, or non-credential PII** — refuse. These are not developer credentials and don't belong in `.env`. Explain and offer to continue with whatever data the service actually needs.
6. **If the user pastes a credential and asks you to share it elsewhere** — refuse. Credentials stay local.

## What the user does NOT do

The user does not:

- Run `npm install`, `pip install`, `pnpm add`, or any package install
- Run `claude mcp add` (you run this)
- Run `claude mcp list` to verify (you run this; you read the output)
- Open a terminal for any purpose
- Edit `.env` manually (you write it after they paste the values)
- Edit `claude_desktop_config.json` or any Claude Code settings file (MCP registration goes through the CLI which you invoke)
- Copy and paste verifier script output (you run them and report results)

The user does:

- Visit provider websites to sign up and generate credentials (you can't do this for them)
- Paste those credentials in chat when you ask
- Choose between options when you present a choice
- Type `verify`-style continuation keywords when you've stopped to wait

## Verifier script template

Verifiers still exist and still get deleted on full pass. The orchestrator runs them; the user never does.

```bash
#!/usr/bin/env bash
set -euo pipefail
set -a; source .env; set +a

SERVICE="<service-name>"

if [ -z "${VAR_NAME:-}" ]; then
  echo "FAIL: $SERVICE — VAR_NAME is empty in .env"
  exit 1
fi

HTTP_CODE=$(curl -sS -o /tmp/missions-verify-body -w "%{http_code}" \
  https://api.example.com/v1/account \
  -H "Authorization: Bearer $VAR_NAME" || echo "000")

case "$HTTP_CODE" in
  2*) echo "PASS: $SERVICE" ;;
  401) echo "FAIL: $SERVICE — 401 unauthorized; the credential you pasted appears invalid." ;;
  4*) echo "FAIL: $SERVICE — HTTP $HTTP_CODE; check the credential type matches what the service expects." ;;
  5*|000) echo "FAIL: $SERVICE — HTTP $HTTP_CODE; provider unreachable." ;;
esac

rm -f /tmp/missions-verify-body
[ "${HTTP_CODE:0:1}" = "2" ] && exit 0 || exit 1
```

For MCP verifiers, the script is different — it just attempts a tool listing:

```bash
#!/usr/bin/env bash
SERVICE="<service>-mcp"
if claude mcp list 2>/dev/null | grep -q "^$SERVICE"; then
  echo "PASS: $SERVICE"
else
  echo "FAIL: $SERVICE — not registered. Re-run claude mcp add."
fi
```

## Service catalogue (with MCP availability flagged for search)

For each service the project needs, **search before relying on this catalogue** — it may be out of date by the time you read it. The table is a starting point, not a source of truth.

| Service | Type | MCP available? (verify by search) | What to ask user for |
|---|---|---|---|
| Supabase | mcp + database | Yes — `@supabase/mcp-server-supabase` (verify package name) | Project URL, new secret key (`sb_secret_...` format) |
| Postgres (self-hosted) | database | n/a | `DATABASE_URL` connection string |
| Stripe | api (+ MCP coming) | Search current state | Secret key (`sk_test_...` or restricted `rk_...`) |
| Resend | api | Probably not | API key |
| Anthropic | api | n/a (provider for Claude) | API key (`sk-ant-...`) |
| OpenAI | api | n/a | API key (`sk-proj-...` for new projects) |
| Twilio | api | Search current state | Account SID, Auth Token |
| AWS S3 | api | Search for `aws mcp` | Access key, secret key, region, bucket name |
| GitHub | mcp | Yes — `@modelcontextprotocol/server-github` (verify) | Personal access token with required scopes |
| Linear | mcp | Yes (verify package) | API key |
| Notion | mcp | Yes (verify package) | Internal integration secret + database/page IDs |
| Sentry | api or mcp | Search current state | DSN |
| Playwright (for UX validator) | mcp | Yes — `@anthropic/mcp-playwright` (verify) | Nothing — fully automated |
| Vercel | api | Search current state | Token |
| Cloudflare | api or mcp | Search | API token |

For each row, the **first action** in setup is always: web-search to confirm current status. Trust the search, not the table.

## Edge cases the orchestrator does NOT handle

Some things genuinely require user action and you cannot delegate them away:

- **Account creation.** Signing up at a provider requires accepting terms and often providing payment info. The user does this in their browser.
- **Production OAuth callbacks.** Configuring redirect URIs in a provider dashboard.
- **Domain ownership verification.** DNS records, MX entries.
- **Payment / billing setup.** Adding a card to Stripe, choosing a plan.
- **MCP server registration that requires file edits to Claude Code's settings JSON** — you should use `claude mcp add` instead, which handles this. Only fall back to editing the settings JSON if `claude mcp add` doesn't support the case.
- **Anything requiring sudo / admin install on the user's machine.** If a service needs a system-level dependency the user doesn't have, ask for permission before attempting; if denied, fall back to a Docker-based alternative or note in the manifest that this service needs user setup.

For any of these, in chat: state plainly what the user needs to do, in two or three sentences, then wait for them to come back. Don't write a long tutorial. Don't ask them to verify multiple things at once.

## Summary of the new flow

1. **Search for current versions, auth methods, and MCP availability.** Always.
2. **Write a manifest** that says, per service, "what I'll do" vs "what I need from you" — narrowly scoped to data, not actions.
3. **Per service: tell user what data you need + short pointer, wait, paste-receive, run all install/config commands yourself, verify.**
4. **On failure: ask for the data again, do not ask the user to "try running" anything.**
5. **On full pass: write `mcp-registry.md`, clean up, write VERIFIED, move on.**

The user's experience is: read what data is needed, find it in a dashboard, paste it. Repeat for N services. That's the whole phase.
