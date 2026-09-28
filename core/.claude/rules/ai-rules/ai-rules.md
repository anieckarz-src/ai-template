---
paths: .claude/**
description: Guidelines for creating and updating AI rules, skills, and agents
---

# AI Rules

Guidelines for creating, updating, and reviewing AI configuration files (rules, skills, agents). The `.claude/` directory is the source of truth. If the project mirrors these files to other AI editors, edit `.claude/` and regenerate the mirrors - never edit the mirrored copies directly.

## Directory Structure

- `.claude/rules/` - Coding standards and patterns in subfolders (e.g., backend, frontend, infrastructure). Loaded automatically for matching `paths:`
- `.claude/skills/<name>/SKILL.md` - Skills (slash-command workflows). One folder per skill; supporting material goes in `references/`, `scripts/`, or `assets/` inside that folder
- `.claude/agents/` - Subagent definitions (one `.md` file per agent)
- `.claude/scripts/` and `.claude/hooks/` - Shell scripts and hooks used by skills and agents
- `CLAUDE.md` - Project contract: project commands (`[BUILD]`, `[TEST]`, `[FORMAT]`, `[LINT]`, `[RESTART_ENV]`, `[SMOKE]`, `[E2E]`, `[BASE_BRANCH]`), work tracking, team roster, git rules

## Frontmatter Formats

### Rules Frontmatter

```yaml
---
paths: **/Commands/*.cs,**/Queries/*.cs
description: Clear, one-line description of what the rule enforces
---
```

- `paths:` - File patterns for conditional loading. Be specific (e.g., `**/Commands/*.cs` not `**/*.cs`)
- `description:` - Keep it standalone

### Skills Frontmatter

```yaml
---
name: skill-name
description: Standalone description of what this skill does and when to use it (trigger phrases)
allowed-tools: Read, Write, Edit, Bash
---
```

- `name:` - Must match the folder name (lowercase, hyphenated)
- `description:` - Must be standalone. It is what the model sees when deciding whether to invoke the skill, so state both what it does and when to trigger it
- `allowed-tools:` - Optional. Restricts or pre-approves the tools the skill may use
- `argument-hint:` - Optional. Shown to the user as the expected arguments

## Writing Rules

1. Use the standard document structure:
   - Start with a level 1 heading (`# Title`) matching the filename (without extension)
   - Begin with a brief overview paragraph describing the rule's purpose
   - Include a level 2 heading `## Implementation` with numbered steps
   - Include a level 2 heading `## Examples` with practical examples

2. Follow formatting conventions:
   - Use Title Case for level 2 headings (e.g., `## Implementation`, `## Examples`)
   - Number implementation steps for easy reference
   - Use bulleted lists for related items within a step

3. Write implementation steps clearly:
   - Begin each step with a directive verb (Use, Follow, Create, Implement)
   - Be specific about requirements and conventions
   - Cover both the "what" and the "how" in your instructions

4. Include code examples:
   - Use language-specific code blocks with proper syntax highlighting
   - Show both good and bad examples for clarity
   - Use comments with `// ✅` and `// ❌` prefixes (optionally with `DO:` and `DON'T:`)
   - Provide multiple examples for complex rules, using `### Example 1` and `### Example 2`

5. Reference related files:
   - Use `[filename](/path/to/file)` syntax to link to other files
   - Reference actual implementation examples from the codebase whenever possible

## Writing Skills

1. Use the standard document structure:
   - Start with `# Title Workflow` or `# Title` heading
   - Use step-by-step structure for complex workflows (STEP 1, STEP 2, etc.)

2. Follow formatting conventions:
   - Use Title Case for level 2 headings
   - Keep `SKILL.md` focused; move long reference material into `references/` and link to it

3. Stay project-agnostic:
   - Use the `CLAUDE.md` placeholders (`[BUILD]`, `[TEST]`, `[FORMAT]`, `[LINT]`, `[RESTART_ENV]`, `[SMOKE]`, `[E2E]`, `[BASE_BRANCH]`) instead of hardcoded commands. An empty placeholder means "skip that step"
   - Mark optional integrations (MCP servers, external tools) as "if available"

4. Reference other rules/skills with links when needed

## Work Tracking Terminology

Skills and agents that refer to planned work must use the tool-agnostic terminology defined in the `## Work Tracking` section of `CLAUDE.md`:

**✅ Use this terminology** (brackets, case, and pluralization consistently):
- `[feature]` / `[features]` / `[Feature]` / `[Features]` - A change folder `context/changes/<change-id>/` (`change.md` + `plan.md`)
- `[task]` / `[tasks]` / `[Task]` / `[Tasks]` - One `## Phase N` of that `plan.md`
- `[subtask]` / `[subtasks]` / `[Subtask]` / `[Subtasks]` - A step row in `## Progress` (see `.claude/skills/10x-plan/references/progress-format.md`)

**❌ Avoid these terms** (tool-specific):
- Issue, Epic, Story, User Story, Work Item, Ticket, Bug (as work item types)

Deviations go to `context/changes/<change-id>/divergence.md`, durable reviews to `context/changes/<change-id>/reviews/`, and scratch files to `.workspace/<branch-name>/`.

## Review Checklist

When reviewing changes to rules, skills, or agents:

- [ ] Frontmatter format is correct for file type (rules vs skills vs agents)
- [ ] Skill `name:` matches its folder name
- [ ] Description is standalone and meaningful
- [ ] Level 2 headings use Title Case
- [ ] Examples use ✅/❌ patterns where applicable
- [ ] File organization matches its category
- [ ] Project commands use `CLAUDE.md` placeholders, not hardcoded tools
- [ ] Tool-agnostic terminology used (no Issue, Epic, Story, etc.)

## Examples

### Example 1 - Rule File

```markdown
---
paths: application/*/Core/*/Commands/*.cs
description: Guidelines for implementing CQRS command handlers
---

# Commands

Command handlers implement write operations following CQRS patterns.

## Implementation

1. Create command record in the feature's Commands folder
2. Implement handler using MediatR IRequestHandler
3. Use FluentValidation for input validation

## Examples

### Example 1 - Command Records

` ` `csharp
// ✅ DO: Use records for commands
public sealed record CreateUserCommand(string Email, string Name) : IRequest<Result<UserId>>;

// ❌ DON'T: Use classes for commands
public class CreateUserCommand : IRequest<Result<UserId>>
{
    public string Email { get; set; }
    public string Name { get; set; }
}
` ` `
```

### Example 2 - Skill File

`.claude/skills/implement-task/SKILL.md`:

```markdown
---
name: implement-task
description: Implement one [task] (a plan.md phase) from a [feature]. Use when the user asks to implement a specific phase.
argument-hint: "<change-id> <phase-number>"
---

# Implement Task Workflow

## STEP 1: Read Task Assignment

Read `context/changes/<change-id>/plan.md` and locate the requested `## Phase N` and its `## Progress` rows.

## STEP 2: Research Patterns

Find similar implementations in the codebase.

## STEP 3: Implement

Follow the relevant rules for your implementation area.

## STEP 4: Validate

Run `[BUILD]`, then `[FORMAT]`, `[LINT]`, and `[TEST]`. Skip any that are empty in `CLAUDE.md`.
```
