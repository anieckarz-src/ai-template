---
name: team-interrupt
description: Send an interrupt signal to a working team agent. Use when an agent is actively running and you need to send it a message without having to wait until it has processed all other messages.
---

# Team Interrupt

`SendMessage` is for idle/hibernated agents only. If the agent is working, the message sits in the queue and is processed later against stale context - answers will be obsolete and queued instructions may already be wrong. To reach a working agent, use an interrupt. Never queue status checks, redirects, or corrections behind active work.

## How It Works

`.claude/scripts/send-interrupt.sh` writes the message to `~/.claude/teams/<team>/signals/<agent>.signal`. A PostToolUse hook in the target agent's session picks up the signal file after its next tool call and delivers the message immediately, ahead of anything queued.

## Procedure

1. Run (use the relative path exactly as written - do not expand it to an absolute worktree path):
   ```bash
   bash .claude/scripts/send-interrupt.sh <team> <agent> "<your instruction>"
   ```
   - `<team>` - the team name (as in `~/.claude/teams/<team>/`)
   - `<agent>` - the target agent's name in that team
   - Quote the message; keep it standalone (the agent reads it mid-task, without your context)
2. The script prints a single `#<id>` line. Send a follow-up `SendMessage` to the same agent with the body prefixed by that ID:
   ```
   #<id> <your instruction>
   ```
   The signal delivers the instruction immediately; the ID-prefixed message keeps it in the agent's inbox. The agent skips stale queued messages until it sees the matching ID and does not act on the same ID twice.
3. If the script exits non-zero, report its error to the user and stop. Do not fall back to a plain queued `SendMessage` for a working agent.
4. STOP - no follow-ups.
