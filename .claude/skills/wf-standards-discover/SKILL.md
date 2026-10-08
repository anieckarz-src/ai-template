---
name: wf-standards-discover
description: Discovers coding standards from a project's configuration files, code patterns, documentation, and external sources (PRs, CI/CD)
---

# Standards Discovery Skill

Examines several project sources in parallel to uncover coding standards, conventions, and best practices. Findings are aggregated with confidence scoring, shown to the user for approval, and the approved standards are applied through the `docs-manager` skill.

## Core Principles

1. **Parallel Execution**: Run discovery subagents concurrently for speed (~45-60s instead of ~2-4min sequentially)
2. **Evidence-Based**: Each finding must cite concrete files, line counts, or config rules as its evidence
3. **Confidence Scoring**: Confidence is multi-factor, based on source count, consistency, and explicitness
4. **Deduplication**: When the same standard turns up in several sources, it is merged into one finding with the combined evidence
5. **Graceful Degradation**: Sources that are unavailable (no gh CLI, no docs) are skipped without failing the whole workflow

---

## Input Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--scope` | `full` | Discovery scope: `full`, `quick`, or any category name (baseline: `global`, `backend`, `testing`; custom categories are supported too) |
| `--confidence` | `60` | Minimum confidence threshold (0-100) for findings to be displayed |
| `--auto-apply` | `false` | Apply standards with confidence >= 90% automatically, without asking |
| `--skip-external` | `false` | Skip the GitHub PR analysis and CI/CD sources |
| `--pr-count` | `20` | How many recent merged PRs to analyze |

**Which phases run depends on the scope:**

| Scope | Config (P1) | Code (P2) | Docs (P3) | External (P4) |
|-------|-------------|-----------|-----------|----------------|
| `full` | Yes | Yes | Yes | Yes |
| `global` | Yes | Yes (limited) | Yes | Yes |
| `backend` | BE configs | BE files | Yes | Yes |
| `testing` | Test configs | Test files | Yes | Yes |
| `quick` | Yes | No | No | No |
| `[custom]` | Relevant configs | Filtered files | Yes | Yes |

Custom scope values are matched against the existing `.claude-workflow/docs/standards/*/` directories, and the analysis is filtered down to the relevant files.

---

## Phase Configuration

| Phase | Subject | activeForm |
|-------|---------|------------|
| 1 | Plan discovery scope | Planning discovery scope |
| 2 | Analyze configuration files | Analyzing configuration files |
| 3 | Mine code patterns | Mining code patterns |
| 4 | Extract documentation standards | Extracting documentation standards |
| 5 | Analyze external sources | Analyzing external sources |
| 6 | Aggregate & deduplicate findings | Aggregating findings |
| 7 | Review findings with user | Reviewing findings |
| 8 | Apply approved standards | Applying standards |
| 9 | Generate summary report | Generating summary |

**Task Tracking**: When Phase 1 starts, use `TaskCreate` for every phase above (pending). Set dependencies: Phases 2-5 are blocked by Phase 1 (they run in parallel once planning is done). Phase 6 is blocked by Phases 2-5. Phases 7-9 run sequentially. When each phase starts: `TaskUpdate` to `in_progress`. When each phase ends: `TaskUpdate` to `completed`. Phases skipped because of scope (e.g., Phases 3-4 with `--scope=quick`) are marked `completed` with `metadata: {skipped: true, reason: "scope=quick"}`.

---

## Execution Workflow

### Phase 1: Planning & Initialization

1. **Parse options** from the command arguments
2. **Check prerequisites**: Confirm that `.claude-workflow/docs/` exists. If it does not, offer to run `/wf-init` first
3. **Read existing standards** from `.claude-workflow/docs/INDEX.md` to tell updates apart from creates and to avoid duplicates
4. **Display discovery plan** with the scope, the sources, and the estimated time
5. **Get user confirmation** through AskUserQuestion before continuing

---

### Phase 2-5: Parallel Discovery

Launch every applicable subagent in a single message so that they run in parallel.

**Step 1: Determine which phases to run** from the scope and flags.

