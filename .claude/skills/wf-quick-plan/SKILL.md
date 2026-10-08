---
name: wf-quick-plan
description: Enters planning mode while enforcing Claude Workflow project standards
argument-hint: "[task description]"
---

# Quick Plan — Plan Mode with Standards Enforcement

It behaves just like Claude Code's built-in plan mode, plus one addition: the plan it produces must discover and enforce the project's coding standards from `.claude-workflow/docs/`.

## Workflow

1. **Get the task** — If an argument was provided, use it. Otherwise ask with `AskUserQuestion`: "What would you like to plan?"

2. **Enter plan mode** — Call `EnterPlanMode` and let plan mode proceed exactly as usual (explore the codebase, design the approach, write the plan, then `ExitPlanMode` for approval). Do not redefine its phases.

3. **Discover and enforce standards (the addition)** — During planning:
   - Read `.claude-workflow/docs/INDEX.md` to learn which standards exist.
   - **Then read the specific standard files it points to that apply to this task.** Reading INDEX.md alone is NOT sufficient — this step is mandatory.
   - Work the matched standards into the plan itself: cite the governing standard wherever it shapes a step, and include a **`## Standards Compliance Checklist`** — one checkbox for each applicable guideline the implementation has to satisfy (each annotated with its source file, e.g. `(from standards/backend/api.md)`). This checklist gets verified after implementation.

   When `.claude-workflow/docs/INDEX.md` does not exist, plan as usual and note in the plan: "No Claude Workflow standards found. Consider running `/wf-init`."

Do not call `ExitPlanMode` before the plan reflects the applicable standards and contains the Standards Compliance Checklist (or the "no standards found" note).

4. **After approval — implement and verify (mandatory)** — After the plan is approved and you implement it, walk through the `## Standards Compliance Checklist` and verify every item — mark it pass/fail and report it. Resolve any failure before marking the task complete.
