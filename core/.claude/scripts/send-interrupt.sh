#!/bin/bash
# Send an interrupt to a running agent-team member.
# Usage: send-interrupt.sh <team-name> <agent-name> "<message>"
# Writes "#<id> <message>" to ~/.claude/teams/<team>/signals/<agent>.signal atomically and
# prints "#<id>". The PostToolUse hook .claude/hooks/check-interrupt.sh delivers it on the
# agent's next tool call; the caller then sends a SendMessage prefixed with the same ID.

set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 <team-name> <agent-name> \"<message>\"" >&2
  exit 1
fi

team="$1"; agent="$2"; shift 2; message="$*"
team_dir="$HOME/.claude/teams/$team"

if [ ! -d "$team_dir" ]; then
  echo "Team '$team' not found in $HOME/.claude/teams" >&2
  exit 1
fi

id="$(date +%H%M%S)$((RANDOM % 100))"
signals_dir="$team_dir/signals"
mkdir -p "$signals_dir"
tmp="$signals_dir/.$agent.signal.$$"
printf '#%s %s' "$id" "$message" > "$tmp"
mv -f "$tmp" "$signals_dir/$agent.signal"
echo "#$id"
