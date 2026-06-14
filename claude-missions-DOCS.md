# Claude Missions

A multi-agent software engineering system that turns Claude Code into an autonomous team capable of running long-horizon coding projects. Take a project from a one-line idea to a tested, validated codebase through seven guided phases, with the AI doing the implementation AND the setup work while a human supervises at the decision points that matter.

---

## TL;DR

Software engineers using AI today can only drive a few tasks forward at a time because every change needs human attention. Claude Missions changes the ratio: you spend effort answering questions, approving decisions, and pasting credentials when asked, but a team of Claude subagents — orchestrated by a main session — does all the implementation, all the setup commands, and all the verification. You never open a terminal during a mission.

The whole thing is one directory of markdown files. No daemon, no database, no SaaS. Drop it into a project, open `claude`, and the seven slash commands appear automatically.

---

## Contents

1. [Why this exists](#why-this-exists)
2. [Two governing principles](#two-governing-principles)
3. [The mental model](#the-mental-model)
4. [The seven phases](#the-seven-phases)
5. [The four roles](#the-four-roles)
6. [How it's built](#how-its-built)
7. [File structure](#file-structure)
8. [Installation and first mission](#installation-and-first-mission)
9. [Customization](#customization)
10. [Design decisions and rationale](#design-decisions-and-rationale)
11. [Troubleshooting](#troubleshooting)
12. [Limitations and caveats](#limitations-and-caveats)
13. [Where it goes next](#where-it-goes-next)

---

## Why this exists

Modern code-generation models are smart enough to implement most features. The bottleneck isn't intelligence — it's human attention. Even strong engineers can drive only a few tasks forward at a time because each one requires their review, their decisions, their context switches. A team of five engineers might have a backlog of fifty features but can only push a handful per day. Today's models could figure out all fifty; there just isn't enough supervisory bandwidth to direct the implementation.

Claude Missions is built around a single trade: you do more decision-making upfront so the system can execute autonomously afterwards. You don't write the code — and you don't run any of the setup commands either. The orchestrator does all the package installs, MCP registrations, env file writes, and verifier executions. You answer questions, paste credentials when asked, approve the plan, and clarify each feature. Then you walk away.

The architecture is borrowed in spirit from Factory's "Missions" system (Luke's talk on multi-agent software engineering for the Anthropic developer community), rebuilt entirely on Claude Code's native primitives: subagents, skills, slash commands, and hooks. The central insight from that talk is that orchestration logic should live in prompts and skills, not in deterministic code. That way the system improves with each model release without requiring a refactor, and four sentences in the right place can dramatically alter execution strategy.

What this system is intentionally **not**:

- **Not a no-code platform.** You read and edit the generated code if you want to. The output is a normal git repository.
- **Not parallel.** Workers run serially by design. Parallel writes break long missions; the error rate from coordination overhead eats the speed gains.
- **Not a SaaS.** Everything is files in your repo.
- **Not magic.** The validation contract is the whole game. Get it right and execution is mostly automatic. Get it wrong and no model upgrade rescues you.

---

## Two governing principles

These two principles override every default behaviour in the system. They're referenced throughout the codebase as **P-1** and **P-2**.

### P-1. The orchestrator does work; the user provides only data

Across every phase, the orchestrator runs all commands via its `Bash` tool. The user's contribution is bounded to information that cannot be obtained without them: credentials, choices between options, free-form descriptions of intent. The user never opens a terminal during a mission.

Concretely, the orchestrator runs (so you don't have to):

- `npm install`, `pip install`, `pnpm add`, `cargo add`, etc.
- `claude mcp add <server>` to register MCP servers
- `claude mcp list` to verify
- Writes to `.env` (after you paste the values in chat once)
- Verifier scripts in `connections/verify/`
- Setup commands like `npx create-next-app`, `supabase init`, etc.

What you still do (because the orchestrator can't):

- Sign up for provider accounts in your browser
- Generate credentials in provider dashboards
- Configure OAuth callbacks in provider dashboards (when applicable)
- Paste the resulting credentials in chat when the orchestrator asks

This is a meaningful departure from how most AI coding workflows operate. Most ask you to follow a tutorial: "Step 1, run `npm install`. Step 2, run `claude mcp add`. Step 3, copy your key to `.env`." Claude Missions doesn't do that. The orchestrator does the work and asks only for the credential value.

### P-2. Versions and setup patterns come from search, not memory

The orchestrator's training data is months or years out of date. Every framework version has moved. Libraries have been deprecated and replaced. Authentication schemes have changed (Supabase moved from legacy `anon`/`service_role` JWT keys to new publishable/secret keys with `sb_publishable_` / `sb_secret_` prefixes; OpenAI introduced project-scoped `sk-proj-` keys; Stripe added restricted `rk_` keys; etc.). New MCP servers have appeared for services that didn't have them at training cutoff.

Before writing any version number, package name, CLI command, or auth scheme in `tech-decisions.md` or `connections/manifest.md`, the orchestrator web-searches to confirm the current state. Each verified choice carries an inline annotation pointing to the source URL and verification date:

```markdown
- Supabase JS client v2.x with publishable/secret keys
  <!-- verified against https://supabase.com/docs/guides/api/api-keys as of 2026-MM-DD -->
```

This makes the search auditable. If a worker later finds the doc has moved, they can re-verify.

The `version-freshness` skill in `.claude/skills/version-freshness/SKILL.md` codifies the rules: what to search for, when, and what to do with conflicting results.

---

## The mental model

Four ideas you need to hold in your head. Everything else in the system follows from these.

**State lives in files.** Every phase writes to `missions/<id>/`. The orchestrator, workers, validators, and you all read the same files. A mission resumes from disk after a crash; nothing important lives in memory. This is also what lets you inspect, edit, or rewind any step.

**The orchestrator does not write code.** The main Claude Code session is the project manager. It scopes, plans, delegates, reads results. The moment it writes implementation code, you've lost the fresh-context guarantee that makes long missions possible. The orchestrator's only file edits happen inside `missions/<id>/`, `.env`, `.env.example`, and `.gitignore`. Everything else is a worker's job.

**Workers start fresh.** Every feature gets a new worker subagent with no prior conversation history. It reads its feature spec from disk, implements one thing, commits, writes a handoff, exits. The next worker inherits a clean git state and a working codebase.

**Validators are adversarial.** Two validators run at every milestone boundary — one reads code with read-only tools, one drives the running app. Neither saw the implementer's reasoning. Both check the validation contract directly, not the worker's claims. Their bias is rejection.

---

## The seven phases

Each phase produces specific files. The next phase refuses to run if its inputs are missing — the system is rigorously gated.

### Phase 1 — Scope (`/mission-scope "<one-line description>"`)

The user describes the app in their own words. The orchestrator records it verbatim in `description.md`. No interpretation, no questions, no rephrasing. This is the only place the user's exact words are stored unchanged.

### Phase 2 — Discover (`/mission-discover`)

Two rounds of multiple-choice questions.

**Round 1** is 30 broad questions across six categories — Users & Access, Data, Interface, Integrations, Deploy & Ops, Quality & Constraints. The orchestrator emits all 30 in one structured message. The user replies with letter codes.

**Round 2** is 15 follow-up questions generated dynamically from Round 1's answers. They close gaps the first round exposed.

### Phase 3 — Plan (`/mission-plan`)

The orchestrator web-searches current versions, package names, and MCP availability for everything implied by the discovery answers (per P-2). It then produces three artefacts in this exact order:

1. **Validation contract** — flat numbered list of falsifiable `AS-NNN` assertions. Medium project: 60–200 assertions.
2. **Plan** — features grouped into milestones in dependency order. Target 30–100 features for medium projects. The first milestone is always Foundation.
3. **Tech decisions** — stack, libraries, file layout, exact run/test commands. Every version has an inline `<!-- verified against <URL> as of <date> -->` annotation.

The user reviews, types `approved`. The contract becomes immutable.

### Phase 4 — Connect (`/mission-connect`)

This is the phase that changed most under P-1.

The orchestrator reads the tech-decisions external-services list. For each service, it web-searches:

- Does an official MCP server exist? (P-2: search every time; the MCP ecosystem grows fast.)
- What's the current authentication format? (Catches Supabase legacy keys, OpenAI project keys, etc.)
- What's the current SDK package name and version?

It writes a `connections/manifest.md` with one row per service. Each row has a "What I'll set up" column listing the commands the orchestrator will run, and a "What I need from you" column listing only data items — never actions.

Then, per service, in order:

1. The orchestrator sends one chat message: "Setting up <Service>. I'll [list of commands]. What I need from you: [credential/URL/choice] — find it at [one-paragraph pointer to provider dashboard]."
2. The user pastes the credential in chat.
3. The orchestrator runs every install, registers the MCP via `claude mcp add`, writes `.env` directly from the pasted values (without echoing them back), and runs the verifier.
4. On failure, the orchestrator reports the safe error and asks the user to re-check the data they pasted. It never tells the user to "run" anything.

When every service passes, the verifier scripts are deleted and `VERIFIED` is written.

What you do in this phase, total: paste credentials when asked. That's it.

### Phase 5 — Tasks (`/mission-tasks`)

Per-feature interrogation. For each feature in the plan, the orchestrator runs two rounds:

**Round A** is 10 task questions covering implementation pattern, data shape, state location, API contract, failure handling, empty state, validation rules, performance budget, access control, and code dependencies.

**Round B** is 5 dynamic follow-ups generated from Round A's specific answers, plus 5 fixed "definition of done" questions covering primary success test, failure test, manual verification, side-effect verification, and evidence artifact.

Every question has four options with **one marked ★ recommended** based on context. The user can:

- Reply with specific letter codes per question
- Type `accept` to take all ★ defaults for the current feature
- Type `accept and continue` to take ★ defaults for all remaining features
- Type `skip F<NNN>` to defer a feature
- Type `stop` to pause

Each clarified feature produces a `clarifications/F<NNN>-clarification.md` and gets its draft spec appended (never replaced) with "Clarified implementation" and "Definition of done" sections.

### Phase 6 — Run (`/mission-run`)

The orchestrator loops:

For each clarified feature in dependency order, spawn a worker subagent with a fresh context window. The worker reads the enriched feature spec, implements, commits with `feat(F<NNN>): <summary> [assertions: AS-NN, ...]`, and writes an 8-section handoff. A `SubagentStop` hook re-runs the test command, checks git is clean, validates the handoff, and either allows exit or forces the worker to continue.

At each milestone boundary, two validators run sequentially:

- **Scrutiny validator** — read-only, adversarial, fans out per-feature reviewers in parallel.
- **UX validator** — boots the application and drives real user flows via Playwright.

Any failed assertion becomes a follow-up feature inheriting the parent's clarification.

### Phase 7 — Status (`/mission-status`)

Read-only and safe at any time. Reports phase completion, assertion counts, milestone status, version-freshness searches conducted, the last handoff summary, open blockers, and next planned action.

---

## The four roles

| Role | Default model | Capability | Tools |
|---|---|---|---|
| Orchestrator (main session) | `claude-opus-4-7` | Slow careful reasoning, scoping, judgement, setup execution | All file tools, Bash, WebSearch, WebFetch, slash commands, Agent |
| Worker | `claude-sonnet-4-6` | Fast code fluency in a fresh context | Read, Write, Edit, Bash, Grep, Glob |
| Scrutiny validator | `claude-opus-4-7` | Precise instruction-following, adversarial bias | Read, Bash, Grep, Glob, Agent (fan-out) |
| UX validator | `claude-opus-4-7` | Patient tool-use, designing real user flows | Read, Bash, Playwright MCP |

The orchestrator now has `WebSearch` and `WebFetch` in its toolset specifically to support P-2. The single highest-leverage configuration change is putting a different model **family** on the scrutiny validator via a proxy (LiteLLM, OpenRouter) — shared training-data bias is real.

---

## How it's built

The system is built entirely on Claude Code's native primitives.

**Subagents** (`.claude/agents/<name>.md`) are isolated workers spawned via the Agent tool. Fresh context window each time. The parent passes a prompt string; the subagent's final message returns verbatim.

**Skills** (`.claude/skills/<name>/SKILL.md`) are progressive-disclosure prompts loaded into context on demand. The orchestrator loads `version-freshness` and `mission-planning` when planning, `validation-contracts` when writing the contract, `connection-setup` and `version-freshness` when setting up services, `task-clarification` during the tasks phase.

**Slash commands** (`.claude/commands/<name>.md`) shape the main session into a phase-specific orchestrator.

**Hooks** (`.claude/hooks/<name>.sh`) intercept lifecycle events. The starter ships one hook — `pre-worker-exit.sh` — registered for `SubagentStop` events filtered to the worker subagent.

The deliberate split: **everything that benefits from model intelligence is in prompts (skills, agents, commands); everything that needs to be unfailable is in hooks (bash).** The hook is ~200 lines; the entire rest of the system is markdown.

---

## File structure

```
.
├── CLAUDE.md                                # repo-wide rules every agent inherits
├── README.md                                # quickstart
├── DOCS.md                                  # this file
├── .gitignore
├── .env.example                             # generated by /mission-connect
│
├── .claude/
│   ├── settings.json
│   ├── agents/
│   │   ├── worker.md
│   │   ├── scrutiny-validator.md
│   │   └── ux-validator.md
│   ├── skills/
│   │   ├── mission-planning/SKILL.md
│   │   ├── discovery-questions/SKILL.md
│   │   ├── task-clarification/SKILL.md
│   │   ├── validation-contracts/SKILL.md
│   │   ├── connection-setup/SKILL.md
│   │   ├── version-freshness/SKILL.md       # NEW — P-2 enforcement
│   │   ├── structured-handoffs/SKILL.md
│   │   └── model-selection/SKILL.md
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
│
└── missions/
    ├── CURRENT
    └── <mission-id>/
        ├── description.md                   # phase 1
        ├── discovery/round-{1,2}.md         # phase 2
        ├── validation-contract.md           # phase 3
        ├── plan.md
        ├── tech-decisions.md
        ├── APPROVED
        ├── features/F<NNN>-*.md             # draft + clarified
        ├── connections/manifest.md          # phase 4
        ├── connections/verify/*.sh          # deleted on full pass
        ├── connections/VERIFIED
        ├── clarifications/F<NNN>-*.md       # phase 5
        ├── handoffs/F<NNN>-handoff.md       # phase 6
        └── milestones/M<N>-{scrutiny,ux}.md
```

Note: prior versions wrote `connections/tutorials/*.md` files. Under P-1 these are no longer needed — the orchestrator does the setup itself, and the manifest's "What I need from you" column replaces tutorial content.

---

## Installation and first mission

```bash
git clone <this-repo> .
git init   # if not already
```

That's it. Open `claude` in the directory.

A first mission looks like this:

```
/mission-scope "I want to build a Slack clone with channels, DMs, and threads"

/mission-discover
# orchestrator emits 30 questions; you reply: "1: b, 2: c, 3: a, ..."
# orchestrator emits 15 follow-ups; you reply

/mission-plan
# orchestrator web-searches versions, writes contract + plan + tech-decisions
approved

/mission-connect
# orchestrator searches for current auth + MCP availability per service
# for each service: "I'll install X, register Y MCP, write Z to .env.
#                    What I need from you: <credential> — find at <pointer>."
# you paste credentials in chat (one-time)
# orchestrator runs everything itself

/mission-tasks
# for each feature, answer Round A (10) then Round B (10)
# or `accept` / `accept and continue` to take ★ recommendations

/mission-run
# orchestrator spawns workers serially; validates at milestone boundaries
# walk away

/mission-status   # anytime
```

The entire flow is resumable. Each phase checks state files and picks up where it left off.

---

## Customization

The intentional customization seams are the skills:

`discovery-questions/SKILL.md` — the 30 default questions. Add domain-specific categories.

`task-clarification/SKILL.md` — the 10 task questions and 5 done questions. Tune to your stack.

`connection-setup/SKILL.md` — the service catalogue. Add your internal services. This is the most valuable team-specific fork.

`version-freshness/SKILL.md` — add known-deprecated patterns specific to your stack (e.g. "we never use Lucia auth; current preference is better-auth").

`mission-planning/SKILL.md` — your stack opinions.

`structured-handoffs/SKILL.md` — add workflow-specific sections.

The `model:` field in each agent file. The single most impactful change is putting a different-family model on the scrutiny validator.

`.claude/hooks/pre-worker-exit.sh` — add your own checks.

`CLAUDE.md` — append house rules every agent inherits.

What you should **not** edit until you really know why:

- The serial execution rule in `mission-run.md`.
- The "orchestrator never edits code" rule in `CLAUDE.md`.
- The contract immutability rule.
- The credential security rules in `connection-setup/SKILL.md`.
- The version-search requirement in `version-freshness/SKILL.md`.
- P-1 and P-2 in `CLAUDE.md`.

---

## Design decisions and rationale

**Why P-1 (orchestrator does work)?** Most AI coding tools today ask the user to follow tutorials: run this, paste that, install the other. This breaks the "walk away while it runs" promise multiple times per mission. With Bash and WebSearch in the orchestrator's toolset, there's no technical reason for the user to ever leave chat. P-1 made the system actually deliver on autonomy.

**Why P-2 (search for versions)?** The Supabase legacy-keys bug was real. The orchestrator's training data had `anon` and `service_role` JWT keys as the current format; the actual current format is `sb_publishable_` and `sb_secret_`. Every framework version, library name, and auth scheme has potentially moved since training cutoff. P-2 forces the orchestrator to verify the world's current state instead of trusting memory.

**Why serial execution?** Parallel writes break long missions. Coordination overhead eats speed gains; agents step on each other's changes; inconsistent architectural decisions compound. Internal parallelism on read-only operations (research subagents, parallel reviewers in the scrutiny validator) is fine.

**Why is the contract immutable?** Once `APPROVED` exists, a worker or validator may be mid-task referencing assertion IDs. Renumbering or editing breaks them silently.

**Why 20 questions per feature?** Vague feature specs cause drift. The clarification turns the draft "build the dashboard" into a fully-specified task. The cost is 20 questions per feature; the ★ recommended option plus `accept` shortcuts keep it survivable.

**Why credentials in `.env` only?** Credentials in markdown end up in git history, screenshots, chat logs. Strictly `.env` (gitignored) with `.env.example` (committed, blank) is the only safe pattern.

**Why a hook instead of trusting workers?** Prompts are unreliable for invariants. "You must commit before exiting" is a hope; `if [ -n "$(git status --porcelain)" ]; then block; fi` is a guarantee.

**Why mostly markdown?** Every model release improves prompt-based systems automatically. Customization is dramatically easier: a team edits a skill file, not a state machine.

---

## Troubleshooting

**"Orchestrator used a legacy auth format (e.g. Supabase anon/service_role keys)."** P-2 violation. Either the orchestrator skipped the version-freshness search or the search returned stale results. Check `tech-decisions.md` — every version should have an inline source-URL comment. If a comment is missing, the search was skipped.

**"Orchestrator asked me to run a command."** P-1 violation. Tell it: "You run it." The orchestrator should never instruct the user to execute setup commands; that's its job via Bash.

**"Orchestrator didn't offer MCP for a service that has one."** Either the version-freshness search missed it or the connection-setup catalogue is stale. Tell the orchestrator: "Search for an official MCP for <service> and use it if available."

**"Validator keeps approving things that don't work."** Most common cause: shared training-data bias. Swap the scrutiny validator to a different model family.

**"Workers keep producing PARTIAL handoffs."** Features too big (split further) or clarification answers inconsistent (re-read clarification.md for contradictions).

**"Hook blocks worker exit incorrectly."** Read the hook's `reason` field. If genuinely wrong, edit `.claude/hooks/pre-worker-exit.sh`.

**"I want to re-clarify a feature mid-run."** Delete both `clarifications/F<NNN>-clarification.md` and the appended sections in `features/F<NNN>-*.md`, then run `/mission-tasks`.

**"I want to abandon a mission and start over."** Run `/mission-scope` again. The old mission directory stays on disk.

---

## Limitations and caveats

**Hooks API may drift.** Verify the `SubagentStop` matcher format against current Claude Code docs.

**Model strings will age.** Update agent files as new releases ship.

**Hook re-runs your full test command.** Split tests into fast/full for huge suites.

**MCP servers require user-side config when `claude mcp add` doesn't cover them.** In that case the orchestrator still does its part; the user does only the minimum browser/dashboard step.

**Clarification cost scales.** 80 features × 20 questions = 1,600 questions. The `accept-and-continue` escape is essential.

**Single working tree.** One mission per repo. Parallel missions = separate clones.

**No automatic rollback.** Use git. The system commits per feature so `git reset --hard <last-good-sha>` works.

**Account creation, browser-only OAuth setup, and payment configuration** still require user action. The orchestrator gives a two-or-three-sentence pointer, not a tutorial.

---

## Where it goes next

When the CLI gets uncomfortable, the natural migration is to port the orchestrator loop to the **Claude Agent SDK** (Python or TypeScript). All the same agent files, skills, and hook logic stay exactly as they are. The slash commands become SDK calls; you build a web view that reads the same `missions/<id>/` state directory.

The SDK port unlocks:

- A web dashboard rendering `missions/<id>/` state
- Multiple missions in parallel (separate worktrees)
- Background execution with notifications
- Multi-project orchestration

Until then, the slash commands plus `/mission-status` are mission control.

---

## Credit

The architecture is inspired by Factory's "Missions" system as presented by Luke (Factory) in his talk on multi-agent software engineering. The original uses different primitives; this is a re-creation on Claude Code's native subagent/skill system. The two governing principles (P-1 and P-2) are additions that emerged from real-world usage discovering specific failure modes — the orchestrator asking users to run terminal commands, and the orchestrator using stale version information from its training data.
