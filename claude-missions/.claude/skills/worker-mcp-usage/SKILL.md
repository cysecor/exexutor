---
name: worker-mcp-usage
description: When and how workers use MCP tools during /mission-run. Prefer MCP for live service introspection (Supabase schema, GitHub, etc.) when connections/mcp-registry.md lists the service. Activate in worker subagents during execution.
---

# Worker MCP usage

Workers implement features in `/mission-run`. External services were registered
during `/mission-connect`. The orchestrator never asks the user questions
during run — resolve ambiguity from clarified specs and this skill.

## Required reading before touching external services

1. `missions/<id>/connections/mcp-registry.md` — which MCP servers exist and tool prefixes
2. `missions/<id>/tech-decisions.md` — SDK names, env var names, conventions
3. Your feature spec "Clarified implementation" and "Touches"

## When to use MCP vs application code

| Situation | Use MCP | Use SDK/code in repo |
|-----------|---------|----------------------|
| Inspect live schema, tables, columns, RLS policies | Yes (e.g. Supabase MCP) | No for one-off checks |
| Apply or verify migrations against real project | Yes when MCP supports it | Migrations files in repo + tests |
| Query seed/fixture data to validate a feature | Yes | — |
| Implement product API routes, components, business logic | No | Yes |
| Unit/integration tests in the test runner | No | Yes |
| Stripe/Resend/etc. with no MCP in registry | No | SDK + env from `.env` |

**Rule:** If `mcp-registry.md` lists the service with `Worker use: yes`, and your
feature touches that service's live state, call the MCP tools **before or after**
code changes to verify schema, policies, or remote configuration. Record which
tools you used in the handoff `Commands run` / `Decisions made` sections.

## Decision tree by feature type

- **Database / migration feature** → MCP for schema introspection and policy checks; commit migration files in repo; re-check via MCP after apply
- **Auth feature using Supabase** → MCP to verify auth settings/users tables if needed; implement with project SDK patterns from tech-decisions
- **Pure UI feature** → No MCP unless spec requires live CMS/data fetch via MCP-backed service
- **GitHub/Linear/Notion feature** → Use listed MCP for issues/PRs/pages when registry says so
- **API-only external service (no MCP row)** → SDK + tests only; never ask the user mid-run

## Tool prefix discovery

Registry rows include `Tool prefix` (e.g. `mcp__supabase__*`). Use tools matching
that prefix. If a tool call fails with "not found", set handoff Status to
`BLOCKED` or `PARTIAL` with:

```
BLOCKER: MCP tool unavailable for <service>
TRIED: <tool names attempted>
NEEDED: Orchestrator should re-run /mission-connect or verify claude mcp list
SUGGESTED FOLLOWUP: <one paragraph to register/fix MCP for this service>
```

Do not ask the user questions. The orchestrator handles recovery without stopping the run.

## Security

- Credentials load from `.env` via the project's standard mechanism — never log values
- Never paste credential values into handoffs, commits, or MCP arguments visible in logs
- MCP responses may contain sensitive data — reference table/column names only in handoffs

## Ambiguity without user input

Priority order when the spec is unclear:

1. Clarified implementation answers in the feature spec
2. ★ chosen answers in `clarifications/F<NNN>-clarification.md`
3. `tech-decisions.md` conventions
4. Safest default that satisfies assertion text
5. If still blocked → `BLOCKED` with `SUGGESTED FOLLOWUP` (orchestrator creates follow-up feature)

Optional in handoff when you applied a default:

```
AUTONOMOUS_DECISION: <what you chose and why>
```

## Evidence for validators

Validators do not see your chat. Link MCP verification in handoff:

- Under `Decisions made`: e.g. "Verified `users` table and RLS via Supabase MCP list_tables"
- Under `Commands run`: note significant MCP tool invocations (tool name only, no secrets)
