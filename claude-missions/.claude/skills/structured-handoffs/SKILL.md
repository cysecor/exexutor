---
name: structured-handoffs
description: Mandatory handoff template every worker fills out before exiting. The pre-worker-exit hook validates this file and blocks the worker if anything is missing. Activate inside any worker subagent.
---

# Structured handoffs

Every worker writes `missions/<id>/handoffs/F<NNN>-handoff.md` before
exiting. This is the **only** channel through which the worker's knowledge
reaches the orchestrator. The pre-worker-exit hook rejects the worker if the
file is missing, any required section is missing, or if Status is COMPLETE
but tests don't pass / git is dirty.

## Required template

Copy this exactly. Every section header must be present even if a section's
body is empty.

```markdown
# Handoff: F<NNN> — <feature name>

## Status
<COMPLETE | BLOCKED | PARTIAL>

## Assertions covered
<one line per assertion ID assigned to this feature, with the result you observed in your own test run>
AS-NNN: PASS | FAIL | UNTESTED — <one-line note>

## Files changed
<list of paths, one per line>

## Commands run
<one line per significant command, with its exit code>
`npm test` (0)
`npm run lint` (0)
`npm run typecheck` (0)

## Decisions made
<bullet list of non-obvious choices and why. Example: "Chose cookie session over JWT because tech-decisions.md says no client-side tokens.">

## Out-of-scope work needed
<features or fixes you noticed but did NOT do. Specific enough that a future worker can pick this up cold without re-investigating.>

## Blockers
<empty if Status is COMPLETE. If BLOCKED or PARTIAL: what stopped you, what you tried, what the orchestrator should do next.>

## Autonomous decisions
<empty if none. Optional during ZERO_QUESTIONS run: defaults you applied when spec was ambiguous.>

## Notes for the next worker
<anything else useful — gotchas, surprises, links to docs you used, MCP tools used>
```

## Rules

- **Don't lie about status.** The hook re-runs your test command from `tech-decisions.md` when status is COMPLETE. If it doesn't pass, you'll be forced back into the loop with the failed test output. Set status to PARTIAL or BLOCKED truthfully and document.
- **Assertions covered must list every assertion ID assigned to your feature.** The hook diffs this list against `plan.md`. Missing IDs block exit.
- **Commands run must include the test command.** The hook checks for this.
- **Blockers section is mandatory when status isn't COMPLETE.** An empty Blockers section with a non-COMPLETE status is treated as a missing section.

## When you find a real blocker

Mark status `BLOCKED`. In Blockers, write (all four lines required):

```
BLOCKER: <one-line description>
TRIED: <what you attempted>
NEEDED: <what would unblock — a decision, a new dep, a contract change, a schema migration>
SUGGESTED FOLLOWUP: <a one-paragraph spec for a feature that would unblock you>
```

`SUGGESTED FOLLOWUP` is **required** for `BLOCKED` and `PARTIAL`. The orchestrator
creates a follow-up feature from it during `/mission-run` without asking the user.

If you applied a default without user input, also fill **Autonomous decisions**:

```
AUTONOMOUS_DECISION: <what you chose and why>
```

Do not write "needs human input" as a reason to stop the run — phrase
`SUGGESTED FOLLOWUP` so the next worker can execute without user chat.
