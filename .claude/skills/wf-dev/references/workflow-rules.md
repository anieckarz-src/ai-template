# Workflow Rules

Execution rules, the state schema, and the shared contracts used by the `wf-dev` orchestrator and the two skills it drives (`wf-implementation-plan-executor`, `wf-implementation-verifier`).

## Contents

1. Delegation Rules
2. Phase Gates (2.1 Decide once; 2.2 Entry checks; 2.3 Auto-continue)
3. Context Passing & Decisions
4. State File (4.1 Timestamps; 4.2 Write rule; 4.3 Schema)
5. Initialization & Resume
6. Issue Resolution & User-Confirmed Rollback
7. Artifact Summary Contract
8. Finalization: Artifact Reconciliation

---

## 1. Delegation Rules

**Always delegate via the Skill or Task tool. Never execute delegated work inline.**

- **Skill tool** for skills (`wf-codebase-analyzer`, `wf-implementation-plan-executor`, `wf-implementation-verifier`) — it loads instructions into the main agent, which then carries on with the workflow. These skills launch their own subagents, and subagents cannot launch subagents, so they must run in the main context.
- **Task tool** for agents (`wf-gap-analyzer`, `wf-specification-creator`, `wf-spec-auditor`, `wf-implementation-planner`, `wf-code-reviewer`, `wf-test-suite-runner`, `wf-implementation-completeness-checker`, ...) — an isolated subprocess that hands back a result.
- Skills and agents cannot be swapped for each other: passing a skill as `subagent_type` fails with "Agent type not found". Reading a SKILL.md and doing the work yourself does not count as invoking it.
- Wait until it completes before continuing.

**Inline is acceptable only for**: AskUserQuestion clarification rounds, state reads/writes, phase announcements, enabling/disabling optional phases, finalization summaries, and the TDD red/green test runs that the phase explicitly marks "Direct".

**Never inline**, no matter how simple it seems: codebase analysis, gap analysis, specification, implementation planning, implementation, code review, test-suite execution, completeness checking. "The task is simple" is no reason to skip delegation.

---

## 2. Phase Gates

**`→ MANDATORY GATE` means STOP and invoke `AskUserQuestion`, then wait for the answer.** Writing "I'll pause here" is not a pause; only the tool call is.

- The gate is the first action once phase work completes — no summary-then-end-turn ahead of it.
- **State ordering**: a phase gets marked completed (state file or `TaskUpdate`) only AFTER the user has answered its exit gate. Work → gate → answer → state update; never the other way round.
- A DECISION GATE (which fires when a subagent returns `decisions_needed`) is separate from the phase exit gate. An empty `decisions_needed` skips only the former.
- The orchestrator is the only channel to the user. Subagents work autonomously; the orchestrator does not.

### 2.1 Decide once: gates override session reminders and permission modes

Settle this when entering the orchestrator and do not re-evaluate it at each gate:

- `→ MANDATORY GATE` fires in every permission mode (`default`, `acceptEdits`, `auto`, `plan`, `bypassPermissions`).
- Reminders such as "work without stopping", "continue without asking", "minimize clarifying questions" cover only your discretionary questions, never workflow gates.
- A compaction summary or earlier session in which the user approved every gate shows patience, not policy. Every gate is a fresh question.
- If you notice yourself reasoning "the user approves everything / auto mode is on / this task is simple, so I can skip this gate" — that reasoning is the documented failure mode. STOP and fire the gate. Re-arguing the rule gate by gate is how it gets lost.

### 2.2 Phase entry checks

Each phase that comes after a gate begins with a self-check: find the previous gate's `AskUserQuestion` call in the conversation. If it can't be found, fire that gate now before doing any work. Never paper over a missed gate by updating state.

### 2.3 Auto-continue

`→ AUTO-CONTINUE`: you may print a summary of 1-2 lines, then move on immediately. Do not end the turn, do not ask, do not wait.

---

## 3. Context Passing & Decisions

### Context passing

Subagents run in an isolated context. Each delegation prompt contains:

- Task instructions and the task path
- **Context from prior phases**: the relevant `task_context` fields and `phase_summaries` entries
- **Artifacts to read**: paths for the full detail
- **Artifact summary contract** (§ 7) for any subagent that writes markdown

### Context extraction

