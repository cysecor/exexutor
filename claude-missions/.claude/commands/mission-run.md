---
description: Execute the current mission until every assertion is GREEN. Every feature must be CLARIFIED first. ZERO_QUESTIONS during run — never stop to ask the user. The orchestrator never edits project code — it only spawns workers and validators.
allowed-tools: Bash, Read, Write, Edit, Agent
---

## Pre-flight

1. Read `missions/CURRENT` for the mission ID. Abort if missing.
2. Verify each of these exists, abort with the next step if any is missing:
   - `missions/<id>/APPROVED` → "Run `/mission-plan` and approve."
   - `missions/<id>/connections/VERIFIED` → "Run `/mission-connect` and verify all services."
   - `missions/<id>/connections/mcp-registry.md` → "Run `/mission-connect` to completion (MCP registry missing)."
3. Verify every feature in `plan.md` is tagged `[CLARIFIED]`, `[CLARIFIED-AUTO]`, or `[SKIPPED]`. If any feature is un-clarified → abort with "Run `/mission-tasks` first. <K> features still need clarification."
4. Load skills: `model-selection`, `mission-planning`, `worker-mcp-usage`, `connection-setup` (read-only for registry).
5. If `missions/<id>/model-overrides.yaml` exists, parse it. Pass `model` to each Agent spawn per the override map.

## MCP preflight (mandatory)

1. Run `claude mcp list` via Bash.
2. Read `connections/mcp-registry.md`. For every row in "MCP servers" with `Worker use: yes`, confirm the `MCP server name (CLI)` appears in the list output.
3. If any required worker MCP is missing → abort with: "MCP preflight failed for <service>. Re-run `/mission-connect`." Do not ask the user questions — connect phase is where credentials and MCP registration happen.
4. Initialize or append `missions/<id>/run-log.md` with a header if the file does not exist:

```markdown
# Run log

_Mission: <id>_ _Started: <UTC>_ _Mode: ZERO_QUESTIONS_

Orchestrator decisions during /mission-run (no user prompts).
```

## ZERO_QUESTIONS invariant

During this command you must **never**:

- Ask the user a question or wait for user input
- Stop the run because a worker handoff says "needs human input"
- Pause for confirmation on implementation choices

Instead:

- Create follow-up features from `SUGGESTED FOLLOWUP` (inherit parent clarification per `task-clarification` follow-up rules)
- Append each autonomous decision to `run-log.md` with timestamp and feature ID
- On repeated failure for the same feature chain, apply the loop guard (below)

Recommend the operator run Claude Code with `--dangerously-skip-permissions` so tool approvals do not interrupt the run.

## The loop

Repeat until every assertion in `validation-contract.md` is GREEN across both validators:

### a. Pick the next feature

Read `plan.md`. Find the next feature whose:

- tag is `[CLARIFIED]` or `[CLARIFIED-AUTO]` (NOT `[SKIPPED]` or `[DEFERRED]`)
- handoff doesn't exist OR existing handoff Status is `BLOCKED`/`PARTIAL` and no follow-up has been created
- declared dependencies are all COMPLETE

If no such feature exists AND there's an open milestone with no validation report → go to (d).
If every milestone has both scrutiny and ux reports GREEN → print "Mission complete." and exit.

### b. Loop guard

Before spawning a worker for feature F<NNN>, count follow-ups in the same chain (same root feature ID in `plan.md` bullets or handoff lineage). If **5 or more** attempts already exist for that assertion root:

1. Tag the feature `[DEFERRED]` in `plan.md`
2. Append to `missions/<id>/run-deferred.md`:

```markdown
## F<NNN> — deferred after 5 attempts
_Assertion roots: AS-..._ _Last handoff: ..._
```

3. Log in `run-log.md` and continue to (a) with the next feature — do not ask the user.

### c. Spawn the worker

Use the `worker` subagent. Pass a prompt containing ONLY:

