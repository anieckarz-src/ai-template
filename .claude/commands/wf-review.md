---
name: wf-review
description: Read-only code review covering quality & security, over-engineering, and production readiness (GO/NO-GO)
---

**ACTION REQUIRED**: This command hands off to the `wf-code-reviewer` subagent. The `<command-name>` tag points to THIS command, not to the target. Invoke the subagent through the Task tool NOW. Do not read files, explore code, or carry out review steps yourself.

Performs a single read-only review of a path: (A) quality & security, (B) over-engineering/simplification, (C) production readiness with a GO / NO-GO verdict.

## Arguments

- **Path** (required): a file, directory, or task directory. When it is missing, ask for it with AskUserQuestion.
- `--focus=all|quality|simplicity|production` (default `all`)

**Report path**: when the path is a task directory (`.claude-workflow/tasks/<type>/<task>/`), use `<task dir>/verification/code-review-report.md` and pass the task dir as `task_path`; otherwise use `.claude-workflow/reviews/YYYY-MM-DD-review.md` (today's date). Never place the report inside the source directory being reviewed.

## Invocation

```
Use Task tool:
  subagent_type: "wf-code-reviewer"
  description: "Code review"
  prompt: |
    Review code at: [path]
    Focus: [all|quality|simplicity|production]
    Report path: [report path]
    Task path: [task dir, only when given a task directory]
```

## After It Finishes

Display the report path, the summary counts (critical / warning / info) for each section, and the GO / NO-GO verdict if production readiness ran. No code gets modified; ask the user whether they want any findings addressed.