**Step 1.5: Create working output directory** — Create a unique working directory inside the project (not in the system temp dir — on Windows, Git Bash's `/tmp` cannot be seen by the Read/Write tools): run `mkdir -p .claude-workflow/tmp/standards-discover-<timestamp>` via Bash (e.g., take the timestamp from `date +%Y%m%d-%H%M%S`). Keep the path (e.g., `.claude-workflow/tmp/standards-discover-20260101-120000`) as `{tmpdir}`. Every subagent writes its results to its own file in this directory: `{tmpdir}/config.yml`, `{tmpdir}/code.yml`, `{tmpdir}/docs.yml`, `{tmpdir}/external.yml`.

**Step 2: Read prompt templates**

For each phase you will run, read its template — the templates define the YAML output schema that the aggregation step relies on:

| Phase | Condition | Read This File |
|-------|-----------|----------------|
| 2: Config Analysis | Always | `references/config-analyzer-prompt.md` |
| 3: Code Patterns | scope != `quick` | `references/code-pattern-prompt.md` |
| 4: Documentation | scope != `quick` | `references/docs-extractor-prompt.md` |
| 5: External Sources | `--skip-external` not set | `references/external-analyzer-prompt.md` |

**Step 3: Adapt templates** — Substitute actual values for `[scope]`, `[confidence]`, and the other placeholders. In each template, replace the `[output_file]` placeholder with the real working file path for that phase (e.g., `{tmpdir}/config.yml`).

**Step 4: Launch subagents in parallel** — For each phase, use the Task tool with `subagent_type: general-purpose`.

**Step 5: Wait** until ALL subagents have finished, then use the Read tool on each temp file to gather the findings.

**Step 6: Display progress** — Show how many findings each phase produced.

---

### Phase 6: Aggregation & Deduplication

**Read** `references/aggregation-strategy.md` for the confidence scoring methodology.

1. **Combine** every finding from Phases 2-5
2. **Deduplicate** by grouping on `category + standard_name` — merging their evidence and sources
3. **Calculate final confidence** with the multi-factor scoring described in the reference
4. **Detect conflicts** — flag standards that contradict each other (e.g., ESLint says semicolons, Prettier says no)
5. **Categorize** as High (>= 80%), Medium (60-79%), Low (< 60%)
6. **Filter** using the `--confidence` threshold

Show an aggregation summary: total raw findings, unique standards, and conflicts detected.

---

### Phase 7: User Review & Approval

**Step 1: Present full summary table** — Before any approval prompt, output ALL findings in a table grouped by confidence level. Each group gets a header with its count:

```
### High Confidence (>=80%) — 5 standards

| # | Standard | Category | Score | Sources | Description |
|---|----------|----------|-------|---------|-------------|
| 1 | no-semicolons | global | 92 | config, code, docs | Omit semicolons in all JS/TS files |
| 2 | ... | ... | ... | ... | ... |

### Medium Confidence (60-79%) — 3 standards
...

### Low Confidence (<60%) — 2 standards
...

### Conflicts — 1 detected
| # | Standard | Conflict | Sources A | Sources B |
```

For each finding, the **Sources** column lists every source that contributed to it (config, code, docs, PRs, CI, pre-commit). This gives users complete visibility before they decide.

**Step 2: Approval flow** — Once the summary table is shown:

- **High confidence (>= 80%)**: Use AskUserQuestion to offer either batch approval ("Apply all N high-confidence standards") or an individual drill-down review. In the drill-down, show the full detail of each finding: all evidence items with source attribution, examples (preferred/avoid), and the confidence score breakdown (how many points each factor contributed).

- **Medium confidence (60-79%)**: Present each one individually with full detail (evidence, examples, confidence breakdown). For each finding, use AskUserQuestion with Accept/Modify/Skip options.

- **Low confidence (< threshold)**: Only show the rows of the summary table. Offer to expand the details or to skip them all.

- **Conflicts**: Present every conflict with both sides, their evidence, and their sources. Resolve with AskUserQuestion (pick side A, pick side B, skip, or custom).

When `--auto-apply` is set, findings with confidence >= 90% are approved automatically and only the remaining ones are prompted.

---

### Phase 8: Application

Standard files are written through the docs-operator subagent instead of Write/Edit, so that INDEX.md and CLAUDE.md remain consistent with the files.

1. **Prepare content** for each approved standard — standard name, description, examples (preferred/avoid), rationale drawn from the evidence, and source citations. Format each one as a `###` heading followed by a 1-10 line description (code snippets excluded); group related standards into a single topic file; include brief code examples only where they help clarify. Record whether each target file is a create or an update.
2. **Invoke the `docs-operator` subagent once** through the Task tool (subagent_type: `wf-docs-operator`) with all of the prepared standards, telling it to apply each create/update (merging updates into the existing content), then regenerate INDEX.md and confirm that CLAUDE.md references the standards directory.

Show an application summary: created count, updated count, total active.

---

### Phase 9: Summary Report

Show the final results:
- Sources analyzed (config files, code files sampled, docs parsed, PRs reviewed)
- Standards applied (created/updated counts per category)
- Standards skipped (low confidence, declined by user)
- Next steps (review, commit, re-run schedule)

**Cleanup**: Using Bash, delete the working directory `{tmpdir}` that was created in Step 1.5 (e.g., `rm -r .claude-workflow/tmp/standards-discover-<timestamp>`), and also remove `.claude-workflow/tmp/` if it is empty afterwards. Clean up as well if the workflow is aborted after Step 1.5.

---

## Error Handling

| Situation | Strategy |
|-----------|----------|
| `.claude-workflow/docs/` missing | Offer `/wf-init`, abort if the user declines |
| gh CLI unavailable | Skip the PR analysis, continue with the other sources |
| GitHub API rate limit | Skip the PR analysis, mention it in the report |
| Config file parse error | Skip that file, log a warning, continue |
| No standards found | Suggest a lower threshold or checking a specific scope |
| docs-manager fails | Offer retry/skip/cancel for each standard |
| Subagent returns empty | Mention it in the report, proceed with the findings available |

---

## Integration

| Integrates With | How |
|-----------------|-----|
| `docs-manager` skill | Creates/updates the standard files, regenerates INDEX.md |
| `implementation-plan-executor` skill | Standards that were discovered are immediately available via INDEX.md |
| `standards-update` command | Complementary: discover = automated bulk, update = manual single |

---

## Examples

```bash
# Full discovery (default)
/wf-standards-discover

# Quick scan (config files only, ~30-60s)
/wf-standards-discover --scope=quick

# Backend standards only
/wf-standards-discover --scope=backend

# High confidence, auto-apply
/wf-standards-discover --confidence=80 --auto-apply

# Skip external analysis (offline/no GitHub)
/wf-standards-discover --skip-external
```
