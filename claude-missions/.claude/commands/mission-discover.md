---
description: Run the two-round discovery questionnaire (30 broad questions, then 15 follow-ups) to build shared understanding before planning.
allowed-tools: Bash, Read, Write
---

## Pre-flight

1. Read `missions/CURRENT` for the active mission ID. Abort if missing — tell the user to run `/mission-scope` first.
2. Verify `missions/<id>/description.md` exists. Abort if missing.
3. Load the `discovery-questions` skill.

## State-based dispatch

Check which round you're in by which files exist:

- Neither `discovery/round-1.md` nor `discovery/round-2.md` exists → start round 1.
- `round-1.md` exists, `round-2.md` doesn't → start round 2.
- Both exist → tell the user discovery is already complete and recommend `/mission-plan`.

## Round 1 — 30 broad questions

1. Read `description.md`. Identify what kind of project this is (web app, mobile, CLI, API, etc.).
2. Using the **discovery-questions** skill's default 30-question set, adapt the questions to the project type:
   - For a CLI tool, interface questions become CLI-specific (TTY rendering, exit codes, flags vs interactive mode).
   - For an API-only service, swap UI questions for API-shape questions (REST vs GraphQL, versioning, rate limits, etc.).
   - For a mobile app, swap deployment for app-store questions.
   - When in doubt, keep the default web-app questions and add a note explaining the substitution.
3. Emit the 30 questions in **one structured message** to the user, grouped into the 6 categories the skill defines. Use the exact format from the skill (single message, scannable, each question has 4 lettered options).
4. End the message with a "How to answer" footer instructing the user to reply with one line per question like `1: a`, `2: c`, etc., and that they may write a custom answer for any question by typing `7: custom — <their text>`.
5. **Stop.** Wait for the user's answers in the next turn.

When the user replies with answers:

6. Parse their answers. If any question is unanswered, ask only about those.
7. Once all 30 are answered, write `missions/<id>/discovery/round-1.md` with each question, the options as presented, and the chosen answer per question.
8. Proceed immediately to round 2 in the same turn.

## Round 2 — 15 gap-closing follow-ups

1. Read `description.md` and `round-1.md`. Identify open questions, contradictions, and underspecified areas. Examples that should trigger follow-ups:
   - Chose "Postgres" + "real-time core" → ask about Realtime tech (logical replication, dedicated WS service, pub/sub broker)
   - Chose "OAuth" + "enterprise compliance" → ask which IdPs specifically, SAML vs OIDC
   - Chose "AI/LLM features" → ask about prompt management, evals, fallback strategy, latency tolerance
   - Chose ambiguous combinations → ask the disambiguator
2. Generate exactly 15 follow-up questions, each with 4 lettered options. Same single-message structured format as round 1.
3. Emit them.
4. **Stop.** Wait for the user's answers.

When the user replies:

5. Parse answers. Write `missions/<id>/discovery/round-2.md` with the same format as round 1.
6. Print:

   > Discovery complete. 45 answers recorded.
   >
   > Next: run `/mission-plan` to produce the validation contract, plan, and tech decisions from your answers.

## Hard rules

- Always present **all** questions of a round in one message. Don't drip-feed.
- Always provide exactly 4 options per question, plus the implicit "custom" escape hatch.
- Never start writing the plan or contract in this phase.
- Never edit the user's answers, even to "improve" them. If something is ambiguous, ask a clarifier in round 2 — don't reinterpret silently.
