# CLAUDE.md Documentation Section Template

Insert this section into the project's `CLAUDE.md` file, placing it prominently near the top. Before adding it, confirm that the INDEX.md path is correct and that the file exists.

```markdown
## Project Documentation & Standards

Before you write or change any code — even for quick, direct requests that skip the `/wf-*` workflows — ground yourself in the project's documentation:

1. Read @.claude-workflow/docs/INDEX.md to learn what is documented. It maps everything the team maintains — coding standards by domain, project vision/tech-stack/architecture, and any other project knowledge (business domain, glossaries, decisions, etc.).
2. Next, open and read the specific files it points to that matter for your task — standards AND any project/domain docs. Reading the index alone is not enough.
3. Follow the standards while you work (they capture team decisions; if one conflicts with the task, ask the user) and use the project docs for context.

### Standards Evolution

If during implementation you spot recurring patterns, fixes, or conventions that the standards don't capture yet — suggest adding them. For example:
- A bug fix exposes a pattern worth standardizing (e.g., "always validate X before Y")
- PR review feedback points to a convention the team wants enforced
- The same kind of fix is needed in multiple files
- A newly adopted library/pattern ought to be documented

When that happens, briefly propose the standard to the user. If they approve, invoke `/wf-standards-update` with the identified pattern.

## Claude Workflow

This project relies on the Claude Workflow kit (vendored in .claude/) for structured development workflows.
```
