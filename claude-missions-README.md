# Claude Missions

A reusable scaffold that turns Claude Code into a **multi-agent software
engineering system** capable of running long-horizon tasks autonomously.

Seven guided phases take a project from a one-line description to a working,
tested, validated codebase: scope → discover → plan → connect → tasks → run → done.

Inspired by Factory's "Missions" architecture, rebuilt entirely on Claude
Code primitives: subagents, skills, slash commands, and hooks.

## Two core principles

**The orchestrator does work; the user provides data.** Across every phase,
the orchestrator runs commands via its `Bash` tool — installations, MCP
registration, env file writing, verifier execution. You — the user — never
open a terminal. Your input is bounded to: a one-line description, answers
to multiple-choice questions, credentials pasted in chat when asked, and
approving the plan.

**Versions and setup come from web search, not memory.** Before writing any
framework version, package name, CLI command, or auth scheme, the
orchestrator web-searches to confirm current state. This is what catches
things like Supabase migrating from legacy anon/service_role JWT keys to
new publishable/secret keys, or libraries getting deprecated and replaced.
Every verified choice carries an inline source-URL annotation.

## The user journey

```
1. /mission-scope "<your one-line app description>"
       └─→ description.md captured (no questions yet)

2. /mission-discover
       ├─→ Round 1: 30 multiple-choice questions (4 options each)
       │   across Users, Data, Interface, Integrations, Deploy, Quality
       └─→ Round 2: 15 follow-ups generated from your round-1 answers

3. /mission-plan
       ├─→ Web-searches current versions and MCP availability per service
       ├─→ validation-contract.md  (60–200 falsifiable assertions)
       ├─→ plan.md                  (30–250 DRAFT features in milestones)
       └─→ tech-decisions.md        (stack with verified-version annotations)
   You review, type `approved` → APPROVED file written, contract locked.

4. /mission-connect
       ├─→ Web-searches current auth methods + MCP availability per service
       ├─→ Builds a manifest with one row per service:
       │     "What I'll set up" (commands the orchestrator will run)
       │     "What I need from you" (data items only — never actions)
       │
       For each service:
       ├─→ Orchestrator tells you what data it needs + where to find it
       ├─→ You paste credentials in chat (one-time, gitignored .env)
       ├─→ Orchestrator runs the installs and `claude mcp add` commands itself
       ├─→ Orchestrator runs the verifier
       └─→ On failure: re-asks for the data; never tells you to "try running" anything

5. /mission-tasks
       For each feature in the plan:
       ├─→ Round A: 10 task questions (implementation, data, errors, edge cases…)
       │   Each question has 4 options; one is ★ recommended based on context.
       └─→ Round B: 5 follow-ups (informed by Round A) + 5 "definition of done"
       │
       Shortcuts: `accept` (★ defaults for this feature), `accept and continue`
       (★ defaults for ALL remaining), `skip F<NNN>`, `stop` (pause/resume).

6. /mission-run
       Loop until every assertion GREEN:
       ├─→ Pick next CLARIFIED feature in dependency order
       ├─→ Spawn worker subagent (fresh context)
       │   Worker reads enriched spec + clarified implementation + done criteria
       ├─→ Worker implements, commits, writes handoff
       ├─→ Pre-exit hook blocks on dirty git, failing tests, missing handoff
       ├─→ At milestone boundary:
       │     spawn scrutiny-validator (adversarial, fans out reviewers)
       │     spawn ux-validator (boots app, runs Playwright)
       └─→ Any FAIL → orchestrator creates follow-up features

7. /mission-status  (anytime)
       Read-only report of all phases including version-freshness searches.
```

## What you actually do across an entire mission

- Type the initial `/mission-scope` description
- Answer 30 + 15 multiple-choice questions in discovery
- Type `approved` after reviewing the plan
- Visit provider websites to sign up and generate credentials (browser-only)
- Paste credentials in chat when asked
- Answer 20 clarification questions per feature (or batch-accept)
- Optionally check `/mission-status`
- Walk away while it runs

## What you do NOT do

- Open a terminal
- Run `npm install`, `pip install`, `claude mcp add`, or any command
- Edit `.env` by hand (orchestrator writes it from values you paste)
- Edit Claude Code settings (orchestrator uses `claude mcp add`)
- Run verifier scripts (orchestrator runs them; reports results)

