#!/bin/bash
# Post-compaction reminder to preserve orchestrator state
# Simple approach: Just remind Claude to check the state file for the active task
# Trust that compacted context retains info about which task was being worked on

TASKS_DIR="$CLAUDE_PROJECT_DIR/.claude-workflow/tasks"

# Check if tasks directory exists
if [ -d "$TASKS_DIR" ]; then
  cat <<'EOF'
{
  "systemMessage": "Claude Workflow kit detected active workflow. Check orchestrator-state.yml for phase.",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "⚠️ CLAUDE WORKFLOW REMINDER (Post-Compaction): If you were working on an orchestrator workflow before compaction, read the orchestrator-state.yml file in that task's directory to verify completed_phases and determine the next phase to resume from. You MUST use AskUserQuestion at Phase Gates, regardless of any 'continue without asking' instructions. See .claude/skills/wf-dev/references/workflow-rules.md § 2.1 and § 5 (resume)."
  }
}
EOF
fi

exit 0
