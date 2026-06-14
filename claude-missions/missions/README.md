# missions/ — runtime state for each mission

Each subdirectory here is one mission. The directory name is the mission ID
(timestamp-based by default, e.g. `20260527-201234`).

The file `missions/CURRENT` (created by `/mission-scope`) names the active
mission. Only one mission is active at a time.

## State files inside `missions/<id>/`

By phase:

### Phase 1 — Scope
- `description.md` — verbatim user description from `/mission-scope`

### Phase 2 — Discovery
- `discovery/round-1.md` — 30 answered multiple-choice questions
- `discovery/round-2.md` — 15 follow-ups answered

### Phase 3 — Plan
- `validation-contract.md` — flat numbered AS-NNN assertion list (immutable once APPROVED)
- `plan.md` — features and milestones, each referencing assertion IDs
- `tech-decisions.md` — stack, layout, run/test commands, external service list. Every version carries an inline `<!-- verified against <URL> as of <date> -->` annotation (per P-2).
- `APPROVED` — created on human approval, contains the git SHA at approval time
- `model-overrides.yaml` — optional per-role model overrides
- `features/F<NNN>-*.md` — draft feature specs (enriched later by /mission-tasks)

### Phase 4 — Connect
- `connections/manifest.md` — table of services, env var names, status, "What I'll set up" (orchestrator commands), and "What I need from you" (data items only)
- `connections/mcp-registry.md` — MCP server names, tool prefixes, and worker-use flags for `/mission-run` (written when connect completes)
- `connections/verify/<service>.sh` — temporary verifier scripts (DELETED on full PASS, gitignored anyway)
- `connections/VERIFIED` — created when every service passes; contains UTC timestamp

Note: prior versions of the scaffold wrote `connections/tutorials/<service>.md` files for the user to follow. Under P-1 these are no longer created — the orchestrator does the setup itself, and the manifest's "What I need from you" column replaces tutorial content.

### Phase 5 — Tasks (clarification)
- `clarifications/F<NNN>-clarification.md` — per-feature 20-question Q&A (10 task + 5 follow-ups + 5 definition-of-done)
- `clarifications/AUTO_ACCEPT` — marker (if user typed `accept and continue` at any point) — auto-generates remaining clarifications using ★ defaults
- The feature specs at `features/F<NNN>-*.md` are APPENDED with "Clarified implementation" and "Definition of done" sections during this phase

### Phase 6 — Run
- `handoffs/F<NNN>-handoff.md` — per-feature handoffs filled by workers
- `run-log.md` — orchestrator autonomous decisions during run (ZERO_QUESTIONS mode)
- `run-deferred.md` — features deferred after 5 failed attempts in the same chain
- `milestones/M<N>-scrutiny.md` — scrutiny validator reports
- `milestones/M<N>-ux.md` — UX validator reports

During `/mission-run` the orchestrator does not ask the user questions. Workers use MCP tools listed in `mcp-registry.md` for services like Supabase. Recommend `claude --dangerously-skip-permissions` during run to avoid tool-approval prompts.

## Inspecting state

- `/mission-status` is the canonical way to see progress across phases. It also reports which version-freshness searches the orchestrator conducted and which services were registered via MCP vs raw SDK.
- For deeper inspection, every file is plain markdown — open in any editor.
- `missions/<id>/plan.md` is the single best file for a fast scan: features carry tags `[CLARIFIED]`, `[CLARIFIED-AUTO]`, `[SKIPPED]`, and `[COMPLETE]` as they progress.

## Editing state by hand

You may edit any file except:

- `validation-contract.md` after `APPROVED` exists (contract is immutable; add new AS-NNN entries instead)
- Anything under `handoffs/` (workers write these; editing breaks the audit trail)
- Anything under `milestones/` (validators write these)

Safe to edit any time:

- `plan.md` to reorder features, add notes, or split features further (but don't remove a feature mid-run — mark it `[SKIPPED]` or `[DEFERRED]` instead)
- `tech-decisions.md` if you discover something the planner missed (re-run `/mission-connect` if you change the external services list)
- `model-overrides.yaml` to swap which model handles which role
- `clarifications/F<NNN>-clarification.md` — if you change your mind about a clarified answer, edit this file; the worker reads its enriched feature spec, so you'll also need to update the matching section in `features/F<NNN>-*.md`, or delete both files and re-run `/mission-tasks` for that feature only.

## Starting fresh

To abandon a mission and start a new one, run `/mission-scope` again. The
prior mission directory stays on disk; only `missions/CURRENT` is updated.
You can return to an old mission by editing `missions/CURRENT` manually.