After every phase, write `task_context.phase_summaries.[phase]` (shape in § 4.3): a summary of 1-2 sentences plus `decisions`, `risks` and `artifacts` taken from the artifact's summary block.

Structured fields that drive routing (e.g. the gap-analyzer's `task_characteristics`, `risk_level`) go into state right away, verbatim — not merely summarized — and are verified by re-reading the state file.

### Decision enforcement

A subagent's `decisions_needed` is always presented through `AskUserQuestion`. Accepting "recommended defaults", logging decisions without asking, or skipping them because they seem obvious all take control away from the user.

- Each decision is a separate single-select question with its own option set — never collapse several decisions into one option list.
- Critical decisions: one `AskUserQuestion` call apiece, with context shown first. Important decisions: up to 4 separate questions in a single call.
- Multi-select only for truly non-exclusive options (e.g. "which verifications to run?").
- Self-check: "Did I present every item in `decisions_needed`?"

---

## 4. State File

`.claude-workflow/tasks/development/YYYY-MM-DD-task-name/orchestrator-state.yml` is the source of truth for both routing and resume.

### 4.1 Timestamps

Each timestamp (`created`, `updated`, phase start/end, work-log entry dates) is a full ISO 8601 UTC date and time, e.g. `2026-06-11T14:32:07Z`.

- Take it from the system — `date -u +"%Y-%m-%dT%H:%M:%SZ"` — in the same turn in which you write it. You do not know the time from context.
- Never write date-only values or zero-filled `T00:00:00Z`. If no real time was captured, write `null`, never a guess.
- Task directory names keep their date-only `YYYY-MM-DD-` prefix; that is a name, not a timestamp.

### 4.2 Write rule

The file has to remain valid YAML; tooling reads it with a strict parser.

- Update it key by key, in place. Never append a second copy of a key that already exists. New keys belong inside their parent block, at the siblings' column.
- Prefer Read → change → Write of the whole file to appending fragments.
- Re-read after each write: every key once per level, consistent indentation, nothing nested under a scalar, intended values present.
- **A malformed file stops the workflow.** Report what is wrong (key, line, shape) and ask: "Repair the state file" (rewrite whole file, re-validate) or "Let me investigate" (pause). Never repair silently, never carry on with it.

### 4.3 Schema

```yaml
orchestrator:
  started_phase: phase-1
  completed_phases: []
  failed_phases: []
  auto_fix_attempts: {}            # phase-id → attempts
  options:
    sequential: false              # --sequential; read by the executor (one group at a time)
    spec_audit_enabled: true
    skip_test_suite: false         # true only when the executor's last work-log entry shows the full suite passed
    code_review_enabled: true      # Phase 10, default on; wf-code-reviewer: quality, simplicity, production readiness
    reality_check_enabled: null    # Phase 10 writes explicit true/false
  created: null                    # ISO 8601 UTC (§ 4.1)
  updated: null
  task_path: .claude-workflow/tasks/development/YYYY-MM-DD-task-name
  task_ids: {}                     # phase → TaskCreate ID; {} when the task tools are unavailable

task:
  title: null
  description: null
  status: pending                  # pending | in_progress | completed | failed | blocked
  tags: []
  priority: null                   # high | medium | low

project_context:
  project_doc_paths: []            # from .claude-workflow/docs/INDEX.md "Project Documentation"

task_context:                      # top level — never nested under orchestrator:
  risk_level: null
  clarifications_resolved: null
  scope_expanded: null
  tech_clarified: null
  architecture_decision: null
  tdd_red_passed: null
  tdd_green_passed: null
  task_characteristics:
    has_reproducible_defect: false
    modifies_existing_code: false
    creates_new_entities: false
    involves_data_operations: false
  phase_summaries:
    # every entry: summary, decisions [{decision, rationale}], risks [], artifacts [{path, label}]
    # phase-specific extras:
    codebase_analysis: {key_files: [], primary_language: null}
    clarifications: {}
    gap_analysis: {integration_points: []}
    scope_clarifications: {scope_expanded: null}
    specification: {}
    architecture_decision: {decision: null}
    implementation: {}

verification_context:
  last_status: null                # passed | passed_with_issues | failed
  issues_found: []
  fixes_applied: []
  decisions_made: []
  reverify_count: 0                # max 3
```

When the user chose to finalize without a phase, that skipped phase records `skip_reason` next to its entry.

---

## 5. Initialization & Resume

### New task

1. Parse the arguments: description, `--from`, `--sequential`, `--audit` / `--no-audit`.
2. Capture the clock with `date` (§ 4.1) — mandatory, before any timestamp gets written.
3. Create `.claude-workflow/tasks/development/YYYY-MM-DD-slug/` containing `analysis/`, `implementation/`, `verification/`. Slug: 3-5 key words in lowercase kebab-case (e.g. `2025-12-17-fix-login-timeout`).
4. Write `orchestrator-state.yml` (§ 4.3).
5. `TaskCreate` each active phase, then `TaskUpdate addBlockedBy` for the dependencies. If the task tools are unavailable, set `task_ids: {}` and rely on the state file as the sole tracker.
6. Announce the task, the directory and the starting phase.

### Resume (`/wf-dev <task-path> [--from=PHASE]`)

1. Read the state file and validate it (§ 4.2). Malformed → stop and ask.
2. Validate the artifacts of `completed_phases`; drop every phase whose artifacts are missing.
3. Resume point: `--from` when given, otherwise the first phase not in `completed_phases`.
4. Check prerequisites; when missing, ask "Start from Phase 1" / "Specify different phase" / "Exit".

   | Starting from | Requires |
   |---|---|
   | Phase 2 Gap analysis | `analysis/codebase-analysis.md` |
   | Phase 5 Specification | `analysis/gap-analysis.md` |
   | Phase 7 Planning | `implementation/spec.md` |
   | Phase 8 Implementation | spec.md + implementation-plan.md |
   | Phase 10/11 Verification | Phase 8 completed |

5. Restore task items: recreate every phase task, re-add the dependencies, mark the completed ones `completed` with `metadata: {restored: true}`, and store the new IDs.
6. Before doing any work, tell the user the current phase and the next gate, based on state and the Phase Configuration table. Never infer the workflow position from the plan or work-log — those are organized by task group, not by phase.

---

## 6. Issue Resolution & User-Confirmed Rollback

**Resolve, don't just report.** Once verification returns structured issues:

1. Trivial and clearly fixable (lint, formatting, missing imports, typos, one-line config) → candidates for "fix all fixable". Design trade-offs, architecture, test logic, unclear requirements → ask the user.
2. Any code change sets `skip_test_suite: false` ahead of re-verification.
3. Loop until verification passes, the user moves on with known issues, or 3 iterations are reached (then ask how to proceed). Track `reverify_count` and `fixes_applied`.
4. **Never proceed past unresolved critical issues without explicit user approval.**

**User-confirmed rollback** — never revert or roll back changes automatically. When something fails: stop, analyze the root cause (config? test setup? real logic error?), look for an easy fix, then ask: "Try suggested fix" / "Rollback changes" / "Let me investigate". Roll back only once explicitly confirmed. Destructive git commands (`stash`, `reset --hard`, `checkout .`, `clean`) are off-limits for the duration of the workflow.

---

## 7. Artifact Summary Contract

Each markdown artifact in the task directory starts (after the H1) with:

```markdown
## TL;DR
[3-5 lines: what this concludes / recommends / delivers]

## Key Decisions
- [decision] — [one-line rationale]

## Open Questions / Risks
- [question or risk]
```

- TL;DR is limited to 5 lines and states conclusions, not process.
- Leave out empty sections entirely — never write "None".
- The full detail follows unchanged; the block is a lens, not a replacement.
- Each artifact-writing delegation prompt carries this contract (§ 3).
- When a report gets rewritten after fixes, its TL;DR reflects the final state.
- Exempt: `orchestrator-state.yml` and the append-only `work-log.md`.

---

## 8. Finalization: Artifact Reconciliation

Before declaring the task complete, resolve each `phase_summaries.[phase].artifacts[].path` against the task root and confirm it exists.

- List every missing path in a **Missing artifacts** block of the workflow summary, along with the phase that declared it and the agent or skill that owed it. Leave the block out when nothing is missing.
- Reconciliation reports; it never repairs. Do not re-run phases, regenerate artifacts, or delete the state entry. It does not block completion.
- Why: an orchestrator can transcribe a subagent's answer in a way that makes the verdict read as if the artifact existed. This check exposes that substitution.
