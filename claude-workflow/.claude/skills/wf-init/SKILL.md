---
name: wf-init
description: Set up the Claude Workflow framework by intelligently analyzing the project and generating its documentation
argument-hint: "[--standards-from=PATH]"
---

# Initialize Claude Workflow Framework

Set up `.claude-workflow/docs/` through intelligent project analysis, generating meaningful documentation grounded in an actual inspection of the codebase.

**NOTE**: At specific phases this skill calls other skills and subagents. For every docs-manager operation, use the **Task tool with `docs-operator` subagent** (subagent_type: `wf-docs-operator`); for project-analyzer, use the **Task tool** (subagent_type: `wf-project-analyzer`). Reserve the **Skill tool** for standards-discover only (Phase 8, the last phase). Once finished, the Task tool hands control back to this skill; the Skill tool does not.

## Phase Configuration

| Phase | Subject | activeForm |
|-------|---------|------------|
| 1 | Pre-flight checks | Running pre-flight checks |
| 2 | Analyze project codebase | Analyzing project codebase |
| 3 | Present findings & gather context | Gathering project context |
| 4 | Select standards to initialize | Selecting standards |
| 5 | Initialize documentation structure | Initializing documentation |
| 6 | Generate project documentation | Generating project documentation |
| 7 | Validate | Validating initialization |
| 8 | Discover coding standards | Discovering coding standards |

**Task Tracking**: Prior to Phase 1, call `TaskCreate` for every phase (pending), then chain them sequentially with `TaskUpdate addBlockedBy`. For each phase: `TaskUpdate` to `in_progress` → execute → `TaskUpdate` to `completed`. When phases are skipped (e.g., the user picks "Update existing"), mark them `completed` with `metadata: {skipped: true}`.

---

## PHASE 1: Pre-flight Checks

**If `--standards-from=PATH` is provided:**
1. Resolve the path (either absolute or relative to the current working directory)
2. Verify that `PATH/.claude-workflow/docs/standards/` exists. If it does not, tell the user and stop — Claude Workflow standards have not been initialized in the specified project.
3. Keep the resolved standards source path for later use in Phases 4 and 5.

Determine whether the `.claude-workflow/` directory is already present.

**If exists**, use AskUserQuestion:
- Options: "Backup and reinitialize", "Update existing documentation", "Cancel"
- If "Backup": Using the Bash tool, create `.claude-workflow.backup-$(date +%Y%m%d-%H%M%S)/`
- If "Update": Jump to PHASE 6 (generate documentation only)
- If "Cancel": Halt execution

---

## PHASE 2: Project Analysis

Call the `project-analyzer` subagent through the Task tool (subagent_type: `wf-project-analyzer`).

Wait until it finishes. Keep the analysis results for use in Phases 3 and 6.

---

## PHASE 3: Present Findings & Gather Context

**Step 1**: Show the user the analysis results (project type, primary language/framework, architecture, tech stack, conventions, strengths/opportunities).

**Step 2**: Confirm the accuracy of the analysis with AskUserQuestion. Collect any corrections that are needed.

**Step 3**: Collect additional context through AskUserQuestion (tailored to the project type):
1. Project name (when not obvious)
2. Project description (1-2 sentences)
3. Primary goals (tailor the question to a new/existing/legacy project)
4. Team context (optional)
5. Special requirements (optional)

**Step 4**: With AskUserQuestion (multi-select), ask which project documentation should be generated:
- "Vision" — Purpose, goals, and vision of the project
- "Roadmap" — Planned features and development roadmap
- "Tech Stack" — Technology choices along with their rationale (ALWAYS selected, required)
- "Architecture" — Design patterns and system architecture (optional)

Smart defaults depending on `projectArchitectureType`:
- Standard/Backend-only: Everything selected
- Monorepo/Umbrella: Only "Tech Stack" selected

Keep the selections for Phase 6.

---

## PHASE 4: Select Standards to Initialize

Before showing the options, explain to the user:
- **What standards are**: Coding standards are documented conventions and best practices (naming, error handling, testing patterns, etc.) that steer consistent development throughout the project.
- **Starting point**: When `--standards-from` was provided, standards are taken from the referenced project. Otherwise, the generic built-in standards shipped with the plugin are used. In both cases they act as a starting point that can later be fully customized or extended.

