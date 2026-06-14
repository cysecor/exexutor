#!/usr/bin/env bash
# pre-worker-exit.sh
#
# Runs on SubagentStop for the 'worker' subagent. Blocks worker exit if:
#   1. No handoff file exists in missions/<id>/handoffs/
#   2. The handoff is missing any required section
#   3. Status is COMPLETE but git working tree is dirty
#   4. Status is COMPLETE but the test command from tech-decisions.md fails
#   5. Status is COMPLETE but assertion IDs listed in the handoff don't match
#      the assignments in plan.md for this feature
#
# Strict mode. There is no relaxation flag in this starter — the talk
# specifically argued that strict serial validation is what makes long runs
# work. Edit this file if you really want to relax it.
#
# Returns JSON to stdout. Exit code 0 = allow, 2 = block (forces the subagent
# to continue). The block JSON's "reason" field is fed back to the worker as
# instructions.

set -euo pipefail

# ---------- Helpers ----------

allow() {
  echo '{"decision":"allow"}'
  exit 0
}

block() {
  # $1: reason string. Escapes to valid JSON.
  python3 -c '
import json, sys
print(json.dumps({"decision":"block","reason":sys.argv[1]}))
' "$1"
  exit 2
}

# ---------- Find active mission ----------

if [ ! -f missions/CURRENT ]; then
  # No active mission — nothing to enforce. Allow.
  allow
fi

MISSION_ID=$(tr -d '[:space:]' < missions/CURRENT)
MISSION_DIR="missions/$MISSION_ID"

if [ ! -d "$MISSION_DIR" ]; then
  block "missions/CURRENT references $MISSION_ID but $MISSION_DIR does not exist. Recreate the mission directory or reset missions/CURRENT before exiting."
fi

# ---------- 1. Handoff file exists ----------

shopt -s nullglob
HANDOFFS=( "$MISSION_DIR"/handoffs/F*.md )
if [ ${#HANDOFFS[@]} -eq 0 ]; then
  block "No handoff file found in $MISSION_DIR/handoffs/. Write F<NNN>-handoff.md using the template in the structured-handoffs skill before exiting."
fi

# Most recently modified handoff = the one this worker wrote
LATEST_HANDOFF=$(ls -t "$MISSION_DIR"/handoffs/F*.md 2>/dev/null | head -n1)

# ---------- 2. Required sections present ----------

REQUIRED_SECTIONS=(
  "## Status"
  "## Assertions covered"
  "## Files changed"
  "## Commands run"
  "## Decisions made"
  "## Out-of-scope work needed"
  "## Blockers"
  "## Notes for the next worker"
)

MISSING=()
for s in "${REQUIRED_SECTIONS[@]}"; do
  if ! grep -qF "$s" "$LATEST_HANDOFF"; then
    MISSING+=("$s")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  block "Handoff $LATEST_HANDOFF is missing required sections: $(IFS=, ; echo "${MISSING[*]}"). All sections in the structured-handoffs template are mandatory — include the header even if the body is empty."
fi

# ---------- 3. Status value ----------

STATUS=$(awk '/^## Status$/{flag=1; next} flag && NF{print; exit}' "$LATEST_HANDOFF" | tr -d '[:space:]')

case "$STATUS" in
  COMPLETE|PARTIAL|BLOCKED) ;;
  "")
    block "Handoff $LATEST_HANDOFF has an empty Status section. Set it to COMPLETE, PARTIAL, or BLOCKED."
    ;;
  *)
    block "Handoff $LATEST_HANDOFF has invalid Status value: '$STATUS'. Must be one of: COMPLETE, PARTIAL, BLOCKED."
    ;;
esac

# Blockers section must be non-empty when status isn't COMPLETE
if [ "$STATUS" != "COMPLETE" ]; then
  BLOCKERS_BODY=$(awk '/^## Blockers$/{flag=1; next} /^## /{flag=0} flag{print}' "$LATEST_HANDOFF" | tr -d '[:space:]')
  if [ -z "$BLOCKERS_BODY" ]; then
    block "Status is $STATUS but the Blockers section is empty. Describe what stopped you using the BLOCKER/TRIED/NEEDED/SUGGESTED FOLLOWUP format from the structured-handoffs skill."
  fi
fi

# ---------- 4 & 5. Apply only when status COMPLETE ----------

if [ "$STATUS" = "COMPLETE" ]; then

  # 4a. git working tree must be clean
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    DIRTY=$(git status --porcelain | head -n 10)
    block "Status is COMPLETE but git working tree is dirty. Commit your changes before exiting. Outstanding files: $DIRTY"
  fi

  # 4b. there must be at least one commit since this hook last allowed an exit
  # (heuristic: there's a commit in the last hour matching feat(F...))
  RECENT_COMMIT=$(git log --since="2 hours ago" --grep="^feat(F" --oneline 2>/dev/null | head -n1 || true)
  if [ -z "$RECENT_COMMIT" ]; then
    block "Status is COMPLETE but no recent commit matching 'feat(F<NNN>):' was found in the last 2 hours. Commit using the format: feat(F<NNN>): <summary> [assertions: AS-NN, AS-NN]"
  fi

  # 4c. test command from tech-decisions.md must pass
  TECH="$MISSION_DIR/tech-decisions.md"
  if [ -f "$TECH" ]; then
    # Pull the first fenced command after a line matching /how to run tests/i
    TEST_CMD=$(awk '
      tolower($0) ~ /how to (run )?tests?/ {found=1; next}
      found && /^```/ {in_block=!in_block; next}
      found && in_block && NF {print; exit}
    ' "$TECH" || true)

    if [ -n "$TEST_CMD" ]; then
      if ! eval "$TEST_CMD" > /tmp/missions-test-output.log 2>&1; then
        TAIL=$(tail -n 40 /tmp/missions-test-output.log)
        block "Status is COMPLETE but the test command failed. Command: $TEST_CMD. Last 40 lines of output: $TAIL. Either fix the failures and re-commit, or change Status to PARTIAL/BLOCKED and document in Blockers."
      fi
    fi
  fi

  # 5. Assertion IDs in handoff vs plan.md
  PLAN="$MISSION_DIR/plan.md"
  FEATURE_ID=$(basename "$LATEST_HANDOFF" | sed -E 's/^(F[0-9]+).*$/\1/')
  if [ -f "$PLAN" ] && [ -n "$FEATURE_ID" ]; then
    EXPECTED_ASSERTIONS=$(grep -oE "AS-[0-9]+" "$PLAN" | sort -u || true)
    HANDOFF_ASSERTIONS=$(grep -oE "AS-[0-9]+" "$LATEST_HANDOFF" | sort -u || true)

    # We only check that every assertion referenced in plan.md for this feature
    # also appears in the handoff. Plan parsing is naive; the worker's spec is
    # the source of truth, so we look at the spec file directly.
    SPEC=$(ls "$MISSION_DIR"/features/"$FEATURE_ID"-*.md 2>/dev/null | head -n1 || true)
    if [ -n "$SPEC" ]; then
      SPEC_ASSERTIONS=$(grep -oE "AS-[0-9]+" "$SPEC" | sort -u || true)
      MISSING_IDS=$(comm -23 <(echo "$SPEC_ASSERTIONS") <(echo "$HANDOFF_ASSERTIONS"))
      if [ -n "$MISSING_IDS" ]; then
        block "Status is COMPLETE but the handoff is missing assertion IDs assigned in $SPEC: $(echo "$MISSING_IDS" | tr '\n' ' '). Add a line per assertion under '## Assertions covered'."
      fi
    fi
  fi
fi

allow
