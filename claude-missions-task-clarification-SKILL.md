---
name: task-clarification
description: Per-feature 20-question interrogation that turns a draft feature spec into a fully-specified one. Three rounds — 10 task questions, 5 follow-ups, 5 "definition of done" questions. Each question has 4 options with one ★ recommended based on context. Activate during /mission-tasks.
---

# Task clarification

Before a worker subagent implements a feature, the orchestrator interrogates
the user about that specific feature. The output — `clarifications/F<NNN>-clarification.md`
plus an enriched feature spec — replaces vague "implement auth" prompts with
precise specifications that workers and validators can execute against
without guessing.

## The 20 questions per feature

- **Round A** — 10 task questions covering the implementation surface
- **Round B** — 5 follow-up questions generated from Round A answers + 5 "definition of done" questions for validation

Every question has exactly 4 options. **One option is marked ★** — the
orchestrator's recommended answer based on discovery + tech-decisions + the
feature's place in the plan. The user can:

- Reply with letter codes per question (`1: a, 2: c, 3: ★, ...`)
- Type `accept` to take all ★ recommendations for the current feature
- Type `accept and continue` to take all ★ for ALL remaining features (skip the rest of clarification)
- Type `skip F<NNN>` to defer this feature and move to the next
- Type `stop` to pause clarification entirely (resumable with `/mission-tasks`)

## Round A — the 10 task questions

These categories apply to most features. Adapt wording per feature type. The
order matters: implementation choice first, then data, then errors, then
edges.

1. **Implementation pattern** — which approach within the chosen stack
   _Example: "How is this feature structured?"_
   _(a) single function in `lib/` / (b) service class with DI / (c) async handler + queue / (d) split across multiple modules_

2. **Data shape** — the canonical representation
   _Example: "How is the channel-membership relation represented?"_
   _(a) join table `channel_members` / (b) JSONB array on `channels` / (c) array on `users` / (d) derived from messages_

3. **State / storage location** — where state lives
   _Example: "Where does the unread-count counter live?"_
   _(a) computed on read / (b) materialized column + trigger / (c) Redis / (d) client-side only_

4. **API contract** — input/output shape (for any endpoint or function)
   _Example: "What does the send-message endpoint return on success?"_
   _(a) full message object / (b) 201 + Location header only / (c) message ID only / (d) WebSocket broadcast, HTTP returns 202_

5. **Failure / error handling** — the dominant failure mode
   _Example: "If the database write fails after the WebSocket broadcast, what happens?"_
   _(a) message marked failed in UI; retry button / (b) silent retry with backoff / (c) crash + alert / (d) roll back broadcast (impossible — note this for user)_

6. **Empty / zero state** — what's shown or returned when no data exists
   _Example: "What does the channel list show for a brand-new user?"_
   _(a) skeleton + "Join channels to get started" / (b) auto-join #general / (c) empty list / (d) onboarding wizard_

7. **Validation rules** — what counts as valid input
   _Example: "What's the message body validation?"_
   _(a) 1-4000 chars, any unicode / (b) 1-2000 chars, strip HTML / (c) 1-10000 chars, sanitize markdown / (d) no length limit, trust client_

8. **Performance budget** — the response/latency target
   _Example: "Target p95 for send-message?"_
   _(a) <50ms / (b) <200ms / (c) <500ms / (d) not a constraint at this stage_

9. **Auth / access control** — who can perform this
   _Example: "Who can send a message to a channel?"_
   _(a) any authenticated user with channel membership / (b) any authenticated user (channel membership checked separately) / (c) only channel members + admins / (d) role-based (writer/reader/admin)_

10. **Dependencies on existing code** — what this feature touches
    _Example: "Which existing modules does this read or modify?"_
    _(a) only this feature's new files / (b) reads from auth module / (c) reads from auth + extends message schema / (d) requires changes to migrations module too_

### Adapting Round A per feature type

- **Pure data/migration features** → drop Q4, Q9; add: "rollback strategy", "data-loss tolerance"
- **Pure UI features** → adapt Q4 to "rendered states", add: "loading state design", "responsive breakpoints"
- **Background/job features** → drop Q4; add: "schedule (cron / event-driven / queue-triggered)", "max execution time"
- **Library/utility features** → drop Q9; add: "public API surface", "test surface (unit only / property-based / fuzz)"

## Round B — generating the 5 follow-ups

After Round A answers, identify ambiguities, contradictions, or implications
that need a decision. Examples:

- Q1 = "service class with DI" + Q3 = "Redis" → ask "Is the Redis client injected or imported?"
- Q5 = "retry with backoff" → ask "Max retries? Backoff curve? Dead-letter destination?"
- Q9 = "role-based" + project has no roles defined yet → ask "Which roles? Define them now."
- Q7 picks "sanitize markdown" → ask which sanitizer (DOMPurify / rehype-sanitize / custom)
- Q2 + Q3 combination implies a denormalization → ask about consistency guarantees

Compose exactly 5 follow-ups, each with 4 options and one ★. If you can
think of more than 5, pick the 5 with highest impact on the implementation.

## Round B — the 5 "definition of done" questions

These are the validation surface. Their answers become assertion IDs the
validator checks. Standardized — keep these five for every feature unless
the feature type genuinely doesn't apply:

