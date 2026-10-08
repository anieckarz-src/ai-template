---
name: wf-dev
description: Single orchestrator covering every development task. ALWAYS execute when invoked — never skip for 'straightforward' tasks. Phases adapt to the task characteristics detected rather than to predetermined types. Use for any development work that modifies code.
user-invocable: true
---

# Development Orchestrator

One workflow for every development task — bug fixes, enhancements, and new features. Phases switch on according to context and analysis findings rather than predetermined task types.

## Initialization

**BEFORE executing any phase, you MUST complete these steps:**

### Step 1: Load Workflow Rules

**Read `references/workflow-rules.md` NOW with the Read tool.** It covers delegation (§ 1), phase gates (§ 2), context passing (§ 3), the state file (§ 4), init/resume (§ 5), issue resolution (§ 6), the artifact summary contract (§ 7) and artifact reconciliation (§ 8). Settle the gate policy (§ 2.1) now, a single time: `→ MANDATORY GATE` fires in every permission mode, regardless of any "continue without asking" reminder or earlier approval pattern.

### Step 2: Initialize Workflow

1. **Capture the clock**: run `date -u +"%Y-%m-%dT%H:%M:%SZ"` via Bash NOW — you do NOT know the time from context. Every timestamp written during this turn (`created`, `updated`) takes this value. Date-only or `T00:00:00Z` values are the documented failure mode (workflow-rules.md § 4.1). In later turns, re-run `date` before writing timestamps.
2. **Create Task Items**: Use `TaskCreate` for every phase (see Phase Configuration), then wire up dependencies with `TaskUpdate addBlockedBy`
3. **Create Task Directory**: `.claude-workflow/tasks/development/YYYY-MM-DD-task-name/`
4. **Initialize State**: Create `orchestrator-state.yml` as described in workflow-rules.md § 4.3
5. **Discover project documentation**: Read `.claude-workflow/docs/INDEX.md` (when it exists) and pull ALL file paths out of the "Project Documentation" section. That covers predefined docs (vision, roadmap, tech-stack, architecture) AND any project docs the user added (e.g., deployment.md, api-strategy.md). Store the full list as `project_context.project_doc_paths` in state.

**Output**:
```
🚀 Development Orchestrator Started

Task: [description]
Directory: [task-path]

Starting Phase 1: Codebase Analysis...
```

---

## Cross-Cutting Rules (apply to every phase)

Every rule in `references/workflow-rules.md` holds throughout. Specifically: each artifact-writing prompt includes the summary contract (§ 7), whose `decisions` / `risks` / `artifacts` get lifted into `phase_summaries` (§ 3); each state write happens in place and is re-validated, and a malformed state file halts the workflow (§ 4.2).

---

## When to Use

Use it for **all development tasks**: bug fixes, enhancements, new features, and any work that changes code.

That includes performance fixes and technology, framework or version migrations — rollback and compatibility checks are planned as part of the spec.

**Out of scope**: pure documentation or research questions that change no code — answer those directly, with no workflow.

---

## Phase Configuration

| Phase | content | activeForm | Activation |
|-------|---------|------------|------------|
| 1 | "Analyze codebase & clarify requirements" | "Analyzing codebase & clarifying" | Always |
| 2 | "Analyze gaps & clarify scope" | "Analyzing gaps & clarifying scope" | Always |
| 3 | "Write failing test (TDD Red)" | "Writing failing test" | When `has_reproducible_defect` |
| 4 | — (removed in backend variant) | — | Never (number kept so later phase numbers stay stable) |
| 5 | "Gather requirements & create specification" | "Gathering requirements & creating specification" | Always |
| 6 | "Audit specification" | "Auditing specification" | Always (conditional) |
| 7 | "Plan implementation" | "Planning implementation" | Always |
| 8 | "Execute implementation" | "Executing implementation" | Always |
| 9 | "Verify test passes (TDD Green)" | "Verifying test passes" | When Phase 3 was executed |
| 10 | "Prompt verification options" | "Prompting verification options" | Always |
| 11 | "Verify implementation & resolve issues" | "Verifying implementation" | Always |
| 12 | — (removed in backend variant) | — | Never |
| 13 | — (removed in backend variant) | — | Never |
| 14 | "Finalize workflow" | "Finalizing workflow" | Always |

---

## Workflow Phases

### Phase 1: Codebase Analysis & Clarifications

