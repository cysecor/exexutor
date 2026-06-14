---
description: Per-feature 20-question clarification. Iterates through every feature in plan order, runs Round A (10 task) + Round B (5 follow-up + 5 done) per feature. Resumable. Supports `accept`, `accept and continue`, `skip`, `stop`.
allowed-tools: Bash, Read, Write, Edit
---

## Pre-flight

1. Read `missions/CURRENT`. Abort if missing.
2. Verify all of these exist; abort with the next step if any is missing:
   - `missions/<id>/APPROVED` → "Run `/mission-plan` and approve first."
   - `missions/<id>/connections/VERIFIED` → "Run `/mission-connect` and verify all services first."
3. Load the `task-clarification` skill.

## State-based dispatch

For each feature listed in `plan.md`, check whether `missions/<id>/clarifications/F<NNN>-clarification.md` exists.

- If every feature has a clarification → print "All features clarified. Run `/mission-run`." and exit.
- Otherwise, identify the **next un-clarified feature** in plan dependency order. Call it F<NNN>.

If a previous `/mission-tasks` session set the `accept-and-continue` flag at `missions/<id>/clarifications/AUTO_ACCEPT` → generate clarifications for ALL remaining features using ★ defaults (no user interaction). Mark each `Mode: accept-and-continue` at the top. Tag every feature `[CLARIFIED-AUTO]` in plan.md. Print summary and exit pointing at `/mission-run`.

## The per-feature loop

For F<NNN>:

### Step 1 — gather context

Read in this order:
1. `missions/<id>/features/F<NNN>-*.md` — the draft feature spec
2. `missions/<id>/discovery/round-1.md` and `round-2.md`
3. `missions/<id>/tech-decisions.md`
4. `missions/<id>/validation-contract.md` — the assertion IDs assigned to F<NNN>

### Step 2 — emit Round A (10 task questions)

Per the `task-clarification` skill:

- Adapt the 10 default categories to this feature type (UI / data / job / library — see skill).
- For each question, pick the ★ recommended option using the priority order from the skill (discovery answer → tech-decisions convention → milestone context → safest default).
- Format as a single structured message. Title: `# F<NNN> Clarification — Round A (10 questions)`. Footer: a "How to answer" block explaining accept / accept-and-continue / skip / stop.
- **Stop.** Wait for the user's reply.

### Step 3 — parse Round A

When the user replies:

- If `accept` → take ★ defaults for all 10. Continue to Step 4.
- If `accept and continue` → take ★ defaults for all 10. Write `missions/<id>/clarifications/AUTO_ACCEPT`. Continue to Step 4 for this feature, then auto-generate clarifications for all remaining features as described in "State-based dispatch" and exit.
- If `skip F<NNN>` or `skip` → mark this feature `[SKIPPED]` in plan.md and proceed to the next un-clarified feature.
- If `stop` → exit immediately without writing partial clarification.
- Otherwise → parse per-question answers. Any unanswered question gets ★ default. If a custom answer appears (`3: custom — <text>`), capture verbatim.

### Step 4 — emit Round B (5 follow-ups + 5 done)

- Generate 5 follow-up questions per the skill's heuristics, informed by the Round A answers just received.
- Generate 5 "definition of done" questions (mostly fixed template from the skill, lightly adapted to the feature type).
- Combined into a single structured message. Title: `# F<NNN> Clarification — Round B (5 follow-ups + 5 definition of done)`. Same footer.
- **Stop.** Wait for the user's reply.

### Step 5 — parse Round B and write outputs

- Apply the same parsing rules as Step 3.
- Write `missions/<id>/clarifications/F<NNN>-clarification.md` per the skill's template, with all 20 questions, options, ★ markers, and chosen answers.
- **Enrich** `missions/<id>/features/F<NNN>-*.md` by appending the "Clarified implementation" and "Definition of done" sections per the skill. Use `Edit` — never overwrite the original feature spec content.
- Tag the feature `[CLARIFIED]` in plan.md (append the tag to that feature's bullet).

### Step 6 — continue or stop

- If user typed `stop` at any point → exit.
- Otherwise → loop back to "State-based dispatch" to find the next un-clarified feature.

## Completion

When every feature in plan.md has either `[CLARIFIED]`, `[CLARIFIED-AUTO]`, or `[SKIPPED]` → print:

> Clarification complete.
>   <N> features clarified interactively
>   <M> features auto-accepted
>   <K> features skipped
>
> Run `/mission-run` to start execution. Skipped features will be picked up only if their dependencies allow — review plan.md if needed.

## Hard rules

- **One feature at a time.** Never present questions for multiple features in one message.
- **Both rounds for each feature** unless `accept` shortcuts it. Don't merge the rounds.
- **Never write a partial clarification.md.** If the user types `stop` mid-feature, exit cleanly without writing — they can resume with `/mission-tasks` and re-do Round A.
- **The enriched feature spec is append-only.** Never delete or rewrite the original sections written by `/mission-plan`.
- **Follow-up features created during `/mission-run`** (when validators reject) do NOT come through here — they inherit the parent feature's clarification per the skill's "Follow-up features" section.
