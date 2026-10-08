---
name: wf-codebase-analyzer
description: Analyzes a codebase with adaptive parallel Explore subagents sized to task complexity. Picks agent roles from a pool, launches the Explore agents, and then hands report generation to the codebase-analysis-reporter subagent.
user-invocable: false
---

# Codebase Analyzer Skill

Coordinates a parallel analysis of the codebase using the built-in Explore subagents. Depending on task complexity, it adaptively picks which agent roles to activate, and then hands synthesis of the report to a specialized subagent.

## Core Principles

1. **Adaptive Agent Selection**: Pick roles from a pool according to task complexity — there is no fixed count
2. **Task-Type Awareness**: Tailor prompts and focus to the task type
3. **Delegated Reporting**: Raw findings are sent to the `codebase-analysis-reporter` subagent for synthesis

---

## Input Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `task_description` | Yes | Description of the development task |
| `description` | Yes | Task description provided by the user |
| `task_path` | Yes | Path to the task directory |
| `artifact_name` | No | Overrides the output filename (default: `codebase-analysis.md`) |

---

## Execution Workflow

### Step 1: Parse Input and Determine Focus

From the description, pull out keywords, component names, file hints, the domain, and any technology hints.

Work out the primary focus based on the task description:

| Signal in Description | Primary Focus | Key Questions |
|----------------------|---------------|---------------|
| Error/crash/broken language | Find buggy code path | Where does the issue happen? What is the execution flow? |
| Improve/enhance/existing | Find existing feature | Which files implement this feature? How does it work? |
| Add/new/create | Find patterns/integration points | Which similar patterns already exist? Where should this plug in? |

### Step 2: Select Agent Roles

Pick the roles to activate from the pool. Every role covers a separate analysis concern.

| Role | Purpose | When Needed |
|------|---------|-------------|
| **File Discovery** | Locate relevant files via patterns, keywords, naming | Almost always |
| **Code Analysis** | Analyze code structure, patterns, execution flow | When it matters to understand existing behavior |
| **Context Discovery** | Locate tests, consumers, dependencies | When it matters to understand impact/coverage |
| **Pattern Mining** | Locate similar implementations to use as templates | New features that follow existing patterns |

**Decision signals:**
- **Specificity** (exact files named → fewer agents)
- **Scope breadth** (several domains → more agents)
- **Uncertainty** (location unclear → more agents)
- **Task type** (bugs are usually focused, features broad, migrations broadest)

**Examples:**

| Task Description | Roles Selected | Count |
|------------------|---------------|-------|
| "Fix null check in `utils/parser.ts`" | File Discovery + Code Analysis (combined) | 1 |
| "Add sorting to the users list endpoint" | File Discovery, Code Analysis | 2 |
| "Fix login timeout" | File Discovery + Code Analysis (combined), Context Discovery | 2 |
| "Add OAuth authentication system" | File Discovery, Code Analysis, Context Discovery | 3 |
| "Add export feature similar to import" | File Discovery, Code Analysis, Pattern Mining | 3 |
| "Migrate from REST to GraphQL" | File Discovery, Code Analysis, Context Discovery, Pattern Mining | 4 |

If you select fewer agents, fold related concerns into one prompt — do not drop any concern.

Say which roles you picked and why (1 sentence).

### Step 3: Read Prompt Templates and Launch Agents

Before launching, read the template file for every selected role — the templates contain the task-type-specific focus lists and the no-write constraint, both of which get lost when prompts are written from memory.

**3a. Read templates** — With the Read tool, load ONLY the files for the roles you selected:

| Role | Read This File |
|------|--------------|
| File Discovery | `references/file-discovery.md` |
| Code Analysis | `references/code-analysis.md` |
| Context Discovery | `references/context-discovery.md` |
| Pattern Mining | `references/pattern-mining.md` |

When combining roles into a single agent, read `references/combined.md` as well for guidance on merging.

**3b. Adapt templates** — Substitute the actual task description for `[description]`. Pick the right task-type section (Bug / Enhancement / Feature).

**3c. Launch agents** — Call the Task tool with `subagent_type="Explore"` — one call for each selected role, all within ONE message.

**IMPORTANT**: Every Explore agent prompt MUST contain this instruction:
> IMPORTANT: Do NOT create, write, or modify any files. Output all findings as text in your response only.

### Step 4: Delegate Report Generation

Once every Explore agent has finished, delegate to the `codebase-analysis-reporter` subagent through the Task tool:

```
Task tool:
  subagent_type: "wf-codebase-analysis-reporter"
  description: "Merge findings into analysis report"
  prompt: |
    You are the codebase-analysis-reporter. Merge these raw findings into a structured analysis report.

    Task description: [description]
    Agent roles used: [list of roles]
    Agent count: [N]
    Output path: [task_path]/analysis/[artifact_name]

    ## Raw Findings

    ### [Role 1 Name]
    [paste raw output from agent 1]

    ### [Role 2 Name]
    [paste raw output from agent 2]

    [... for each agent]
```

The subagent writes the final report to `{task_path}/analysis/{artifact_name}` and returns structured results.

### Step 5: Return Results to Orchestrator

Forward the subagent's structured output unchanged:

```yaml
status: success|partial|failed
report_path: analysis/[artifact_name]
summary: "[1-2 sentence summary]"
files_found: [count]
complexity: simple|moderate|complex
risk_level: low|low-medium|medium|medium-high|high
```

---

## Error Handling

- **No files found**: Report the partial results and suggest that the user give more specific hints
- **Agent timeout**: Rely on results from the agents that finished, and note that the analysis is incomplete
- **Conflicting results**: Hand every perspective to the reporter subagent, which calls out the conflicts

---

## Integration

| Orchestrator | Phase | artifact_name |
|-------------|-------|---------------|
| development orchestrator | Phase 1 | `codebase-analysis.md` (default) |