**Purpose**: Thorough codebase exploration, followed by clarification of scope/requirements
**Execute**:
1. Skill tool - `wf-codebase-analyzer`
2. Write the analysis results to state
3. Direct - use AskUserQuestion for at most 5 critical clarifying questions
4. Save the clarifications to `analysis/clarifications.md`
**Output**: `analysis/codebase-analysis.md`, `analysis/clarifications.md`
**State**: Update `task_context.risk_level`, `phase_summaries.codebase_analysis`, `task_context.clarifications_resolved`

→ **AUTO-CONTINUE** — Do NOT end turn, do NOT prompt user. Move straight on to Phase 2.

---

### Phase 2: Gap Analysis & Scope Clarification

**Purpose**: Compare the current and desired state, detect task characteristics, then settle scope/approach decisions
**Execute**:
1. Task tool - `wf-gap-analyzer` subagent
2. **Extract the structured data from the gap-analyzer result and store it**:
   a. Read `task_characteristics` from the gap-analyzer output — 4 fields: `has_reproducible_defect`, `modifies_existing_code`, `creates_new_entities`, `involves_data_operations`
   b. Write all 4 fields into `orchestrator-state.yml` under `task_context.task_characteristics`
   c. Read `risk_level` from the output and write it to `task_context.risk_level`
   d. Pull out a phase summary (1-2 sentences) and write it to `phase_summaries.gap_analysis`
   e. **SELF-CHECK**: "Did I read the 4 task_characteristics from the gap-analyzer output and write them to state? Let me re-read `orchestrator-state.yml` to confirm the values match the gap-analyzer output."