11. **Primary success test** — what test proves the happy path
    _(a) unit test on the core function / (b) integration test (DB + HTTP) / (c) end-to-end (Playwright) / (d) all three_

12. **Failure test** — what test proves error handling
    _(a) unit test on each error branch / (b) integration test forcing failure / (c) chaos test (random failures injected) / (d) error paths are tested manually_

13. **Manual verification** — what a human checks before sign-off
    _(a) follow a 3-step script in feature spec / (b) demo to user / (c) check produced log lines / (d) none — automated suffices_

14. **Side-effect verification** — what should NOT happen
    _(a) test verifies no other table is mutated / (b) test verifies no other endpoint changes behaviour / (c) snapshot test of affected data / (d) not applicable_

15. **Evidence artifact** — what proves done in the milestone report
    _(a) test output + coverage report / (b) screenshot or video / (c) log lines from a real run / (d) all of the above_

Combined with Round A's answers, these five answers go directly into the
`Acceptance criteria for this feature` section of the enriched feature spec
and into the validators' checklist for the milestone.

## Pre-filling the ★ recommended option

The orchestrator picks the recommended option using this priority order:

1. **Explicit user answer from discovery** — if discovery already answered this question, mark that as ★.
2. **Project-wide convention from tech-decisions.md** — e.g. tech-decisions says "Vitest with 90% coverage on core paths" → Q11 ★ becomes "all three" or "integration test".
3. **The feature's milestone context** — Foundation milestone features get conservative recommendations (single function, computed on read). Polish milestone features get rigorous ones (e2e tests, all three).
4. **Sensible default for the project type** — if no signal exists, pick the option that minimizes coupling, maximizes testability, and is reversible.

If no option is clearly best, mark **none** with ★ and write `(no recommendation — please choose)` after the question.

## Output: clarification.md

Path: `missions/<id>/clarifications/F<NNN>-clarification.md`

```markdown
# F<NNN> Clarification

_Generated: <UTC>_  _Mode: full | accept-defaults | partial-accept_

## Round A — 10 task questions

**1. Implementation pattern**
- (a) single function in lib/
- (b) service class with DI                  ★ recommended (matches tech-decisions "service-layer pattern")
- (c) async handler + queue                     ← chosen
- (d) split across multiple modules

... (questions 2-10)

## Round B — 5 follow-ups

**11. Redis client — injected or imported?**
- (a) injected via constructor                ★ recommended  ← chosen
- (b) imported from singleton module
- (c) created per-request
- (d) connection pool, shared

... (questions 12-15)

## Round B — 5 "definition of done" questions

**16. Primary success test**
- (a) unit test
- (b) integration test                        ★ recommended  ← chosen
- (c) end-to-end (Playwright)
- (d) all three

... (questions 17-20)
```

## Output: enriched feature spec

After clarification, the feature spec at `features/F<NNN>-*.md` is rewritten
(not replaced — extended) with these new sections appended:

```markdown
<original feature spec content unchanged>

---

## Clarified implementation (from clarifications/F<NNN>-clarification.md)

- Pattern: <answer to Q1>
- Data shape: <answer to Q2>
- State location: <answer to Q3>
- API contract: <answer to Q4>
- Failure handling: <answer to Q5>
- Empty state: <answer to Q6>
- Validation: <answer to Q7>
- Performance budget: <answer to Q8>
- Access control: <answer to Q9>
- Touches: <answer to Q10>

### Follow-up decisions
- <Q11 answer>
- <Q12 answer>
- <Q13 answer>
- <Q14 answer>
- <Q15 answer>

## Definition of done

- **Primary success test:** <Q16 answer> — derived test cases:
  - <one bullet per assertion ID covered>
- **Failure test:** <Q17 answer>
- **Manual verification:** <Q18 answer>
- **Side-effect verification:** <Q19 answer>
- **Evidence artifact:** <Q20 answer>

These five answers are what the milestone validators check. A worker is not
done until each definition-of-done answer is satisfied with concrete output
linked from the handoff.
```

## Follow-up features generated by validators

When a milestone validator rejects something and the orchestrator appends a
follow-up feature, that follow-up does NOT need a full 20-question
clarification. It inherits the parent feature's clarification verbatim, plus
a short addendum derived from the validator report:

```markdown
## Clarified implementation
<inherited from parent F<NNN>>

## Follow-up scope (from M<N>-scrutiny.md)
<validator's recommended fix as a one-paragraph spec>

## Definition of done
<inherited, plus: "the previously failing test now passes">
```

## Hard rules

- Always emit Round A first, wait for answers, then emit Round B (follow-ups + done questions together).
- Never skip the ★ marking — even on questions where the user might pick anything, picking the most-defensible option as ★ lets them `accept` and move on.
- Never write a clarification.md without all 20 answers (or explicit `accept` indicating ★ defaults across the board).
- The five "definition of done" answers are mandatory inputs for both validators. They go into the milestone report checklist.
- If the user types `accept and continue`, take ★ defaults for the current feature and silently mark every remaining feature in the plan as `[CLARIFIED-AUTO]` with ★ defaults. Note this mode at the top of each auto-generated clarification.md so reviewers can spot it.
