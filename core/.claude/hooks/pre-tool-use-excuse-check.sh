#!/bin/bash
# PreToolUse hook: if a tool call contains the banned excuse phrase ("pre-existing"),
# inject a non-blocking reminder. The tool call still proceeds. No jq required.

input=$(cat)

if printf '%s' "$input" | grep -qiE 'pre-?existing'; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"REMINDER: \"pre-existing\" is not an accepted excuse. Main is always clean -- CI enforces this. Any failure on the branch was introduced by us and must be fixed before any approval, handoff, or commit. Boy Scout Rule: leave the code better than you found it. Stop and fix the failure; if it is outside your scope in multi-agent mode, escalate to the team lead. Never approve, hand off, or commit with known failures."}}'
fi

exit 0