## Install

```bash
# In an empty directory where you want the project to live
git clone <this-repo> .
git init   # if not already
```

Open `claude` in the directory. The seven slash commands appear
automatically because they live in `.claude/commands/`.

## The seven commands

```
/mission-scope "<one-line description>"   # capture (Phase 1)
/mission-discover                          # 30 + 15 questions (Phase 2)
/mission-plan                              # contract, draft plan, tech (Phase 3)
/mission-connect                           # orchestrator sets up services (Phase 4)
/mission-tasks                             # per-feature 10+5+5 clarification (Phase 5)
/mission-run                               # execute until done (Phase 6)
/mission-status                            # read-only report (anytime)
```

## File layout

```
.
├── CLAUDE.md                                # repo-wide rules every agent inherits
├── README.md                                # this file
├── DOCS.md                                  # human documentation
├── .gitignore
├── .env.example                             # generated by /mission-connect
├── .claude/
│   ├── settings.json
│   ├── agents/
│   │   ├── worker.md
│   │   ├── scrutiny-validator.md
│   │   └── ux-validator.md
│   ├── skills/
│   │   ├── mission-planning/SKILL.md        # decompose into many small features
│   │   ├── discovery-questions/SKILL.md     # 30 + 15 question rules
│   │   ├── task-clarification/SKILL.md      # 10 + 5 + 5 per-feature Q&A
│   │   ├── validation-contracts/SKILL.md    # assertion format
│   │   ├── connection-setup/SKILL.md        # orchestrator-does-setup flow
│   │   ├── version-freshness/SKILL.md       # web-search current versions
│   │   ├── structured-handoffs/SKILL.md     # mandatory handoff template
│   │   └── model-selection/SKILL.md         # droid whispering
│   ├── commands/
│   │   ├── mission-scope.md
│   │   ├── mission-discover.md
│   │   ├── mission-plan.md
│   │   ├── mission-connect.md
│   │   ├── mission-tasks.md
│   │   ├── mission-run.md
│   │   └── mission-status.md
│   └── hooks/
│       └── pre-worker-exit.sh
└── missions/
    └── README.md
```

## Customization seams

For your team or domain, fork these:

1. **`.claude/skills/discovery-questions/SKILL.md`** — add domain-specific categories to the 30 defaults.
2. **`.claude/skills/task-clarification/SKILL.md`** — tune the 10 task + 5 done questions to your stack.
3. **`.claude/skills/connection-setup/SKILL.md`** — extend the service catalogue with your internal services.
4. **`.claude/skills/version-freshness/SKILL.md`** — add known-deprecated patterns specific to your stack.
5. **`.claude/skills/mission-planning/SKILL.md`** — your stack opinions.
6. **`.claude/skills/structured-handoffs/SKILL.md`** — add workflow-specific sections.
7. **The `model:` field in each agent file** — see `model-selection/SKILL.md`.
8. **`.claude/hooks/pre-worker-exit.sh`** — add your own checks.
9. **`CLAUDE.md`** — append house rules every agent inherits.

What you should NOT edit:

- The serial execution rule in `mission-run.md`.
- The "orchestrator never edits code" rule in `CLAUDE.md`.
- The contract immutability rule in `validation-contracts/SKILL.md`.
- The credential security rules in `connection-setup/SKILL.md`.
- The version-search requirement in `version-freshness/SKILL.md`.

## Design principle

Almost all orchestration logic lives in **prompts and skills**, not in
deterministic code. The hook is ~200 lines of bash; everything else is
markdown. Future model releases improve the system automatically; the
hooks remain stable. Four sentences in a skill file can dramatically
alter execution strategy.

## Known caveats

- **Hooks API:** Claude Code's hooks schema has evolved. Verify the `SubagentStop` matcher format in `.claude/settings.json` against current docs.
- **Playwright MCP** is required for the UX validator. The orchestrator installs it during `/mission-connect`.
- **Model strings** in agent files (`claude-opus-4-7`, `claude-sonnet-4-6`) age — update as new releases ship.
- **Hook re-runs your test command** on every COMPLETE handoff. For huge test suites, split into fast/full.
- **Discovery answers** aren't re-asked on edit — re-run `/mission-plan` if you edit them.
- **Re-clarification** mid-run: delete both clarification and the appended spec sections, then re-run `/mission-tasks`.
