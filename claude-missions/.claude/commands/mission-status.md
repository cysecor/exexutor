---
description: Print progress of the current mission across all seven phases. Read-only and safe at any time.
allowed-tools: Bash, Read
---

## Steps

1. Read `missions/CURRENT`. If absent, print `No active mission. Run /mission-scope to start one.` and exit.
2. Read every state file in `missions/<id>/`. Determine the status of each phase.
3. Print a report in this exact format (omit sections not yet reached):

```
Mission: <id>
Goal:    <first non-blank line of description.md>

PHASES:
  1. Description      ✓  description.md written at <ts>
  2. Discovery R1     ✓  30/30 answered
  3. Discovery R2     ✓  15/15 answered
  4. Plan + Contract  ✓  APPROVED at git <sha>  (M milestones, F features, A assertions)
                          Versions verified via web search: <N> services
  5. Connections      ⏳  3 of 5 verified
       PASS: postgres, anthropic, resend
       MCP registry: connections/mcp-registry.md (N worker MCPs)
       Registered via MCP: supabase, playwright
       PENDING: stripe (user filling .env)
       FAIL: playwright — server not detected
  6. Clarification    ⏳  47 of 72 features clarified
       [CLARIFIED]:      F001..F045 (45 interactive) + F050..F051 (2 auto-accept)
       [SKIPPED]:        F046
       PENDING:          F047, F048, F049, F052..F072 (24)
  7. Execution        —  not started
       Run mode: ZERO_QUESTIONS (when run-log.md exists)
       [DEFERRED]: F0NN (if any)
       Run log: <last line from run-log.md or "—">
       Deferred: <summary from run-deferred.md or "—">

ASSERTIONS (after phase 4):
  GREEN:        AS-001..AS-014 (14)
  IN PROGRESS:  AS-015..AS-024 (10)
  PENDING:      AS-025..AS-067 (43)

MILESTONES (after phase 6):
  M1 Foundation       GREEN  (scrutiny ✓ ux ✓)
  M2 Auth             IN PROGRESS  (3/5 features complete)
  M3..M7              NOT STARTED

LAST HANDOFF: F0NN — <name>
  Status:  COMPLETE | PARTIAL | BLOCKED
  Summary: <one-line synthesis>

OPEN BLOCKERS:
  - F0NN: <one-line>

NEXT ACTION:
  <one line — e.g. "run /mission-tasks to clarify 24 remaining features"
                  or "run /mission-run to execute next feature F046">
```

4. Do not modify any state files.

## How to gather the data

- Phase 1: existence of `description.md`
- Phase 2: existence of `discovery/round-1.md` and `discovery/round-2.md`; count answered questions by counting `← chosen` markers
- Phase 3: existence of `APPROVED`; parse `plan.md` for milestone/feature/assertion counts; grep `tech-decisions.md` for `verified against` annotations to count version-search verifications
- Phase 4: parse `connections/manifest.md` Status column; read `connections/mcp-registry.md` for worker MCP count; identify MCP services by Type `mcp` or `mcp + database`
- Phase 5: parse `plan.md` for feature tags including `[DEFERRED]`
- Phase 6: parse `handoffs/*.md` Status; parse `milestones/*.md` for assertion statuses; read `run-log.md` and `run-deferred.md` if present

The status command should never write or modify state. Read-only inspection.
