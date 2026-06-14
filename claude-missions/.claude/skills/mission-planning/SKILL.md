---
name: mission-planning
description: How to produce the validation contract, draft plan, and tech-decisions from the description and discovery answers. Web-searches for current versions before committing to anything. Targets fine-grained feature decomposition (more features = better). Features here are DRAFTS — the /mission-tasks phase enriches them. Activate during /mission-plan.
---

# Mission planning

A mission is a long-horizon goal completed by a team of subagents under your
orchestration. Good planning is the entire game — if the contract is right,
the versions are current, and features are sized correctly, execution is
mostly automatic.

## Inputs

By the time this skill is loaded, the user has already completed:

- `description.md` — their free-form description of the app
- `discovery/round-1.md` — 30 answered multiple-choice questions
- `discovery/round-2.md` — 15 gap-closing follow-ups

Re-read all three before producing anything.

## Version freshness is mandatory

Before writing `tech-decisions.md`, you MUST load the `version-freshness`
skill and web-search for current information on every framework, library,
runtime, auth scheme, and external service the discovery answers imply.
Your training data is out of date. Writing a plan that references stale
package names, deprecated libraries, or legacy auth keys is a failure mode,
not a minor issue.

Specifically, search for:

- The current stable major version of the chosen framework
- The current package name (libraries get renamed — Lucia became better-auth, NextAuth became Auth.js, etc.)
- The current authentication method for each external service (Supabase, Stripe, OpenAI, AWS — all have current vs legacy key formats)
- Whether an official MCP server exists for each service
- The current canonical setup commands (`create-next-app` flags, `supabase init` syntax, etc.)

Annotate each version choice in `tech-decisions.md` with the URL you verified it against and the date. This makes the freshness auditable.

## Drafts, not final specs

The features you produce in `plan.md` and the per-feature spec files are
**drafts**. They contain enough scope and assertion mapping for a human to
review the plan as a whole, but they are NOT fully implementation-ready.
The next phase — `/mission-tasks` — interrogates the user for 20 questions
per feature and enriches each spec with the answers.

Therefore:

- The draft spec contains: title, milestone, dependencies, assertion IDs covered, scope bullets, approximate files, brief notes.
- The draft spec does NOT need: specific implementation pattern, data shape, state location, error-handling strategy, performance budget, or detailed acceptance criteria — those come from clarification.
- Keep drafts concise. ~10–25 lines per feature is right.

## The four planning artefacts (in this order)

### 1. `validation-contract.md` — FIRST

The contract drives features, not the other way around. Use the
`validation-contracts` skill for format and quality rules. Cover:

- Every functional capability the user described
- Every behavioural implication of discovery answers
- Every constraint from category F of round-1 (test coverage, performance budget, i18n, compliance, docs)
- Every integration's happy path AND its failure path

For a medium project, expect **60–200 assertions**. Smaller is suspicious.

### 2. `plan.md` — draft features and milestones

**Sizing rule (the most important rule in this skill):**

> Target features of 15–45 minutes of worker wall-clock time. **More features
> is better.** A medium project should have **30–100 features** across **4–10
> milestones**. Large projects 100–250 features.

Reject your own draft if any feature looks like it would take more than 45
minutes. Split it. Examples:

- ❌ "Implement user authentication" — far too big
- ✅ Split into: `password-hashing-utility`, `signup-endpoint`, `signup-validation`, `signup-email-trigger`, `login-endpoint`, `login-rate-limit`, `session-cookie-issuance`, `session-cookie-verification`, `logout-endpoint`, `auth-middleware`, `auth-middleware-tests`

**Draft feature file format** at `missions/<id>/features/F<NNN>-<slug>.md`:

```markdown
# F<NNN>: <one-line title>

**Milestone:** M<N> — <name>
**Estimated worker time:** <15|30|45> minutes
**Depends on:** F<NNN>, F<NNN>  (or "none")

## Assertion IDs covered
- AS-NNN: <assertion text>

## Draft scope
<2–6 bullet points>

## Files (approximate)
<paths>

## Notes for clarification
<context for /mission-tasks>
- MCP at run: <none | Supabase MCP for schema/RLS | GitHub MCP | ... — if feature touches live external state, note which MCP from tech-decisions>
```

**Milestone structure:**

- **M1 Foundation** (always first, always small): project skeleton via the **current** setup command (verified via search, not memory), dependencies at their current versions, `.env.example` complete, CI green on an empty test, one runnable hello-world route/command. No business logic.
- **M2..M(N-1)**: each milestone ends in a coherent, demoable state.
- **M(N) Polish/QA**: final hardening — accessibility audit, performance pass, doc generation, deploy checklist.

### 3. `tech-decisions.md`

Every version choice carries a search-verified annotation. Required sections in exact order:

```markdown
# Tech decisions

## Stack
- Language: <e.g. TypeScript 5.x>  <!-- verified against https://typescriptlang.org as of 2026-MM-DD -->
- Framework: <e.g. Next.js 15.x with App Router>  <!-- verified against https://nextjs.org/docs as of 2026-MM-DD -->
- Database: <e.g. Supabase Postgres>  <!-- verified against https://supabase.com/docs as of 2026-MM-DD -->
- Auth: <e.g. Supabase Auth with new secret keys (sb_secret_* format)>  <!-- verified against https://supabase.com/docs/guides/api/api-keys as of 2026-MM-DD -->

## Libraries used
<bullet list with current version constraints AND one-line justification>

## Libraries explicitly avoided
<bullet list with reasons — especially any deprecated alternatives you considered>

## File layout
<tree showing the top 3 levels>

## External services needed
- Supabase (MCP available — will use @supabase/mcp-server-supabase; needs Project URL + secret key)
- Stripe (no MCP confirmed; needs secret key; SDK: `stripe` v current-major)
- Resend (no MCP; needs API key; SDK: `resend` v current-major)
- Playwright (MCP available — @anthropic/mcp-playwright)
...

## How to run the app
\`\`\`
<exact command, verified current>
\`\`\`

## How to run tests
\`\`\`
<exact command — the pre-worker-exit hook parses this section verbatim>
\`\`\`

## How to run linter
\`\`\`
<exact command>
\`\`\`

## How to run type-check
\`\`\`
<exact command>
\`\`\`

## Conventions
<naming, file organization, error handling, logging — any rule a worker should follow>
```

### 4. Verify and present

After writing all three:

1. Confirm every assertion is referenced by at least one feature.
2. Confirm every feature lists at least one assertion ID.
3. Print summary:

```
Milestones:   N
Features:     M    (target: 30–100 medium / 100–250 large)
Assertions:   K    (target: 60–200 medium)
Coverage:     100% / GAPS: ...
Versions verified via web search: <list>
Services with MCP available: <list>
Estimated clarification questions to come: 20 × M = X
```

4. Tell the user to review and type `approved`.

## Reject your own vague plans

Before showing the plan to the human, re-read each feature description. If
any feature lacks specific scope bullets or could be interpreted multiple
ways, rewrite it.

## When to escalate to the human mid-plan

- A version search returns conflicting recommendations and the discovery answers don't resolve which to use → ask the user
- A service mentioned in discovery has been deprecated/sunset since your training data → propose a replacement and ask
- A search reveals that an answer the user gave in discovery is no longer reasonable (e.g. they chose a library that no longer exists) → flag and ask
