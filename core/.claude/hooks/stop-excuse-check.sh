#!/bin/bash
# Stop hook: if the last assistant turn used the banned excuse phrase ("pre-existing"),
# block the stop once and tell the agent to fix the failure instead. No jq required.

input=$(cat)

# Never re-block while already continuing because of a Stop hook (prevents loops).
printf '%s' "$input" | grep -q '"stop_hook_active": *true' && exit 0

transcript=$(printf '%s' "$input" | sed -n 's/.*"transcript_path": *"\([^"]*\)".*/\1/p' | sed 's#\\\\#/#g')
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

last_assistant=$(grep '"type":"assistant"' "$transcript" 2>/dev/null | tail -n 1)

if printf '%s' "$last_assistant" | grep -qiE 'pre-?existing'; then
  cat >&2 <<'MSG'
REMINDER: "pre-existing" is not an accepted excuse.

Main is always clean -- CI enforces this. Any failure on the branch was introduced by us and must be fixed before any approval, handoff, or commit. The Boy Scout Rule applies: leave the code in a better state than you found it.

Stop and fix the failure. If it is outside your scope and you are in multi-agent mode, escalate to the team lead. Never approve, hand off, or commit with known failures.
MSG
  exit 2
fi

exit 0
