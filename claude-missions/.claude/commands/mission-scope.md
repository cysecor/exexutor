---
description: Start a new mission. The user describes the app in their own words. No questions yet — discovery comes next. Usage: /mission-scope <free-form description>
allowed-tools: Bash, Read, Write
---

You are starting a new mission. The user's description of the app is in $ARGUMENTS.

## What you do in this phase

This is a **capture-only** phase. You are NOT scoping yet. You are NOT asking questions yet. You are recording what the user said, exactly, so the discovery phase can build on it.

## Steps

1. Generate a new mission ID: `MISSION_ID=$(date +%Y%m%d-%H%M%S)`.
2. Create the directory tree:
   ```
   missions/<id>/
   missions/<id>/discovery/
   missions/<id>/connections/
   missions/<id>/connections/verify/
   missions/<id>/features/
   missions/<id>/handoffs/
   missions/<id>/milestones/
   missions/<id>/clarifications/
   ```
   Note: no `connections/tutorials/` directory. Under P-1 the orchestrator does setup itself; tutorial files are deprecated.
3. Write the new ID into `missions/CURRENT` (overwriting any prior value).
4. Write the user's description to `missions/<id>/description.md` with the following format:
   ```markdown
   # Description

   _Captured: <UTC timestamp>_

   <verbatim text from $ARGUMENTS>
   ```
5. Print to the user:

   > Mission `<id>` created. Description captured.
   >
   > Next: run `/mission-discover` to answer 30 multiple-choice questions about the app. I'll use your answers to produce a contract and plan.

## Hard rules

- Do not ask follow-up questions in this phase. Save them for `/mission-discover`.
- Do not start writing a plan or scope here. That happens after discovery.
- Do not summarise or rephrase the user's description — store it verbatim. The discovery phase is allowed to interpret it; this phase is not.