**⛔ DECISION GATE** (mandatory — do NOT skip):
- Parse `decisions_needed` out of the gap-analyzer output
- When `decisions_needed.critical` OR `decisions_needed.important` is non-empty:
  - MUST use `AskUserQuestion` — each decision is a separate single-select question with its own option set (never flattened into one question's option list). Critical decisions: one call apiece with full context. Important decisions: may be grouped as up to 4 separate questions in a single call (workflow-rules.md § 3)
- When both are empty: Record "No scope decisions needed" in state

**SELF-CHECK** before moving on: "Did the gap-analyzer return `decisions_needed` items? If so, did I invoke `AskUserQuestion`? If I skipped it, STOP and go back."

3. Save the scope clarifications to `analysis/scope-clarifications.md`

**Output**: `analysis/gap-analysis.md`, `analysis/scope-clarifications.md` (conditional)
**State**: Update `task_context.task_characteristics`, `task_context.scope_expanded`, `phase_summaries.gap_analysis`

**Context to pass**: Risk level, codebase summary, key files, clarifications, project_doc_paths (from state)

→ **MANDATORY GATE** — invoke `AskUserQuestion` now and wait for the answer (workflow-rules.md § 2).

The Phase 2 exit gate **always** invokes `AskUserQuestion`. What branches is *which questions get asked*, not whether to ask at all:
1. When `decisions_needed.critical` or `.important` is non-empty → present the DECISION GATE questions first (see the DECISION GATE block above)
2. Then **always** ask the executive-summary routing question (Phase 3 / 5 depending on `task_characteristics`) shown below

An empty `decisions_needed` skips only step 1. Step 2 is unconditional. No path through Phase 2 bypasses `AskUserQuestion`.

**ANTI-PATTERN — DO NOT DO THIS:**
- ❌ "The defect is trivial, skipping Phase 3..." — STOP. When `has_reproducible_defect` is true, Phase 3 runs. That assessment belongs to the gap-analyzer, not to you.

AskUserQuestion - Show an executive summary before asking. Read `analysis/gap-analysis.md` and pull out: detected task type, risk level, key characteristics enabled (TDD gates), scope decisions made (if any). Then read `task_context.task_characteristics` from `orchestrator-state.yml` and work out the next phase:
- When `has_reproducible_defect` is true → ask "Continue to Phase 3: TDD Red Gate?"
- Otherwise → ask "Continue to Phase 5: Technical Approach, Requirements & Specification?"

---

### Phase 3: TDD Red Gate (Conditional)

> **Phase entry self-check**: Find the exit-gate `AskUserQuestion` call from Phase 2 in this conversation. If you can't, STOP and fire that gate now — never cover up a missed gate by updating state (workflow-rules.md § 2.2).

**Purpose**: Write a failing test that reproduces the defect
**Execute**: Direct - write the test, confirm it FAILS
**Output**: `implementation/tdd-red-gate.md`, failing test file
**State**: Update `tdd_red_passed: true`

**Skip if**: `task_characteristics.has_reproducible_defect` is false (not set by gap-analyzer)

**Critical**: The test MUST fail before implementation (proving the defect exists)

→ **MANDATORY GATE** — invoke `AskUserQuestion` now and wait for the answer (workflow-rules.md § 2).

AskUserQuestion - "TDD red gate complete. Continue to Phase 5?"

---

### Phase 5: Technical Approach, Requirements & Specification

> **Phase entry self-check**: Find the exit-gate `AskUserQuestion` call from the preceding phase in this conversation. If you can't, STOP and fire that gate now — never cover up a missed gate by updating state (workflow-rules.md § 2.2).

**⛔ ROUTING GUARD**: Read `task_context.task_characteristics` from `orchestrator-state.yml`. When `has_reproducible_defect` is true and Phase 3 is NOT in `completed_phases` → STOP, run Phase 3 first.

**Purpose**: Settle technical decisions, collect specification requirements, then produce a comprehensive specification
**Execute**:

**Part A — Technical & Architecture Clarification (inline, conditional)**:
1. For a complex task with several approaches: Direct - use AskUserQuestion for 3-5 technical questions
2. When several valid architectural approaches exist: Present 2-3 of them via AskUserQuestion. The selected approach goes to specification-creator so the spec is written around the decided architecture.
3. Save to `analysis/technical-clarifications.md` (conditional)

**Skip technical clarification if**: Simple task, risk_level = low, no multiple approaches detected

**Part B — Requirements Gathering (inline)**:
3. Direct - use AskUserQuestion for the specification requirements:
   - Scale the question count to the description length:
     - Brief (<30 words): 6-8 questions
     - Standard (30-100 words): 4-6 questions
     - Detailed (>100 words): 2-3 focused questions
   - Phrase them as confirmable assumptions: "I assume X, is that correct?"
   - REQUIRED questions (always include):
     1. **Consumers & Contracts**: Which clients/services call this (API consumers, batch jobs, other services)? Which API/message/schema contracts change, and do they have to stay backward compatible (versioning, deprecation)?
     2. **Integration Points**: Which downstream systems, databases, queues, or external APIs are involved? What failure modes, timeouts, and idempotency needs are expected?
     3. **Existing Code Reuse**: Are there similar features, services, or backend patterns to reference?
4. Save the gathered requirements to `analysis/requirements.md` containing: initial description, Q&A from every round, similar features identified, consumers and contract changes, integration points, functional requirements summary, reusability opportunities, scope boundaries, technical considerations

**Part C — Specification Creation (subagent)**:

5. Task tool - `wf-specification-creator` subagent (always delegated, never written inline — workflow-rules.md § 1)

**Context to pass to subagent**: task_path, task_description, task_characteristics, requirements_path (analysis/requirements.md), project_context_paths (INDEX.md + project_doc_paths from state — all discovered project docs), risk_level, phase_summaries (codebase_analysis, gap_analysis, clarifications, scope_clarifications)

**Output**: `analysis/technical-clarifications.md` (conditional), `analysis/requirements.md`, `implementation/spec.md`
**State**: Update `task_context.tech_clarified`, `task_context.architecture_decision`, `phase_summaries.specification`

→ **MANDATORY GATE** — invoke `AskUserQuestion` now and wait for the answer (workflow-rules.md § 2).

AskUserQuestion - Show an executive summary before asking. Read `implementation/spec.md` and pull out: spec title, scope boundaries (what's in and what's out), number of key requirements, chosen architecture approach (if any), assumptions made. Present a brief overview, then "Continue to specification audit?"

---

### Phase 6: Specification Audit (Recommended)

> **Phase entry self-check**: Find the exit-gate `AskUserQuestion` call from Phase 5 in this conversation. If you can't, STOP and fire that gate now — never cover up a missed gate by updating state (workflow-rules.md § 2.2).

**Purpose**: Independent review of the specification ahead of implementation
**Execute**: Task tool - `wf-spec-auditor` subagent
**Output**: `verification/spec-audit.md`
**State**: Update `options.spec_audit_enabled`

**Recommended**: Always. Offer the spec audit as the recommended default. The user may skip it if they choose.

AskUserQuestion - "Run specification audit? (Recommended)" with "Yes, run audit (Recommended)" as first option

→ **MANDATORY GATE** — invoke `AskUserQuestion` now and wait for the answer (workflow-rules.md § 2).

AskUserQuestion - Show an executive summary before asking. Read `verification/spec-audit.md` and pull out: overall verdict (pass/pass-with-concerns/fail), issue counts per severity, the top 1-2 critical findings if there are any. Present a brief overview, then "Continue to implementation planning?"

---

### Phase 7: Implementation Planning

> **Phase entry self-check**: Find the exit-gate `AskUserQuestion` call from Phase 6 in this conversation. If you can't, STOP and fire that gate now — never cover up a missed gate by updating state (workflow-rules.md § 2.2).

**Purpose**: Split the specification into implementation steps

**Execute**: Task tool - `wf-implementation-planner` subagent (always delegated — workflow-rules.md § 1)
**Output**: `implementation/implementation-plan.md`
**State**: Update task groups and dependencies

**Context to pass to subagent**: task_path, task_description, task_characteristics, phase_summaries (specification, gap_analysis, codebase_analysis)

→ **MANDATORY GATE** — invoke `AskUserQuestion` now and wait for the answer (workflow-rules.md § 2).

AskUserQuestion - Show an executive summary before asking. Read `implementation/implementation-plan.md` and pull out: number of task groups, total implementation steps, key dependencies between groups, estimated complexity. Present a brief overview, then "Continue to implementation?"

---

### Phase 8: Implementation

> **Phase entry self-check**: Find the exit-gate `AskUserQuestion` call from Phase 7 in this conversation. If you can't, STOP and fire that gate now — never cover up a missed gate by updating state (workflow-rules.md § 2.2).

**Purpose**: Carry out the implementation plan

**Execute**: Skill tool - `wf-implementation-plan-executor` (always delegated; it owns wave dispatch, progress tracking and the work-log — workflow-rules.md § 1)
**Output**: Implemented code, `implementation/work-log.md`
**State**: Update implementation progress, extract phase_summaries.implementation

**⚠️ POST-IMPLEMENTATION CONTINUATION** — Once the skill finishes and hands control back:

When the executor returns, Phase 8 ends and nothing else does. The plan's final task group is a group within Phase 8 regardless of its name ("Finalization", "push readiness") — it is never Phase 14. Next comes the Phase 8 exit gate below, then Phase 9 or Phase 10.

1. Read `orchestrator-state.yml` to confirm you are the orchestrator
2. Update state: add Phase 8 to `completed_phases`
3. Evaluate the conditional: if `task_characteristics.has_reproducible_defect` AND Phase 3 in `completed_phases` → Phase 9, else → Phase 10

→ **MANDATORY GATE** — invoke `AskUserQuestion` now and wait for the answer (workflow-rules.md § 2).

AskUserQuestion - Show an executive summary before asking. Pull from `phase_summaries.implementation` and `implementation/work-log.md`: task groups completed, files changed, test results from incremental runs, any known issues or deferred items. Present a brief overview, then "Continue to verification?"

---

### Phase 9: TDD Green Gate (Conditional)

> **Phase entry self-check**: Find the exit-gate `AskUserQuestion` call from Phase 8 in this conversation. If you can't, STOP and fire that gate now — never cover up a missed gate by updating state (workflow-rules.md § 2.2).

**Purpose**: Confirm that the failing test now passes
**Execute**: Direct - run the test written in Phase 3
**Output**: `implementation/tdd-green-gate.md`
**State**: Update `tdd_green_passed: true`

**Skip if**: Phase 3 was not executed

**Critical**: The test MUST pass (proving the defect is fixed)

→ **MANDATORY GATE** — invoke `AskUserQuestion` now and wait for the answer (workflow-rules.md § 2).

AskUserQuestion - "TDD gate passed. Continue to Phase 10?"

---

### Phase 10: Verification Options Prompt

> **Phase entry self-check**: Find the exit-gate `AskUserQuestion` call from the preceding phase in this conversation. If you can't, STOP and fire that gate now — never cover up a missed gate by updating state (workflow-rules.md § 2.2).

**Purpose**: Decide which verification checks run, using a tiered decision matrix
**Execute**: Direct - show the plan, confirm/adjust via AskUserQuestion
**Output**: State updated with all verification options
**State**: Set `options.code_review_enabled`, `options.reality_check_enabled`, `options.skip_test_suite`
**Auto-set**: `skip_test_suite: true` only if the executor's final `work-log.md` entry records the full test suite as passed; otherwise `skip_test_suite: false`, so that verification runs it. Cleared before re-verification when fixes are applied.

**Step 1**: Show the verification plan:
```
Verification Plan:
  Obligatory (always run):
    ✓ Completeness check
    ✓ Test suite (skipped when it passed during implementation — re-enabled after fixes; otherwise runs)

  Recommended (adjustable):
    ✓ Code review — quality, security, simplicity (over-engineering) and production readiness
    ✓ Reality check — validates the work actually solves the problem
```

**Step 2** (single question): AskUserQuestion (multi-select) — "Which verifications to run?"
Options: "Code review (Recommended)" → `code_review_enabled` (runs the `wf-code-reviewer` subagent), "Reality check" → `reality_check_enabled`. Code review starts pre-selected (default on).

Store each answer in state as an explicit `true`/`false`.

→ **MANDATORY GATE** — invoke `AskUserQuestion` now and wait for the answer (workflow-rules.md § 2).

---

### Phase 11: Verification & Issue Resolution

> **Phase entry self-check**: Find the exit-gate `AskUserQuestion` call from Phase 10 in this conversation. If you can't, STOP and fire that gate now — never cover up a missed gate by updating state (workflow-rules.md § 2.2).

**Purpose**: Full implementation verification with fix-then-reverify cycles
**Output**: `verification/implementation-verification.md`, optional code-review/reality-check reports, updated `implementation/work-log.md`
**State**: Update verification results, `verification_context`

**Execute**:

**Step 1**: Invoke Skill tool - `wf-implementation-verifier`

**Step 2**: Show a detailed issue breakdown grouped by category and severity:
```
Verification Results:
  Critical ([N]):
    - [category]: [description] — [file:line] [fixable/manual]
    ...
  Warning ([N]):
    - [category]: [description] — [file:line] [fixable/manual]
    ...
  Info ([N]):
    - [description] (listed for awareness, not actionable)
```

**Step 3**: Gate on the verification status:
- `status: passed` → jump to Post-Verification Continuation
- `status: passed_with_issues` or `failed` → enter the user-driven fix loop (Step 4)

**Step 4**: User-driven fix loop (max 3 iterations):
1. List all critical + warning issues as a numbered list
2. AskUserQuestion — "Which issues should I fix?" with options:
   - "Fix all fixable issues" (convenience default)
   - "Let me choose specific issues" (user picks by number)
   - "Skip fixes, proceed as-is"
3. Fix the chosen issues, logging each to `verification_context.fixes_applied`
4. Once fixes are applied: set `skip_test_suite: false` (the code changed, so tests must re-run)
5. AskUserQuestion — "Re-run verification to check fixes?" with options:
   - "Yes, re-run verification" → re-invoke `wf-implementation-verifier` → return to Step 2
   - "No, proceed to next phase"
6. Update `verification_context.reverify_count`

**Exit conditions**:
- No critical issues left → proceed
- User explicitly picks "Skip fixes, proceed as-is" or "No, proceed to next phase" → proceed with the issues logged
- Max 3 iterations reached → AskUserQuestion: "Proceed with known issues?" / "Stop workflow"
- **MUST NOT proceed with unresolved critical issues unless user explicitly approves**

**⚠️ POST-VERIFICATION CONTINUATION** — Once issue resolution is done:
1. **Canonical report check**: `verification/implementation-verification.md` MUST reflect the FINAL post-fix verdict before this phase is left. If fixes were applied and the canonical report still shows the pre-fix state (whether re-checks ran through the full verifier skill or through individual subagents writing `*-reverify.md` side files), re-invoke `wf-implementation-verifier` (or have it redo its report-compilation phase) so the report gets rewritten with a "Fix & Re-Verification History" section. Leaving a stale pre-fix report is a phase-exit violation.
2. Read `orchestrator-state.yml` to confirm you are the orchestrator
3. Update state: add Phase 11 to `completed_phases`
4. Proceed to Phase 14

→ **MANDATORY GATE** — invoke `AskUserQuestion` now and wait for the answer (workflow-rules.md § 2).

AskUserQuestion - Show an executive summary: total issues found, issues fixed, issues remaining per severity. Then "Continue to Phase 14: Finalization?"

---

### Phase 14: Finalization

> **Phase entry self-check**: Find the exit-gate `AskUserQuestion` call from Phase 11 in this conversation. If you can't, STOP and fire that gate now — never cover up a missed gate by updating state (workflow-rules.md § 2.2).

**Purpose**: Wrap up the workflow and give next steps
**Execute**: Direct - create the summary, update state, guide the commit
**Output**: Workflow summary
**State**: Set `task.status: completed`

**Preconditions** — read `orchestrator-state.yml` before you finalize. Every phase listed in the Phase Configuration table has to be resolved:
- **Resolved** means the phase appears in `completed_phases`, or its activation condition is false in state: Phase 3 (no reproducible defect), Phase 6 (`spec_audit_enabled` false), Phase 9 (Phase 3 not run). The removed phase numbers in the table never activate and need no resolution. Phase 11 has no such condition — it must be completed.
- **Any unresolved phase blocks finalization.** Name it and use `AskUserQuestion` for each such phase: "Run Phase N now (Recommended)" goes back to that phase; "Finalize without it" records the choice plus the user's reason in `work-log.md`, the workflow summary, and the phase's `skip_reason` in state. Never silently finalize past an unresolved phase.

**Process**:
1. **Reconcile artifacts against disk** — check every `artifacts[]` entry in state against what actually exists, and name each missing path in the summary (workflow-rules.md § 8)
2. Create the workflow summary
3. Set the task status to "completed"
4. Supply a commit message template — following the repository's own commit-message rules (its agent instruction files or contributing guide). Those rules take precedence over generic tool defaults, such as default trailers.
5. Guide the next steps (code review, PR, deployment)

→ End of workflow

---

## State

The full `orchestrator-state.yml` schema (options, `task_context`, `phase_summaries`, `verification_context`): workflow-rules.md § 4.3.

---

## Task Structure

```
.claude-workflow/tasks/development/YYYY-MM-DD-task-name/
├── orchestrator-state.yml
├── analysis/
│   ├── codebase-analysis.md       # Phase 1
│   ├── clarifications.md          # Phase 1
│   ├── gap-analysis.md            # Phase 2
│   ├── scope-clarifications.md    # Phase 2 (conditional)
│   └── technical-clarifications.md # Phase 5 (conditional)
├── implementation/
│   ├── spec.md                    # Phase 5
│   ├── requirements.md            # Phase 5
│   ├── implementation-plan.md     # Phase 7
│   ├── work-log.md                # Phase 8
│   ├── tdd-red-gate.md            # Phase 3 (conditional)
│   └── tdd-green-gate.md          # Phase 9 (conditional)
├── verification/
│   ├── spec-audit.md              # Phase 6 (recommended)
│   └── implementation-verification.md  # Phase 11
```

---

## Auto-Recovery

| Phase | Max Attempts | Strategy |
|-------|--------------|----------|
| 1 | 2 | Widen search, prompt user |
| 2 | 2 | Re-analyze, ask user |
| 3 | 2 | Rewrite test, skip TDD with doc |
| 5 | 2 | Regenerate spec |
| 7 | 2 | Regenerate plan |
| 8 | 5 | Fix syntax, imports, tests |
| 9 | 3 | Return to implementation |
| 11 | 3 | Fix tests, re-run |

---

## Command Flags

| Flag | Effect |
|------|--------|
| `--from=PHASE` | Begin at a specific phase |
| `--audit` / `--no-audit` | Force/skip specification audit |
| `--sequential` | Turn off parallel wave dispatch in the executor; run task groups one at a time. Persisted as `orchestrator.options.sequential: true` in `orchestrator-state.yml` and read by `implementation-plan-executor` Phase 2. Off by default (parallel waves). |

---

## Command Integration

Invoked through:
- `/wf-dev [description] [--audit|--no-audit] [--sequential]` (new)
- `/wf-dev [task-path] [--from=PHASE] [--reset-attempts]` (resume — workflow-rules.md § 5)

---

## TDD Gate Rules

**Phase 3 (Red Gate)**: Test MUST FAIL before implementation (activated when the gap-analyzer detects a reproducible defect)
**Phase 9 (Green Gate)**: Test MUST PASS after implementation (activated when Phase 3 was executed)
