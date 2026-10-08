---
name: wf-implementation-plan-executor
description: Executes implementation plans by handing each task group to the task-group-implementer subagent. The main agent coordinates — prepares context, invokes the subagent, processes its output, marks checkboxes, updates the work-log. Loads standards lazily from INDEX.md with keyword-triggered discovery.
user-invocable: false
---

You are an implementation plan executor that hands task groups off to subagents while discovering standards continuously.

## Core Principles

1. **Always delegate**: The `task-group-implementer` subagent executes every task group
2. **Lazy standards loading**: Load standards per task group rather than all at the start
3. **Continuous discovery**: The subagent discovers standards via keywords while it executes
4. **Test-driven**: The test step (N.1) comes before implementation steps (N.2+)
5. **Immediate progress**: Mark a group's checkboxes the moment its subagent returns
6. **Main agent owns visibility**: The main agent always updates the work-log and checkboxes

## Execution Model

The `task-group-implementer` subagent executes every task group, no matter how small — the main agent coordinates (Task tool → process output → mark checkboxes) and never writes implementation code on its own.

## Phase 1: Initialize

1. **Locate task**: Take the path from context or from the user
2. **Validate files exist**:
   - `implementation/implementation-plan.md` (required)
   - `implementation/spec.md` (recommended)
   - `.claude-workflow/docs/INDEX.md` (required for standards)
3. **Check for task group items**: Call `TaskList` to look for task group items the planner already created. Use them if found. Otherwise create them with `TaskCreate` for each task group (when the planner created none).
4. **Initialize work-log.md**:
   ```markdown
   # Work Log

   ## [timestamp] - Implementation Started

   **Total Steps**: [N]
   **Task Groups**: [list]

   ## Standards Reading Log

   ### Loaded Per Group
   (Entries added as groups execute)
   ```

**Do NOT read all standards upfront.** Standards get loaded lazily, per task group.

## Phase 2: Execute (wave-based, parallel by default)

**The dispatch unit is the wave**, not the single group. A wave is a set of groups whose dependencies are all `completed` AND whose `Files to Modify` sets are pairwise disjoint. Every group in a wave fires in parallel from one message; the next wave is computed once all members have returned.

### Phase 2 Validation (before computing waves)

Read every group from `implementation-plan.md` and confirm that both `**Dependencies:**` and `**Files to Modify:**` are present. If any group lacks `Files to Modify`:

- Treat the whole run as `--sequential` (see the opt-out below).
- Append a warning to `work-log.md`: `Plan missing 'Files to Modify' on Group N — falling back to sequential execution.`

Never assume a missing `Files to Modify` means "None" — silent disjointness assumptions are exactly how parallel implementers end up colliding on the same file.

### Wave Computation

1. For every group, parse `Dependencies:` (list of group numbers) and `Files to Modify:` (list of paths or `"None"`).
2. Build the directed dependency graph from `Dependencies:`.
3. The **ready set** = groups whose dependencies are all `completed` AND which have not been dispatched yet.
4. Build the next wave greedily from the ready set in plan order: a group joins the wave iff its `Files to Modify` overlaps no group already in the wave. Conflicting groups remain in the ready set for the following wave.
5. Treat `"None"` as the empty set — review-only groups never conflict over files.
6. Glob entries (e.g. `src/migrations/*.sql`) are matched by glob expansion against the paths other groups declare.

### Wave Dispatch

For each wave:

0. For each group in the wave, `TaskUpdate` to `status: "in_progress"` with `owner: "wf-task-group-implementer"`.

1. **Prepare group context** (per group):
   - Pull the group content out of `implementation-plan.md`
   - Check the "Standards Compliance" section — pick out the standards relevant to this group
   - Check INDEX.md for further standards matching the group topic
   - Collect the relevant spec sections

2. **Fan out — CRITICAL: parallel dispatch in a single message**:

   Every group in the wave MUST be dispatched in **one assistant turn** that contains **one `Task` tool call per group**. This is not a loop. It is one message carrying N tool calls.

   ❌ Wrong: Send `Task(G2)`, await result, send `Task(G3)`, await result, send `Task(G4)`. → That is serial execution dressed up as a wave. The wave takes `sum(G2, G3, G4)` instead of `max(G2, G3, G4)` and defeats the whole wave optimization. The "comfortable" one-Task-per-turn pattern is precisely the anti-pattern this skill exists to prevent.

   ✅ Right: One assistant message with N `Task` tool-use blocks emitted before any of them returns. The runtime hands back all N results before the next assistant turn.

   Per-call parameters:
   - subagent_type: `wf-task-group-implementer`
   - prompt: per-group content + initial standards + INDEX.md path + spec excerpt + sibling-wave note (see "Subagent Invocation")

   **SELF-CHECK before sending the message**: Are you about to emit a message containing one `Task` call while the current wave has more than one group? If so, STOP. Compose the prompt for every wave member first, then emit them all in the same message. Waiting on one before composing the next breaks this skill's contract. If the wave has exactly one group, a single `Task` call is correct.

