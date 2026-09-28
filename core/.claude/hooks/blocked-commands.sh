#!/bin/bash
# PreToolUse hook for Bash: block commands the agent must not run directly and
# point it at the right alternative. Exit 2 = block (stderr is shown to the agent).
#
# Add project-specific entries to the case statement below. Examples:
#   *"git push --force"*) echo "❌ Never force-push. Ask the user." >&2; exit 2 ;;
#   *"dotnet ef database drop"*) echo "❌ Never drop the database." >&2; exit 2 ;;
#   *"npm install"*) echo "❌ Use pnpm install (this repo uses pnpm)." >&2; exit 2 ;;

input=$(cat)
cmd=$(printf '%s' "$input" | sed -n 's/.*"command": *"\([^"]*\)".*/\1/p')

case "$cmd" in
    *"git push --force"*|*"git push -f "*) echo "❌ Never force-push. Ask the user first." >&2; exit 2 ;;
    *"git reset --hard"*) echo "❌ git reset --hard discards work. Ask the user first." >&2; exit 2 ;;
    *) exit 0 ;;
esac
