---
name: model-selection
description: Guidance for picking the right model per role ("droid whispering"). Activate when configuring agents, starting a new mission, or diagnosing why a role is misbehaving. Model strings age fast — verify current names via search per P-2 before relying on the defaults below.
---

# Model selection (droid whispering)

No single model is best at planning, implementing, and validating. Each
agent in `.claude/agents/` sets its own `model:` field. Change them per
project and per role.

## P-2 applies to model strings

Per the version-freshness skill, the model identifiers below age faster
than almost anything else in the system. Anthropic ships new models
frequently; deprecated model IDs may still resolve for a transition
window but get worse responses than the current generation.

**Before relying on the defaults below**, search to verify which model IDs
are current. Useful queries: `Anthropic latest models`, `claude opus current
version`, `claude sonnet current version`. Update the agent files'
`model:` field with the verified-current ID and annotate with a source URL
comment if you want auditability.

## Default mapping (as of scaffold creation; verify before use)

| Role | Capability needed | Default model |
|---|---|---|
| Orchestrator (main session) | Slow careful reasoning, conversational scoping, judgement at milestone boundaries, web-search execution | `claude-opus-4-7` |
| Worker | Fast code fluency, willingness to iterate, tight instruction-following inside a fresh context | `claude-sonnet-4-6` |
| Scrutiny validator | Precise instruction-following, adversarial bias, willingness to reject | `claude-opus-4-7` (ideally a different model family entirely if you have access — see below) |
| UX validator | Patience with flaky UI, reliable tool-use, ability to design real user flows | `claude-opus-4-7` |

Search-verify these strings before assuming they're still current. If a
search reveals a newer generation, update the agent files.

## When to deviate

- **Throwaway prototype mission, cost matters more than iterations** — Sonnet or Haiku everywhere. Expect more validator-driven follow-ups.
- **Production-critical mission (migration, refactor, anything customer-visible)** — Opus everywhere. The serial bottleneck dominates wall-clock time; model cost is rounding error compared to a human review.
- **Scrutiny validator suspiciously lenient** — if you have access to a non-Anthropic frontier model via a proxy, put it here. Shared training data means an Anthropic model reviewing Anthropic-written code is more likely to share the same blind spots. This is the single highest-leverage swap.
- **Worker keeps producing vague handoffs** — first tighten the `structured-handoffs` skill template, then upgrade the worker model. Not the other way around.
- **Orchestrator keeps drifting from the plan** — upgrade the orchestrator model. Planning is the role most sensitive to model quality.

## Per-mission overrides

Drop `missions/<id>/model-overrides.yaml`:

```yaml
worker: claude-sonnet-4-6
scrutiny-validator: claude-opus-4-7
ux-validator: claude-opus-4-7
```

The orchestrator reads this file (if present) before spawning each subagent and
passes the model via the Agent tool call, overriding the agent file's default.

## Watching for failure modes

After every milestone, glance at:

- Average worker iterations before COMPLETE — rising means worker model is below the task's difficulty
- Scrutiny rejection rate — falling toward zero across milestones is suspicious (could mean coverage is dropping, not quality rising)
- UX validator INCONCLUSIVE rate — rising means the app is getting harder to drive, often a sign of accidental coupling

If any of these trend wrong over 2 milestones, change models before they
compound across a multi-day run.

## When model IDs in agent files are out of date

If you spin up a mission and a worker subagent fails to spawn with "unknown
model" or returns degraded responses, the model ID is likely deprecated.
Web-search for the current name (per P-2), update the relevant `.claude/agents/<role>.md`
file's `model:` field, and re-run the failed phase command.
