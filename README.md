# Exexutor — Claude Missions

> A reusable scaffold that turns **Claude Code** into a **multi-agent software
> engineering system** capable of taking a project from a one-line idea to a
> tested, validated codebase — autonomously.

Seven guided phases move a project from a single sentence to working software:
**scope → discover → plan → connect → tasks → run → done.** A team of Claude
subagents, orchestrated by a single main session, does all the implementation,
all the setup commands, and all the verification. **You never open a terminal
during a mission.**

The entire system is one directory of Markdown files plus a single ~200-line
bash hook. No daemon, no database, no SaaS. Drop it into a project, open
`claude`, and seven slash commands appear automatically.

---

## Table of contents

1. [Why this exists](#why-this-exists)
2. [What makes it different](#what-makes-it-different)
3. [Inspiration & credit](#inspiration--credit)
4. [Prerequisites](#prerequisites)
5. [Installation](#installation)
6. [Step-by-step: your first mission](#step-by-step-your-first-mission)
7. [The seven commands](#the-seven-commands)
8. [What you do vs. what the system does](#what-you-do-vs-what-the-system-does)
9. [Architecture: how it works behind the scenes](#architecture-how-it-works-behind-the-scenes)
10. [The four roles](#the-four-roles)
11. [File structure](#file-structure)
12. [Customization](#customization)
13. [Troubleshooting](#troubleshooting)
14. [Limitations & caveats](#limitations--caveats)

---

## Why this exists

Modern code-generation models are smart enough to implement most features. The
bottleneck isn't intelligence — it's **human attention**. Even strong engineers
can only drive a few tasks forward at a time, because each one needs their
review, their decisions, their context switches. A team might have a backlog of
fifty features but can only push a handful per day. Today's models could figure
out all fifty; there just isn't enough supervisory bandwidth to direct the
implementation.

Exexutor is built around a single trade: **you do more decision-making upfront
so the system can execute autonomously afterwards.** You don't write the code —
and you don't run any of the setup commands either. The orchestrator does all
the package installs, MCP registrations, env-file writes, and verifier runs. You
answer questions, approve the plan, paste credentials when asked, and clarify
each feature. Then you walk away.

What this system is intentionally **not**:

- **Not a no-code platform.** The output is a normal git repository. Read and
  edit the generated code whenever you want.
- **Not parallel.** Workers run serially by design — parallel writes break long
  missions; coordination overhead eats the speed gains.
- **Not a SaaS.** Everything is files in your repo.
- **Not magic.** The validation contract is the whole game. Get it right and
  execution is mostly automatic; get it wrong and no model upgrade rescues you.

---

## What makes it different

Two governing principles, referenced throughout the codebase as **P-1** and
**P-2**, override every default behaviour. They are what separate this from a
typical "AI writes code" workflow.

### P-1 — The orchestrator does work; the user only provides data

Most AI coding tools still hand you a tutorial: *"Step 1, run `npm install`.
Step 2, run `claude mcp add`. Step 3, copy your key to `.env`."* That breaks the
"walk away while it runs" promise several times per project.

Exexutor doesn't do that. The orchestrator runs every command itself via its
`Bash` tool. Your contribution is bounded to information that genuinely cannot be
obtained without you: **credentials, choices between options, and free-form
descriptions of intent.** If the orchestrator ever catches itself writing "now
run `npm install …`", the rule is to stop and run it itself.

### P-2 — Versions and setup come from web search, not memory

A model's training data is months or years out of date. Frameworks jump major
versions, libraries get deprecated and replaced, providers change auth-key
formats, and new MCP servers appear for services that had none at training time.

Before writing **any** version number, package name, CLI command, or auth scheme,
the orchestrator **web-searches to confirm the current state** — and annotates
every verified choice with a source URL and date:

```markdown
- Supabase JS client v2.x with publishable/secret keys
  <!-- verified against https://supabase.com/docs/guides/api/api-keys as of 2026-MM-DD -->
```

This is what catches real-world drift like Supabase migrating from legacy
`anon`/`service_role` JWT keys to new `sb_publishable_` / `sb_secret_` keys,
OpenAI's project-scoped `sk-proj-` keys, or a library you'd reach for from memory
having been abandoned and superseded.

### Why it's exceptional

- **Contract-first, with an immutable contract.** Features exist to satisfy
  falsifiable assertions, not the other way around. Once approved, the contract
  is locked — new requirements get new IDs; existing assertions are never edited.
- **Adversarial validation from two independent angles.** At every milestone,
  one validator reads the code (read-only, fans out parallel reviewers) and one
  drives the running app via Playwright. Neither sees the implementer's
  reasoning. Their bias is rejection — they even fail tests that merely mirror
  the implementation instead of verifying behaviour.
- **Determinism exactly where it matters — and nowhere else.** All orchestration
  logic lives in prompts/skills (so it improves automatically with every model
  release). The single thing that must be unfailable — "commit before exit,
  tests must pass" — is a ~200-line bash hook.
- **Built for long-horizon autonomy.** A `ZERO_QUESTIONS` run mode, a loop guard
  that defers a feature after 5 failed attempts, fresh-context workers, and
  structured handoffs mean it can genuinely run for hours unattended without
  stalling on "needs human input."
- **Everything is resumable and inspectable.** All state lives in files under
  `missions/<id>/`. Crash, close the laptop, come back tomorrow — each phase
  reads state from disk and picks up exactly where it left off.

---

## Inspiration & credit

The architecture is inspired by **Factory's "Missions"** system, as presented by
Luke (Factory) in his talk on multi-agent software engineering for the Anthropic
developer community. The original uses different primitives; this is a re-creation
built entirely on Claude Code's native **subagents, skills, slash commands, and
hooks.**

The central insight borrowed from that talk: *orchestration logic should live in
prompts and skills, not in deterministic code* — so the system gets better with
every model release, and four sentences in the right place can dramatically alter
execution strategy.

The two governing principles (P-1 and P-2) are additions that emerged from
real-world usage discovering specific failure modes — the orchestrator asking
users to run terminal commands, and the orchestrator using stale version
information from its training data.

---

## Prerequisites

These are **one-time tools you install once**. Note the distinction: anything a
*project* needs (frameworks, SDKs, MCP servers, databases) is installed by the
orchestrator during a mission — **not** by you. The list below is only what
Claude Code and the harness themselves require.

| Tool | Why it's needed |
|---|---|
| **Claude Code CLI** | The engine. The whole system runs inside it. |
| **Node.js** (LTS) | Required by Claude Code, by `claude mcp add`, and by most npm-based MCP servers the orchestrator installs. |
| **Git** | **Required.** The pre-worker-exit hook enforces a clean tree and a commit per feature; the run phase relies on per-feature commits for rollback. |
| **Python 3** | The `pre-worker-exit.sh` hook uses `python3` to emit valid JSON. Without it the hook fails. |
| **Bash + coreutils** | The hook is bash and uses `awk`/`grep`/`comm`/`sed`. Native on macOS & Linux; on Windows use WSL or Git Bash. |
| **Anthropic account / API access** | To authenticate Claude Code (Claude subscription or API key). |

### 1. Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

Then authenticate by launching it once and following the login prompt:

```bash
claude
```

> Verify the current install command and supported auth methods at
> <https://docs.claude.com/en/docs/claude-code> — the CLI evolves.

---

## Installation

The scaffold lives in the **`claude-missions/`** directory of this repo.

**Option A — start a brand-new project (recommended).** Copy the scaffold into a
fresh, empty folder where you want your project to live, then initialize git:

```bash
git clone https://github.com/cysecor/exexutor.git
cp -R exexutor/claude-missions/. my-new-project/
cd my-new-project
git init
claude --dangerously-skip-permissions
```

**Option B — try it in place.** Clone the repo and work inside the scaffold
directory directly:

```bash
git clone https://github.com/cysecor/exexutor.git
cd exexutor/claude-missions
git init
claude --dangerously-skip-permissions
```

That's it. Because the seven commands live in `.claude/commands/`, they appear
in Claude Code automatically — no registration step.

> **Git is mandatory.** The worker-exit hook checks `git status` and requires a
> `feat(F…)` commit before a worker may finish. If the directory isn't a git
> repo, the run phase won't behave correctly.

### Launch with `--dangerously-skip-permissions` from the very start

Start **every** phase — yes, from the first idea and planning step, not just the
run phase — with:

```bash
claude --dangerously-skip-permissions
```

**Why from the beginning?** This system is built on **P-1: the orchestrator does
the work, you only provide data.** That means the orchestrator runs Bash on your
behalf in *every* phase, not only during `/mission-run`:

- **Plan** — it web-searches and writes the contract, plan, and tech-decisions.
- **Connect** — it runs `npm install`, `claude mcp add`, writes `.env`, and
  executes verifier scripts.
- **Tasks** — it reads and writes mission state files.
- **Run** — it spawns workers that edit code, run tests, and commit.

Without the flag, Claude Code stops to ask for your approval **before every one
of those commands**. You'd be clicking "allow" dozens of times per phase — which
defeats the entire premise of "answer questions, then walk away." Launching with
`--dangerously-skip-permissions` lets the orchestrator move through scope →
discover → plan → connect → tasks → run **uninterrupted**, so the only things
that ever stop for you are the moments that genuinely need a human: answering
questions, approving the plan, and pasting credentials.

> **Use it in a directory you trust.** The flag lets the agent run bash and edit
> files without per-action confirmation. That's exactly what you want for a
> dedicated mission repo — but don't point it at a folder full of unrelated,
> sensitive files. One mission lives in its own repo by design, which keeps the
> blast radius contained.

---

## Step-by-step: your first mission

First, make sure you launched Claude Code with the flag — from this very first
step, not just the run phase:

```bash
claude --dangerously-skip-permissions
```

(See [why](#launch-with---dangerously-skip-permissions-from-the-very-start) — in
short, the orchestrator runs Bash on your behalf in every phase, so without the
flag you'd be approving commands constantly.)

Everything below is then typed **as slash commands inside Claude Code** — you
never leave the chat. Run them in order. The whole flow is resumable: each phase
checks its state files and refuses to run until the previous phase's outputs
exist.

### 1. Scope

```
/mission-scope "I want to build a Slack clone with channels, DMs, and threads"
```

Captures your description **verbatim** to `description.md`. No questions yet, no
rephrasing. This is the only place your exact words are stored unchanged.

### 2. Discover

```
/mission-discover
```

- **Round 1 — 30 broad questions** across six categories (Users & Access, Data,
  Interface, Integrations, Deploy & Ops, Quality & Constraints). All emitted in
  one message; each has 4 lettered options. Reply one line per question:

  ```
  1: b, 2: c, 3: a, 4: d, ...
  ```

  Any question accepts a custom answer: `7: custom — <your text>`.

- **Round 2 — 15 follow-ups** generated dynamically from your Round 1 answers, to
  close gaps and resolve contradictions. (45 answers total.)

### 3. Plan

```
/mission-plan
```

The orchestrator **web-searches current versions and MCP availability** (P-2),
then produces three files, in this exact order:

1. **`validation-contract.md`** — flat numbered list of falsifiable `AS-NNN`
   assertions (60–200 for a medium project).
2. **`plan.md`** — many small features (15–45 min each) grouped into milestones in
   dependency order. The first milestone is always **Foundation**.
3. **`tech-decisions.md`** — stack, libraries, file layout, and the exact
   run/test/lint commands, each version annotated with its verified source URL.

Review the three files, edit anything, then type:

```
approved
```

This writes `APPROVED` and **locks the contract** — it is now immutable.

### 4. Connect

```
/mission-connect
```

The orchestrator finds every external service, web-searches each one's current
auth format and MCP availability, and builds a manifest. Then, per service:

- It tells you, in one message, **what it will set up** (the commands it will run)
  and **what it needs from you** (a credential/URL/choice, plus a short pointer to
  where in the provider dashboard to find it).
- You **paste the credential in chat once.**
- It runs every install, registers the MCP via `claude mcp add`, writes `.env`
  (never echoing the value back), and runs a verifier.
- On failure it reports a safe error and asks you to re-check the data — it never
  tells you to "run" anything.

When all services pass, it writes `connections/mcp-registry.md` for the workers,
deletes the verifier scripts, and marks `VERIFIED`.

> **Security:** credentials only ever land in `.env` (gitignored). They are never
> printed back, never written to markdown, logs, or commits. The orchestrator
> refuses non-developer secrets (credit cards, IDs, banking details).

### 5. Tasks

```
/mission-tasks
```

Per-feature interrogation that turns each draft feature into a fully-specified
one. For every feature:

- **Round A — 10 task questions** (implementation pattern, data shape, state
  location, API contract, failure handling, empty state, validation, performance
  budget, access control, code dependencies).
- **Round B — 5 follow-ups** (generated from your Round A answers) **+ 5
  "definition of done"** questions.

Each question has 4 options with **one marked ★ recommended** based on context.
Shortcuts:

| Type this | Effect |
|---|---|
| letter codes | answer each question explicitly |
| `accept` | take all ★ defaults for the current feature |
| `accept and continue` | take ★ defaults for **all** remaining features, then finish |
| `skip F<NNN>` | defer a feature |
| `stop` | pause (resume later with `/mission-tasks`) |

### 6. Run

```
/mission-run
```

This phase is **`ZERO_QUESTIONS`** — the system never stops to ask you anything.
This is exactly why you launched with `--dangerously-skip-permissions` back at
[installation](#launch-with---dangerously-skip-permissions-from-the-very-start):
with no approval prompts and no questions, the loop below runs completely
unattended. If you skipped the flag earlier, restart Claude Code with it now —
otherwise every worker action will pause for your confirmation.

The orchestrator then loops, fully autonomously:

1. **MCP preflight** — verifies required MCP servers are registered.
2. **Pick the next feature** in dependency order whose deps are complete.
3. **Spawn a worker** in a fresh context. It reads the clarified spec, implements
   one feature, writes tests that reference assertion IDs, runs the full suite,
   commits as `feat(F<NNN>): … [assertions: AS-NN, …]`, and writes a handoff.
4. **The exit hook** blocks the worker if the tree is dirty, tests fail, the
   handoff is incomplete, or assertion IDs are missing.
5. `BLOCKED` / `PARTIAL` handoffs become **follow-up features** (inheriting the
   parent's clarification) — the run never stalls on "needs human input." After 5
   failed attempts on the same chain, the feature is `[DEFERRED]` and the loop
   moves on.
6. **At each milestone boundary**, two validators run in sequence — **scrutiny**
   (adversarial code review, parallel per-feature reviewers) then **UX** (boots
   the app, drives real flows via Playwright). Any failed assertion becomes a new
   follow-up feature.

Then **walk away.** It runs until every assertion is green.

### 7. Status (anytime)

```
/mission-status
```

Read-only, safe at any time. Reports phase completion, assertion counts,
milestone status, version searches performed, the last handoff, open blockers,
and the next planned action.

---

## The seven commands

```
/mission-scope "<one-line description>"   # Phase 1 — capture intent verbatim
/mission-discover                         # Phase 2 — 30 + 15 questions
/mission-plan                             # Phase 3 — contract, plan, tech (then `approved`)
/mission-connect                          # Phase 4 — orchestrator sets up all services
/mission-tasks                            # Phase 5 — per-feature 10 + 5 + 5 clarification
/mission-run                              # Phase 6 — execute until done (ZERO_QUESTIONS)
/mission-status                           # Phase 7 — read-only report (anytime)
```

Each phase **gates** the next: no planning without discovery answers, no connect
without an approved plan, no run until every feature is clarified.

---

## What you do vs. what the system does

**What you do, across an entire mission:**

- Type the initial `/mission-scope` description
- Answer 30 + 15 multiple-choice discovery questions
- Review the plan and type `approved`
- Sign up for provider accounts and generate credentials **in your browser**
- Paste credentials in chat when asked, by name
- Answer 20 clarification questions per feature (or `accept` / `accept and continue`)
- Optionally check `/mission-status`
- Walk away

**What you never do:**

- Open a terminal
- Run `npm install`, `pip install`, `claude mcp add`, or any setup command
- Edit `.env` by hand (the orchestrator writes it from what you paste)
- Edit Claude Code settings JSON
- Run verifier scripts (the orchestrator runs them and reports results)

---

## Architecture: how it works behind the scenes

The system is built entirely on Claude Code's native primitives. The deliberate
split is: **everything that benefits from model intelligence is a prompt
(skills, agents, commands); everything that must be unfailable is a hook
(bash).** The hook is ~200 lines; the entire rest of the system is Markdown.

### Four ideas everything follows from

- **State lives in files.** Every phase writes to `missions/<id>/`. Orchestrator,
  workers, validators, and you all read the same files. A mission resumes from
  disk after a crash — nothing important lives in memory.
- **The orchestrator does not write code.** The main session is a project
  manager: it scopes, plans, delegates, and reads results. Its only file edits
  happen inside `missions/<id>/`, `.env`, `.env.example`, and `.gitignore`.
  Everything else is a worker's job — this is what preserves the fresh-context
  guarantee.
- **Workers start fresh.** Each feature gets a new worker subagent with **no
  prior conversation history.** It reads its spec from disk, implements one thing,
  commits, writes a handoff, and exits. The next worker inherits a clean git
  state and a working codebase.
- **Validators are adversarial.** Two run at every milestone — neither saw the
  implementer's reasoning, both check the contract directly, and their bias is
  rejection.

### The native primitives

- **Subagents** (`.claude/agents/<name>.md`) — isolated workers spawned via the
  Agent tool, each with a fresh context window. The parent passes a prompt; the
  subagent's final message returns verbatim.
- **Skills** (`.claude/skills/<name>/SKILL.md`) — progressive-disclosure prompts
  loaded into context on demand. The orchestrator loads `version-freshness` and
  `mission-planning` when planning, `validation-contracts` when writing the
  contract, `connection-setup` when connecting, `task-clarification` during tasks,
  and `worker-mcp-usage` during run. Workers load `structured-handoffs`,
  `validation-contracts`, and `worker-mcp-usage`.
- **Slash commands** (`.claude/commands/<name>.md`) — shape the main session into
  a phase-specific orchestrator.
- **Hooks** (`.claude/hooks/<name>.sh`) — intercept lifecycle events. The
  scaffold ships one: `pre-worker-exit.sh`, registered for `SubagentStop` events
  filtered to the worker subagent.

### The enforcement hook (why prompts alone aren't enough)

"You must commit before exiting" is a *hope*; a bash check is a *guarantee*. On
every worker exit, `pre-worker-exit.sh` **blocks** the worker (forcing it to
continue) unless:

1. A handoff file exists in `missions/<id>/handoffs/`.
2. The handoff contains every required section.
3. If Status is `COMPLETE`: the git tree is clean, a recent `feat(F…)` commit
   exists, **the project's test command passes**, and the handoff's assertion IDs
   match those assigned in the spec.

The hook reads the test command straight out of `tech-decisions.md`, so it always
runs the right suite for the project being built.

### Control flow at a glance

```
/mission-scope ─▶ description.md
       │
/mission-discover ─▶ discovery/round-1.md, round-2.md
       │
/mission-plan ─▶ (web search) ─▶ validation-contract.md + plan.md + tech-decisions.md
       │                                      │
   `approved` ─▶ APPROVED  (contract now immutable)
       │
/mission-connect ─▶ (web search) ─▶ per-service: ask data ▸ install ▸ register MCP ▸
       │             write .env ▸ verify ─▶ mcp-registry.md + VERIFIED
       │
/mission-tasks ─▶ per feature: Round A (10) + Round B (5+5) ─▶ clarified specs
       │
/mission-run ──┐  (ZERO_QUESTIONS)
       │       │  pick feature ▸ spawn worker (fresh ctx) ▸ implement+commit+handoff
       │       │        ▼ pre-worker-exit hook gate
       │       │  BLOCKED/PARTIAL ▸ follow-up feature   |   5 fails ▸ [DEFERRED]
       │       │  milestone boundary ▸ scrutiny validator ▸ UX validator
       │       └──────────────── loop until every assertion GREEN
       │
/mission-status ─▶ read-only report (safe anytime)
```

---

## The four roles

| Role | Default model | What it does | Tools |
|---|---|---|---|
| **Orchestrator** (main session) | `claude-opus-4-7` | Scoping, planning, judgement, all setup execution. Never writes project code. | All file tools, Bash, WebSearch, WebFetch, slash commands, Agent |
| **Worker** | `claude-sonnet-4-6` | Implements exactly one feature in a fresh context; uses MCP for live service introspection. | Read, Write, Edit, Bash, Grep, Glob, MCP (per registry) |
| **Scrutiny validator** | `claude-opus-4-7` | Adversarial milestone code review; fans out parallel per-feature reviewers. Read-only. | Read, Bash, Grep, Glob, Agent |
| **UX validator** | `claude-opus-4-7` | Boots the running app and drives real user flows. | Read, Bash, Playwright MCP |

> Model strings age — update the `model:` field in each agent file as new releases
> ship. The single highest-leverage change is putting a **different model family**
> on the scrutiny validator (via a proxy) to break shared training-data bias.

---

## File structure

```
.
├── README.md                                # this file
├── claude-missions/                         # the scaffold — copy this into your project
│   ├── CLAUDE.md                            # repo-wide rules every agent inherits
│   ├── README.md
│   ├── DOCS.md                              # full design documentation
│   ├── .gitignore
│   ├── .claude/
│   │   ├── settings.json                    # registers the SubagentStop hook
│   │   ├── agents/
│   │   │   ├── worker.md
│   │   │   ├── scrutiny-validator.md
│   │   │   └── ux-validator.md
│   │   ├── skills/
│   │   │   ├── mission-planning/SKILL.md
│   │   │   ├── discovery-questions/SKILL.md
│   │   │   ├── task-clarification/SKILL.md
│   │   │   ├── validation-contracts/SKILL.md
│   │   │   ├── connection-setup/SKILL.md
│   │   │   ├── version-freshness/SKILL.md
│   │   │   ├── worker-mcp-usage/SKILL.md
│   │   │   ├── structured-handoffs/SKILL.md
│   │   │   └── model-selection/SKILL.md
│   │   ├── commands/
│   │   │   ├── mission-scope.md
│   │   │   ├── mission-discover.md
│   │   │   ├── mission-plan.md
│   │   │   ├── mission-connect.md
│   │   │   ├── mission-tasks.md
│   │   │   ├── mission-run.md
│   │   │   └── mission-status.md
│   │   └── hooks/
│   │       └── pre-worker-exit.sh
│   └── missions/
│       ├── CURRENT                          # active mission id
│       └── <mission-id>/                    # all mission state (created per run)
│           ├── description.md               # phase 1
│           ├── discovery/round-{1,2}.md     # phase 2
│           ├── validation-contract.md       # phase 3
│           ├── plan.md
│           ├── tech-decisions.md
│           ├── APPROVED
│           ├── connections/manifest.md      # phase 4
│           ├── connections/mcp-registry.md
│           ├── connections/VERIFIED
│           ├── features/F<NNN>-*.md         # draft + clarified
│           ├── clarifications/F<NNN>-*.md   # phase 5
│           ├── handoffs/F<NNN>-handoff.md   # phase 6
│           └── milestones/M<N>-{scrutiny,ux}.md
└── AGENTS.md                                # notes
```

---

## Customization

The intended customization seams are the skill files — edit Markdown, not a state
machine:

- **`discovery-questions/SKILL.md`** — add domain-specific categories to the 30 defaults.
- **`task-clarification/SKILL.md`** — tune the 10 task + 5 done questions to your stack.
- **`connection-setup/SKILL.md`** — extend the service catalogue with your internal services (the most valuable team-specific fork).
- **`version-freshness/SKILL.md`** — add known-deprecated patterns specific to your stack.
- **`mission-planning/SKILL.md`** — your stack opinions.
- **`structured-handoffs/SKILL.md`** — add workflow-specific sections.
- **The `model:` field** in each agent file.
- **`.claude/hooks/pre-worker-exit.sh`** — add your own checks.
- **`CLAUDE.md`** — append house rules every agent inherits.

**Do not edit** (until you really know why): the serial-execution rule, the
"orchestrator never edits code" rule, the contract-immutability rule, the
credential-security rules, the version-search requirement, and P-1 / P-2.

---

## Troubleshooting

- **Orchestrator used a legacy auth format.** A P-2 miss. Check `tech-decisions.md`
  — every version should carry an inline source-URL comment. If one is missing, the
  search was skipped; ask it to re-verify.
- **Orchestrator asked you to run a command.** A P-1 violation. Reply: *"You run
  it."* Setup commands are its job, via Bash.
- **A validator keeps approving things that don't work.** Most often shared
  training-data bias — switch the scrutiny validator to a different model family.
- **Workers keep producing PARTIAL handoffs.** Features are too big (split further)
  or clarification answers contradict each other.
- **Hook blocks worker exit incorrectly.** Read the hook's `reason` field; edit the
  hook if it's genuinely wrong.
- **Re-clarify a feature mid-run.** Delete both `clarifications/F<NNN>-…md` and the
  appended sections in `features/F<NNN>-*.md`, then re-run `/mission-tasks`.
- **Abandon a mission and start over.** Run `/mission-scope` again; the old mission
  directory stays on disk.

---

## Limitations & caveats

- **Hooks API may drift.** Verify the `SubagentStop` matcher format in
  `.claude/settings.json` against current Claude Code docs.
- **Model strings will age.** Update agent files as new releases ship.
- **The hook re-runs your full test command** on every `COMPLETE` handoff — split
  huge suites into fast/full.
- **Clarification cost scales.** 80 features × 20 questions = 1,600 questions; the
  `accept and continue` escape is essential.
- **One mission per repo** (single working tree). Run parallel missions in separate
  clones.
- **No automatic rollback** — but the system commits per feature, so
  `git reset --hard <last-good-sha>` always works.
- **Account creation, browser-only OAuth, and payment setup** still require your
  action — but you get a two-or-three-sentence pointer, never a tutorial.

---

*Inspired by Factory's "Missions"; rebuilt on Claude Code's native subagents,
skills, slash commands, and hooks.*