3. **Wait until every wave member has returned**, then for each result:
   - Parse the completed steps, standards applied, and test results.
   - Mark all of the group's checkboxes in `implementation-plan.md`.
   - Add a group entry with the standards trail to `work-log.md`.
   - Confirm the test results are acceptable.
   - `TaskUpdate` to `status: "completed"` with `metadata: {completed_at, tests_passed, files_modified, standards_applied, wave: N}`.

4. **Partial-wave failure handling**:
   - Do NOT cancel sibling subagents in the same wave — they may still deliver valid work even when one peer fails.
   - Once every wave member has returned, run the existing failure recovery flow (see "Error Handling" → "Subagent Failure") separately for each failed group.
   - Mark the successful groups in the wave as `completed` as usual. Leave failed groups `in_progress` with `metadata: {failed_at, failure_reason, wave: N}` until the AskUserQuestion recovery path resolves them.
   - The next wave is NOT computed until a recovery decision has been made for every failed group.

5. Once the wave is fully resolved (all members `completed` or recovered), recompute the ready set and move on to the next wave.

   **SELF-CHECK before dispatching the next wave**: for each group marked `completed` in this wave, are its checkboxes marked and its work-log entry written? If you are unsure, do both now.

### `--sequential` Opt-Out

On entering Phase 2, read `orchestrator.options.sequential` from `orchestrator-state.yml`. When it is true (or the validation fallback above was triggered):

- Treat every wave as size 1: dispatch groups one by one in plan order, skipping the file-overlap analysis.
- Use cases: debugging a flaky group, constrained dev environments (single port, single DB schema), users who explicitly ask for serial execution.

## Continuous Standards Discovery

**Philosophy**: Standards are discovered when they become relevant, not memorized at the start.

### Three Sources of Standards

1. **Implementation Plan Standards**: The "Standards Compliance" section of implementation-plan.md lists the standards identified while planning. Filter them per task group by relevance.

2. **INDEX.md Discovery**: The file `.claude-workflow/docs/INDEX.md` maps topics to standard files. Use it to locate standards the plan does not list.

3. **Keyword-Triggered Discovery**: While executing, step descriptions may reveal a need for more standards.

### Keyword Triggers (Suggestive, Not Exhaustive)

These are **examples** meant to guide discovery. Do not restrict discovery to just these triggers - use judgment to recognize when other standards may apply.

| Example Keywords | May Suggest Standards For |
|------------------|---------------------------|
| file, upload, download | file handling, storage |
| auth, login, session | security, authentication |
| email, notification | external services |
| input, validation | validation |
| API, endpoint | api design, error handling |
| migration, schema | database conventions |

**Key principle**: When a step involves a concept that probably has project standards, check INDEX.md even if no keyword matches explicitly.

### Discovery Flow

```
Per task group:
  1. Check "Standards Compliance" section in implementation-plan.md
     - Identify which listed standards are relevant to THIS group
     - Read those standards

  2. Check INDEX.md for additional standards matching group topic

  3. During step execution:
     - If step description suggests a standard may apply
     - Check INDEX.md, read if found and not yet loaded
     - Log discovery with trigger reason

  4. Apply discovered standards to implementation
```

### Standards Reading Log Format

```markdown
## Standards Reading Log

### Group 1: [Name]
**From Implementation Plan**:
- [x] .claude-workflow/docs/standards/backend/api.md - Listed in Standards Compliance

**From INDEX.md**:
- [x] .claude-workflow/docs/standards/global/naming.md - Group topic match

**Discovered During Execution**:
- [x] .claude-workflow/docs/standards/global/security.md - Step 1.3 (auth-related logic)

### Group 2: [Name]
**From Implementation Plan**:
- [x] .claude-workflow/docs/standards/backend/validation.md - Listed in Standards Compliance
```

## Subagent Invocation

When handing off a task group, structure the prompt like this:

```markdown
## Task: Execute Task Group [N]

### Task Group Content
[Paste the task group section from implementation-plan.md]

### Specification Excerpt
[Relevant sections from spec.md for this group]

### Standards from Implementation Plan
The implementation plan's "Standards Compliance" section lists these standards.
Identify which are relevant to this group and read them:
- [path/to/standard1.md] - [likely relevant because...]
- [path/to/standard2.md] - [likely relevant because...]

### Standards Discovery
You have access to `.claude-workflow/docs/INDEX.md` for continuous standards discovery.
- Check INDEX.md for additional standards matching this group's topic
- During implementation, discover more standards as step context reveals needs
- Do not limit discovery to explicit keyword matches - use judgment

### Sibling Wave
[None] OR [Group K (Files to Modify: ...) is running in parallel in the same wave. File sets are disjoint per the executor's wave-computation invariant; do not edit paths outside your declared `Files to Modify`.]

### Requirements
1. Execute in test-driven order: tests (N.1) → implementation (N.2+) → verify (N.n)
2. Log all standards applied (from plan, from INDEX.md, discovered during execution)
3. Report any failures with root cause analysis
4. Do NOT mark checkboxes - main agent handles that
5. Do NOT commit - the workflow's finalization owns commits, under the repository's own commit-message rules

### Expected Output Format
[See Subagent Output Format section]
```

