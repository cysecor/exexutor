---
description: Set up and verify every external service the mission needs. The orchestrator does all installation, MCP registration, env file writing, and verification. The user provides only credentials and choices.
allowed-tools: Bash, Read, Write, Edit, WebSearch, WebFetch
---

## Pre-flight

1. Read `missions/CURRENT`. Abort if missing.
2. Verify `missions/<id>/APPROVED` exists. Abort with "Run `/mission-plan` and approve first." if not.
3. Verify `missions/<id>/tech-decisions.md` exists.
4. Load skills in this order: `version-freshness`, then `connection-setup`.

## State-based dispatch

Check `missions/<id>/connections/manifest.md`:

- Doesn't exist → start at **Step 1 — Search and manifest**.
- Exists, some services PENDING → resume at the next PENDING service.
- All services PASS, no `VERIFIED` marker → write `VERIFIED` and exit.
- `VERIFIED` exists → tell user to run `/mission-tasks`.

## Step 1 — Search and manifest

1. Read `tech-decisions.md` "External services needed" section, discovery answers, and validation contract. List every external dependency.

2. **For each service, web-search to determine current state.** Required searches per the version-freshness skill:
   - `<service> Claude Code MCP` or `<service> MCP server` — does an official MCP exist?
   - `<service> API keys current` or `<service> latest authentication` — what's the current credential format?
   - `<service> SDK npm latest` (or pip / cargo / equivalent) — what's the current package name and version?

3. **Write `connections/manifest.md`** per the connection-setup skill's format. Each row has columns: Service, Type, What I'll set up, What I need from you, Status. The "What I'll set up" column lists the commands you will run (`claude mcp add ...`, `npm install ...`, `.env` writes). The "What I need from you" column lists only data items (URLs, keys, choices) — never actions.

4. Output a brief summary message:

   > I found N external services. I've checked current versions and MCP availability for each (X services have official MCP servers, which I'll use).
   >
   > I'll set up each one. For each, I'll tell you what data I need and where to find it. You paste it in chat; I do everything else.
   >
   > Starting with <first service>...

5. Proceed directly to Step 2 for the first PENDING service.

## Step 2 — Per-service setup loop

For each PENDING service in manifest order:

### 2a. Announce and request data

Send ONE message to the user containing:

- **What this service is for** (one sentence + assertion IDs it supports)
- **Type** (MCP / API / OAuth app / database / CLI tool)
- **What I'll do** (terse bullet list of commands you will run — install package, register MCP, write env)
- **What I need from you** (specific data items with one-sentence pointers to where in the provider's dashboard, e.g. "Project URL: Project Settings → API → Project URL")

Do not write a 10-step tutorial. Two or three short pointers, then ask.

If the service requires the user to **sign up first** (no account yet), say so and wait. When they confirm an account exists, repeat the data-request message.

### 2b. Wait

Stop. The user's next message will contain the data.

### 2c. Receive data

Parse the user's message. Identify the credential values, URLs, choices. If anything is missing or ambiguous, ask only about the missing pieces.

### 2d. Execute setup

Use the `Bash` tool to do the work:

**For MCP services:** invoke `claude mcp add` with the appropriate arguments. Example:

```bash
claude mcp add supabase --env SUPABASE_URL="<url>" --env SUPABASE_SECRET_KEY="<key>"
```

After registration, run `claude mcp list` and confirm the service appears.

**For API-based services:** install the SDK and write env vars. Example:

```bash
npm install @supabase/supabase-js
{
  echo "SUPABASE_URL=<url>"
  echo "SUPABASE_SECRET_KEY=<key>"
} >> .env
```

Use append (`>>`) so existing `.env` entries are preserved. Never print credential values in any visible output — write directly to `.env` from the Bash tool's quoted argument.

**For database services:** construct the `DATABASE_URL` from user-supplied components, write to `.env`. If the service ships its own CLI (e.g. Supabase CLI for migrations), install it.

**For OAuth apps:** the user provides client ID + client secret pair; write both to `.env` with conventional names (`<PROVIDER>_CLIENT_ID`, `<PROVIDER>_CLIENT_SECRET`).

### 2e. Verify

Generate `connections/verify/<service>.sh` per the connection-setup skill's template. Run it. Read the output line.

### 2f. Update manifest and report

Update the Status column in `connections/manifest.md` to PASS or FAIL. Tell the user the result in one sentence. Never echo credential values.

### 2g. Handle FAIL

In chat: state the safe error message and ask the user to verify the data they pasted. Offer to retry with corrected values. Don't tell them to "run" anything — ask for the data again.

### 2h. Advance

On PASS, move to the next PENDING service. On FAIL, stay on this service until it passes or the user explicitly skips it.

## Step 3 — Write MCP registry for workers

When every service in the manifest is PASS:

1. Run `claude mcp list` via Bash. Capture exact server names from the output.
2. Write `missions/<id>/connections/mcp-registry.md` per the connection-setup skill (Step 3 — MCP registry). Include tool prefixes and `Worker use: yes|no` per service.
3. Confirm every manifest row with Type containing `mcp` has a matching registry row (except validator-only servers like Playwright → `Worker use: no`).

## Step 4 — Completion

```bash
rm -f missions/<id>/connections/verify/*
date -u +"%Y-%m-%dT%H:%M:%SZ" > missions/<id>/connections/VERIFIED
```

**P-1 checklist before exit:** all commands run by you; user only pasted data in chat; `mcp-registry.md` written; verifiers deleted; `VERIFIED` exists.

Output:

> All <N> services set up and verified. MCP registry written for `/mission-run`. Verifier scripts cleaned up.
>
> Next: `/mission-tasks` to clarify each feature.

## Hard rules

- **Search before writing.** Every service's setup commands and credential names must come from a current docs search, not from memory.
- **Prefer MCP over raw SDK** when an official MCP server exists for the service.
- **You run every command.** The user never opens a terminal during this phase.
- **Never echo credential values** in any output, error message, or manifest row.
- **`.env` is the only file that receives credential values.** Never write them to source code, tutorials, manifests, commit messages, or logs.
- **Account creation, browser-only steps, and payment setup** are the only places where you ask the user to do something themselves. Even then, the instruction is two or three sentences, not a tutorial.
- **If `claude mcp add` fails** with an authentication or schema error, search the current docs for the correct invocation — do not guess.
- **Refuse non-developer credentials** in chat: credit cards, SSNs, banking details, government IDs. These do not belong in `.env`.
