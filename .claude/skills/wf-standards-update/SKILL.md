---
name: wf-standards-update
description: Create or update project standards based on conversation context or an explicit description
argument-hint: "[description of standard/convention] [--from=PATH]"
---

# Update Project Standards

Creates or updates standards in `.claude-workflow/docs/standards/` from the conversation context or from a description you provide. The best-matching category and file are detected automatically. Both baseline categories (global, backend, testing) and custom categories defined by the user are supported.

## Usage

```bash
/wf-standards-update                                    # Detect from conversation
/wf-standards-update "always paginate list endpoints"   # From description
/wf-standards-update --from=/path/to/other-project      # Sync from another project
```

---

## Mode: Sync from External Project (`--from=PATH`)

If `--from=PATH` is given, the skill switches into **sync mode** — it imports standards from the `.claude-workflow/docs/standards/` of another project into the current one. Phases 1-3 are skipped and a dedicated flow is used instead.

### SYNC STEP 1: Validate Source

1. Resolve the path (either absolute or relative to cwd)
2. Verify that `PATH/.claude-workflow/docs/standards/` exists. If it does not, tell the user and stop.
3. Verify that `.claude-workflow/docs/standards/` exists in the current project. If it does not, offer to run `/wf-init` first.

### SYNC STEP 2: Analyze Differences

1. Scan the source project's `standards/*/` — list every category and file
2. Scan the current project's `standards/*/` — list every category and file
3. Compare each source file with its local counterpart:
   - **Missing locally**: The category or file is absent from the current project
   - **Differs**: Both exist, but their content is different (read and compare)
   - **Identical**: Nothing to do
4. Show the user a summary through AskUserQuestion (multi-select):
   - Group by status: "New standards to add" and "Standards that differ"
   - Every item displays `[category]/[file]` with a short description of its contents
   - Options: the individual files to sync, plus the convenience options "Select all new" / "Select all different"
   - The user picks which standards to import

### SYNC STEP 3: Apply Selected Standards

For every selected standard:
- **Missing locally**: Copy the file over from the source. Create the category directory if required.
- **Differs**: Show a short diff summary and use AskUserQuestion for each file:
  - "Replace with source version" — overwrite the local file
  - "Merge (append new sections)" — read both files and append the `###` sections from the source that are not present locally
  - "Skip" — keep the local file as is

### SYNC STEP 4: Update INDEX.md

Invoke the `docs-operator` subagent through the Task tool (subagent_type: `wf-docs-operator`):
> "Regenerate INDEX.md to include all newly added/updated standards. Verify CLAUDE.md integration."

Wait until docs-operator finishes, then go straight on to SYNC STEP 5.

### SYNC STEP 5: Summarize

Show the standards added, updated and skipped, along with the total count. Recommend reviewing the imported standards and committing them.

---

## Mode: Conversation / Description (default)

If `--from` is NOT given, the skill follows the standard detect-and-update flow described below.

---

## PHASE 1: Detect Standard

**Step 1: Gather input**
- **If argument provided**: Treat the description as the primary input. Additionally scan the last 15-20 messages for extra context, examples, or related conventions.
- **If no argument**: Scan the last 15-20 messages for discussions about conventions. Watch for phrases like "we should always...", "our convention is...", "prefer X over Y", "never use...", and code examples that show patterns.

**Step 2: Discover existing categories and files**

Scan `.claude-workflow/docs/standards/*/` to locate every existing category and standard file. This tells you what is available — it is not restricted to the baseline categories.

**Step 3: Match to category and file**

From the detected topic, propose the existing category and file that match best. Take into account:
- File names and what they contain (read the existing files when the topic is close)
- Whether the convention belongs in an existing file or calls for a new one

**Step 4: Present suggestion**

- **If confident match** → AskUserQuestion: "This convention about [topic] fits [category/file]. Update it?" (Yes / Choose different / Cancel)
- **If ambiguous** → AskUserQuestion that lists the possible categories/files + "Create new category" + "Create new file in [category]"
- **If nothing detected** (no argument and no conversation context) → ask the user to describe the convention they would like to document

---

## PHASE 2: Determine Action

Check whether the target file exists:
- **Exists** → update mode
- **Doesn't exist** → create mode (for a new category, create its directory as well)

No user prompt is required — simply inform: "Updating existing standard: [name]" or "Creating new standard: [category/name]"

---

## PHASE 3: Gather Standard Content

### If updating

1. Read the current content
2. Present a summary of the existing practices
3. Ask what should be added/changed
4. Extract: new practices, modifications, removals, code examples

### If creating

1. Tell the user the target path
2. Ask for practices, conventions, code examples, and do's/don'ts
3. Optionally show the plugin baseline when a similar standard exists in the bundled docs of docs-manager

---

## PHASE 4: Apply via docs-manager

> Every standard uses a `###` heading followed by a 1-10 line description (code snippets not counted). A topic file holds multiple standards. Break large topics into sub-topic files.

**Invoke the `docs-operator` subagent** through the Task tool (subagent_type: `wf-docs-operator`) with this context:

For **updates**:
> "Update documentation file: standards/[category]/[name].md. Current content: [content]. Add/change: [new conventions]. Integrate new practices, maintain markdown formatting, organize logically, preserve existing unless conflicts. Update INDEX.md entry with practice-specific description (enumerate actual practices, not generic category)."

For **creates**:
> "Create documentation file: standards/[category]/[name].md. Category: [category]. Content: [conventions]. Create with proper markdown, organized sections, code examples. Add to INDEX.md with practice-specific description. Verify CLAUDE.md integration."

Wait until docs-operator finishes, then go straight on to Phase 5.

---

## PHASE 5: Summarize

Show a summary: what was created/updated, which practices were added, and the next steps (review, commit, share with the team). If docs-operator reported a failure, mention it.

---

## Prerequisites

If `.claude-workflow/docs/` does not exist, offer to run `/wf-init` first.