```
Feature spec (clarified): missions/<id>/features/F<NNN>-<name>.md
Clarification file:       missions/<id>/clarifications/F<NNN>-clarification.md
Assertion IDs assigned to you: AS-NN, AS-NN, AS-NN
Tech decisions: missions/<id>/tech-decisions.md
MCP registry: missions/<id>/connections/mcp-registry.md
Mission ID: <id>

Run mode: ZERO_QUESTIONS — never ask the user anything. Resolve ambiguity from
  clarified spec, clarification ★ defaults, tech-decisions, and discovery files.
  If blocked, set Status BLOCKED/PARTIAL with SUGGESTED FOLLOWUP; do not wait
  for human reply.

For services in the MCP registry with Worker use: yes (e.g. Supabase), use MCP
  tools to introspect and verify live schema/policies when the feature touches
  that service.

Credentials are in .env at repo root. Load via the project's standard mechanism.
Never log credential values.

Read your feature spec — including "Clarified implementation" and "Definition of
done" — FIRST. Follow them. If you disagree with a clarified answer, set Status
to BLOCKED and explain with SUGGESTED FOLLOWUP.

Write tests referencing assertion IDs in the test name. Commit before exiting.
Fill out the handoff per the structured-handoffs skill — every section mandatory.
```

Do NOT pass the orchestrator's conversation history. The worker starts fresh.

### d. After the worker returns

Read `missions/<id>/handoffs/F<NNN>-handoff.md`. Based on Status:

- **COMPLETE** — mark the feature done in `plan.md` (append `[COMPLETE]` to its bullet) and loop back to (a).
- **PARTIAL** — read Out-of-scope and Blockers. Create a follow-up feature `F<NNN+m>-<name>.md` in the current milestone covering what was missed. Inherit parent clarification per `task-clarification` — DO NOT run `/mission-tasks`. Log in `run-log.md`. Loop back to (a).
- **BLOCKED** — always create follow-up from `SUGGESTED FOLLOWUP` in Blockers (inherit clarification). Log in `run-log.md`. **Never stop the run to ask the user**, even if the handoff mentions "needs human input" — encode the decision as a follow-up spec and continue.

If MCP failure is cited (missing tools), run `claude mcp list` once. If registry server is missing, append to `run-log.md` and create an unblocker follow-up feature "restore-mcp-<service>"; do not ask the user during run.

### e. Milestone boundary — scrutiny validator

When every feature in a milestone is COMPLETE or `[DEFERRED]` (and no incomplete non-deferred features remain), spawn the `scrutiny-validator` subagent. Pass:

```
Milestone: M<N>
Mission ID: <id>
```

Read `missions/<id>/milestones/M<N>-scrutiny.md`. For each FAIL:

- Append a new feature to `plan.md` covering the fix
- Inherit failing assertion ID(s) and parent clarification
- Log in `run-log.md`
- Loop back to (a)

Do NOT proceed to UX validation until scrutiny is fully GREEN (no FAIL).

If the same milestone fails scrutiny **twice in a row**, do not ask the user — create a milestone-replan follow-up feature bundle, log in `run-log.md`, and continue.

### f. Milestone boundary — UX validator

Once scrutiny is GREEN, spawn the `ux-validator` subagent with the same payload. Read `M<N>-ux.md`. Handle FAIL/INCONCLUSIVE the same as scrutiny — append follow-up features, log, continue. Never stop to ask the user.

When both reports are GREEN, mark the milestone GREEN in `plan.md` and continue.

## Hard rule

You — the orchestrator — never call `Edit` or `Write` on anything outside `missions/<id>/`. If you catch yourself about to do so, stop and spawn a worker for that change. The only files outside `missions/` you may touch are `missions/CURRENT`, `.env.example` (during connect), and `.gitignore` if a critical addition is needed.

During `/mission-run` you may write under `missions/<id>/`: `run-log.md`, `run-deferred.md`, handoffs (workers write these), plan updates, milestone reports, and follow-up feature specs.