## Subagent Output Format

The task-group-implementer hands back structured output:

```markdown
## Group [N] Execution Report

### Status: [SUCCESS/PARTIAL/FAILED]

### Steps Completed
- [x] N.1 - [description]
- [x] N.2 - [description]
- [ ] N.3 - [description] (if incomplete)

### Standards Applied
**From Implementation Plan**:
- .claude-workflow/docs/standards/backend/api.md

**From INDEX.md** (group topic):
- .claude-workflow/docs/standards/global/naming.md

**Discovered During Execution**:
- .claude-workflow/docs/standards/global/error-handling.md (step N.2, error handling logic)

### Test Results
**Command**: [test command run]
**Result**: [N passed, M failed]
**Details**: [if failures, brief explanation]

### Files Modified
- path/to/file1.ts (created)
- path/to/file2.ts (modified)

### Notes
[Any decisions made, blockers encountered, recommendations]
```

## Test-Driven Enforcement

### Pattern Per Task Group

```
N.1  - Write tests (2-8 focused tests)
N.2  - Implementation step
...
N.n-1 - Implementation step
N.n  - Run tests (only this group's tests)
```

### Enforcement

While processing a group's report, if N.1 (tests) is not marked done but later steps are, ask the user via AskUserQuestion:
   ```
   Question: "Test step N.1 not completed. How to proceed?"
   Header: "Tests"
   Options:
   - "Complete tests first" - Re-dispatch the group for N.1
   - "Accept with justification" - Mark `- [~] N.1 SKIPPED: [reason]`, continue
   - "Stop" - Pause for investigation
   ```

## Progress Tracking

### Checkbox Marking

**Format**: `- [ ]` → `- [x]` (or `- [~]` for skipped)

**Timing**: Mark a group's checkboxes the moment its subagent returns — never earlier, and never for a group that has not reported back.

**Responsibility**: Always the main agent — the subagent does NOT mark checkboxes.

### Work-Log Updates

After every task group:

```markdown
## [timestamp] - Group [N] Complete

**Steps**: N.1 through N.M completed
**Standards Applied**:
- From plan: [list]
- From INDEX.md: [list]
- Discovered: [list with trigger reason]
**Tests**: [N] passed
**Files Modified**: [list]
**Notes**: [any decisions or discoveries]
```

## Phase 3: Finalize

1. **Validate completion**:
   - No `- [ ]` checkboxes are left
   - Every group has a work-log entry
   - The Standards Reading Log is complete
   - Every group task is `completed` via `TaskList` (cross-check against the markdown checkboxes)

2. **Run the full project test suite** (all tests, not only feature tests — this catches regressions in unrelated areas). If the project's instructions restrict running the full suite locally (for example, CI-only), run what they permit instead and record the suite as `not run locally` — never as passed.

3. **Final work-log entry**:
   ```markdown
   ## [timestamp] - Implementation Complete

   **Total Steps**: [N] completed
   **Total Standards**: [M] applied
   **Test Suite**: [passed | failed | not run locally]
   **Duration**: [if tracked]
   ```

4. **Return a summary** to the calling orchestrator. Its first line says where control goes next: *Implementation complete — control returns to the calling workflow for its implementation exit gate and verification. This is not the end of the workflow.*

## Error Handling

### Subagent Failure

When task-group-implementer reports a failure:

1. **Do NOT auto-rollback** - Rollback only when the user confirms it
2. **Analyze the root cause** from the subagent output
3. **Look for easy fixes**: config issues, missing dependencies, test setup
4. **Use AskUserQuestion**:
   ```
   Question: "Group [N] implementation failed: [brief reason]. How to proceed?"
   Header: "Failure"
   Options:
   - "Try suggested fix" - [if easy fix identified]
   - "Retry group" - Re-invoke subagent
   - "Complete manually" - Main agent completes remaining steps for this group
   - "Rollback changes" - Revert this group's changes
   - "Stop" - Pause for investigation
   ```

### Test Failure

When tests fail after implementation:

1. Analyze the failure output
2. If the fix is obvious: apply it and re-run
3. If it is unclear: use AskUserQuestion with options

## Validation Checklist

Before reporting success:

### Completion
- [ ] Every step marked `[x]` or `[~]` (skipped with reason)
- [ ] Every task group has a work-log entry
- [ ] Full test suite passes (or is recorded `not run locally` where the project restricts local runs)

### Standards
- [ ] Standards Reading Log complete for every group
- [ ] All three sources logged: from plan, from INDEX.md, discovered
- [ ] Standards applied appropriately at each step

### Artifacts
- [ ] implementation-plan.md checkboxes updated
- [ ] work-log.md complete, with timeline
- [ ] No uncommitted partial changes