**Determine available categories:**
- **If `--standards-from` was provided**: Scan `PATH/.claude-workflow/docs/standards/*/` to find every category available in the external project (this may include custom categories beyond the baseline global/backend/testing).
- **Otherwise**: Fall back to the built-in baseline categories (global, backend, testing).

Compute smart defaults from the analysis:
- **Global**: Recommended in every case (if available)
- **Backend**: When a backend framework is detected or projectArchitectureType includes backend (if available)
- **Testing**: Recommended in every case (if available)

Additionally scan `.claude-workflow/docs/standards/*/` for existing custom categories to include.

Present a summary of the smart defaults (stating the source: external project or built-in), then use AskUserQuestion:
- "Use smart defaults" → continue with the computed defaults
- "Customize selection" → present a multi-select of all discovered categories plus an "Add custom category" option

Custom categories: when the user adds a new category, create its directory and add it to the selection.

Keep the selection for Phase 5.

---

## PHASE 5: Initialize Documentation Structure

**Invoke `docs-operator` subagent** through the Task tool (subagent_type: `wf-docs-operator`) with prompt:

> "Initialize documentation structure. Standards selection: [array from Phase 4]. [If --standards-from was provided: Standards source path: [resolved path]/.claude-workflow/docs/standards/. Copy standards from this external path instead of built-in defaults.] Only copy selected standard categories. Do NOT copy project templates — only create the project/ directory. Project documentation will be generated in Phase 6 with real content from project analysis. Create placeholder sections in INDEX.md for skipped categories."

Once docs-operator completes, move straight on to Phase 6.

---

## PHASE 6: Generate Project Documentation

**IMPORTANT**: Generate only the docs selected in Phase 3.

For every selected doc type, read the matching reference template:
- Vision selected → Read `references/vision-templates.md`, picking the template for the project type (new/existing/legacy)
- Roadmap selected → Read `references/roadmap-templates.md`, picking the template for the project type
- Tech Stack (always) → Read `references/tech-stack-template.md`
- Architecture selected → Read `references/architecture-template.md`

Populate the templates with:
- Data from the analysis report (tech stack, age, structure)
- Context the user supplied in Phase 3 (goals, users, requirements)
- Project characteristics detected automatically

Write every file into `.claude-workflow/docs/project/`.

---

## PHASE 7: Validate

**Step 1**: Call the `docs-operator` subagent through the Task tool (subagent_type: `wf-docs-operator`) with prompt:

> "Regenerate INDEX.md to include all newly created project documentation. Then verify CLAUDE.md is properly integrated with .claude-workflow/docs/ documentation."

Once docs-operator completes, continue right away with Step 2.

**Step 2**: Show a comprehensive summary, including any failures that docs-operator reported.
- Results of the project analysis (type, language, framework, architecture)
- Structure created (a tree with check marks next to created items)
- Documentation status (which docs were generated, which standards were initialized)
- Key findings (strengths, opportunities)
- Next steps:
  1. Review the generated documentation
  2. Customize it for your team
  3. Begin development with `/wf-dev "task description"`
  4. Keep the documentation up to date

---

## PHASE 8: Discover Coding Standards

Through the Skill tool, invoke the `wf-standards-discover` skill with `--scope=full` so coding standards are discovered automatically from the project's config files, source code patterns, documentation, and external sources.

> "Run standards discovery with --scope=full. This is being invoked as part of project initialization."

User interaction is handled by the standards-discover skill itself (it presents findings by confidence tier and asks for approval). Allow it to run its complete workflow — since this is the final phase of init, handing off context here is fine.

When it completes, show a short summary of how many standards were discovered and applied.

---

## Error Handling Principles

- When creating `.claude-workflow/docs/` fails: check permissions and suggest creating it manually
- When project-analyzer fails: offer to continue using manual input only
- When docs-manager fails: offer a retry (max 2 attempts), then give manual instructions
- Never roll back automatically — always ask the user before any destructive action
