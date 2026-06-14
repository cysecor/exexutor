---
name: version-freshness
description: Forces the orchestrator to web-search for current versions, current authentication methods, and current setup patterns before writing tech-decisions, connection manifest entries, or anything else that depends on the state of the world today. Activate during /mission-plan and /mission-connect. NEVER skip this.
---

# Version freshness

Your training data is months or years out of date. Every framework version, every authentication scheme, every package name, every MCP server, every API surface has potentially changed since your knowledge cutoff. **You must web-search for current information before committing to any of these in writing.** Asking a user to use the old version of anything is a defect, not a quirk.

## When to search (mandatory triggers)

Search **before** writing:

- A framework or runtime version into `tech-decisions.md` (Next.js, React, Vue, FastAPI, Rails, Django, Node, Python, etc.)
- A library version into the libraries list (every dependency the project will install)
- An authentication scheme into a connection manifest (key formats, header names, scopes)
- An MCP server reference (does this service have one? What's the current install command?)
- A connection method for any third-party service (Supabase, Stripe, Clerk, Auth0, OpenAI, Anthropic, AWS, etc.)
- Any setup command (`create-next-app`, `prisma init`, `supabase init` — flags change)

If you find yourself about to type a version number, a CLI command, a key name, or an API endpoint from memory — **stop and search first**.

## What to search for

For each service in the discovery answers and tech-decisions list:

1. **Current stable version.** Search `<framework> latest stable version` or `<library> npm latest`. Note the version. If it's a major version newer than what you'd reach for from memory, read the migration notes.

2. **Current authentication method.** Many providers have changed their key formats recently. Examples (verify each before using):
   - **Supabase** moved from `anon` / `service_role` JWT keys to publishable / secret keys with new prefixes. Search `Supabase API keys current` and check the docs before writing connection manifest entries.
   - **Stripe** introduced restricted keys; the old "secret key" is still valid but `rk_` keys are preferred for scoped access.
   - **OpenAI** project-scoped keys (`sk-proj-...`) supersede org keys for new projects.
   - **Anthropic** keys are stable but model names change frequently.
   - **AWS** access-key vs IAM-role vs SSO — depends on the deployment context.

3. **Current MCP server.** Search `<service> MCP server claude code` or `<service> mcp install`. If an official MCP exists, prefer it over raw API integration. The connection-setup flow then becomes "install MCP, supply credentials" instead of "wire up SDK".

4. **Current setup command.** `create-next-app` flags change. `supabase init` becomes `supabase link`. Always pull the canonical command from the provider's docs, not from memory.

## How to search

Use the web_search and web_fetch tools available in Claude Code. Construct queries that include the current year if relevant — "Next.js latest stable version 2026" returns better results than "Next.js latest" when your priors might pull a 2024 answer.

Prefer authoritative sources: the project's own docs, the provider's official documentation, the npm/PyPI registry page. Avoid year-old blog posts and StackOverflow answers as primary sources for version or auth questions; they're often the trap.

After fetching the relevant doc page, **quote the specific version or instruction you're going to use** in a comment in `tech-decisions.md` so the user can see where it came from:

```markdown
## Stack

- Next.js 15.x  <!-- verified against https://nextjs.org/docs as of <date> -->
- React 19.x    <!-- verified against https://react.dev as of <date> -->
- Supabase JS client v2.x with new publishable/secret keys  <!-- verified against https://supabase.com/docs/guides/api/api-keys as of <date> -->
```

This makes the search auditable. If a worker later finds that the doc has changed, they can re-verify.

## What to do when search results disagree with your priors

Trust the search. If Supabase docs now say "publishable key" and your memory says "anon key", write publishable. Memory is the unreliable source here.

If search results themselves disagree (e.g. one blog says one thing, the official doc says another), trust the official doc.

If the official doc itself is ambiguous (e.g. two valid auth methods documented), note both in tech-decisions and ask the user in the next /mission-tasks round which to use.

## Search budget

For a medium project, expect 5–15 searches during `/mission-plan` and another 5–15 during `/mission-connect`. This is not optional cost — skipping it means writing a plan that asks the user to do things that don't work.

Do **not** ask the user "should I check?" — just check. The user's time is what we're optimizing for; web searches happen silently.

## What you do NOT need to search for

- Stable, decades-old protocols (HTTP, SQL, basic Linux commands)
- Language syntax for well-established languages (Python, JS, Go, Rust at non-bleeding-edge versions)
- Algorithmic and conceptual knowledge (data structures, common patterns)
- Things the user explicitly specified in discovery (if they said "use X v3", use X v3)

The principle: search anything where the state of the world changes faster than your training data. Don't search things that have been stable for years.

## Reporting freshness to the user

In the summary table at the end of `/mission-plan`, add a line:

```
Versions verified via web search: <list of N services checked>
```

So the user knows you actually did the work.
