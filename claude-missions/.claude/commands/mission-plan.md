---
description: Produce the validation contract, plan, and tech-decisions document. Web-searches current versions and current setup patterns before committing to any stack choice. Awaits human approval.
allowed-tools: Bash, Read, Write, WebSearch, WebFetch
---

## Pre-flight

1. Read `missions/CURRENT` for the active mission ID. Abort if missing.
2. Verify these files exist; abort with the next step if any is missing:
   - `missions/<id>/description.md` → "Run `/mission-scope` first."
   - `missions/<id>/discovery/round-1.md` → "Run `/mission-discover` first."
   - `missions/<id>/discovery/round-2.md` → "Run `/mission-discover` to complete round 2."
3. Load skills in this order:
   1. `version-freshness` — required reading; controls when to search
   2. `validation-contracts`
   3. `mission-planning`

## Steps

1. Read description + both discovery rounds. Internalize the user's intent and constraints.

2. **Web-search for current versions and patterns.** Per the version-freshness skill, search before committing to any framework, library, or service in writing. For a typical web project the searches include:
   - The chosen framework's latest stable version (Next.js, Remix, SvelteKit, FastAPI, etc.)
   - The chosen ORM / database client's current package name and major version
   - The chosen auth library's current state (libraries get deprecated; Lucia → better-auth, NextAuth → Auth.js, etc.)
   - The chosen UI library's current version (Tailwind v4 vs v3, shadcn/ui current install command)
   - The Node / Python / runtime version that's current LTS or recommended
   - For each external service in discovery answers: does an official MCP exist? What's the current auth scheme?

   Record what you find. Add inline comments referencing the source URL where you got each version, per the version-freshness skill.

3. Produce three files, **in this order** (do not skip):

   ### a. `missions/<id>/validation-contract.md`
   Flat numbered list of `AS-NNN` assertions per the `validation-contracts` skill. For a medium project, 60–200 assertions.

   ### b. `missions/<id>/plan.md`
   Features grouped into milestones in dependency order. Per the `mission-planning` skill, target many small features — 15–45 minutes each. A medium project should have 30–100 features across 4–10 milestones. Each feature lists assertion IDs covered.

   First milestone is always **Foundation**: project skeleton via current setup commands, dependencies installed, CI green on empty test, runnable hello-world. No business logic.

   ### c. `missions/<id>/tech-decisions.md`
   Stack choices derived from the discovery answers AND from the current versions you just searched. Required sections:
   - `## Stack` (with inline `<!-- verified against <URL> as of <date> -->` comments per version-freshness skill)
   - `## Libraries used` (each with a one-line justification AND a version constraint based on what you found via search)
   - `## Libraries explicitly avoided` (each with reason — including deprecated alternatives you considered and rejected)
   - `## File layout`
   - `## External services needed` (one bullet per service, with a note on whether you found an MCP for it; the connect phase uses this list)
   - `## How to run the app` (fenced command block)
   - `## How to run tests` (fenced command block — the pre-worker-exit hook reads this exactly)
   - `## How to run linter` (fenced command block)
   - `## How to run type-check` (fenced command block)
   - `## Conventions` (naming, file organization, error handling, logging — anything a worker should follow)

4. Verify coverage: every assertion in the contract is referenced by at least one feature in the plan. Print the result.

5. Print a summary:

   ```
   Milestones: N
   Features:   M    (target: 30–100 medium / 100–250 large)
   Assertions: K    (target: 60–200 medium)
   Coverage:   100% / GAPS: ...
   Versions verified via web search: <list>
   Services with MCP available: <list>
   ```

6. Tell the user verbatim:

   > Review the three files:
   >   - `missions/<id>/validation-contract.md`
   >   - `missions/<id>/plan.md`
   >   - `missions/<id>/tech-decisions.md`
   >
   > I've verified current versions and MCP availability via web search — those are noted in tech-decisions.md.
   >
   > Edit anything you want, then type `approved` to lock the plan.
   > After approval, run `/mission-connect` to set up credentials and external services. I'll do all the installation and configuration; you'll only need to paste credentials when I ask.

7. When the user types `approved`, write `missions/<id>/APPROVED` containing the output of `git rev-parse HEAD 2>/dev/null || echo no-git`. The contract is now immutable.

## Hard rules

- Do not write a version number, package name, CLI command, or auth scheme from memory. Search first per the version-freshness skill.
- Do not produce the plan before the contract. Features exist to satisfy assertions, not the other way around.
- Do not invent requirements not implied by description + discovery.
- Prefer more features over larger features. Reject your own draft and re-split anything that looks like it would take a worker more than 45 minutes.
- If your search finds that a library you'd reach for from memory is deprecated, abandoned, or superseded, **use the current replacement** — not the deprecated one.
