# INDEX.md Template

Follow this structure when generating or updating `.claude-workflow/docs/INDEX.md`. Populate the sections dynamically by scanning the actual `.claude-workflow/docs/` directory — do not hardcode file lists.

For technical standards, the description MUST list the specific practices/conventions the file documents, not merely give a generic category description.

```markdown
# Documentation Index

**IMPORTANT**: Read this file at the start of any development task to learn which documentation and standards are available.

## Quick Reference

### Project Documentation
Project-level documentation that covers vision, goals, architecture, and technology choices.

### Technical Standards
Coding standards, conventions, and best practices grouped by domain.

---

## Project Documentation

Located in `.claude-workflow/docs/project/`

### Vision (`project/vision.md`)
[Brief description of what this file contains]

### Roadmap (`project/roadmap.md`)
[Brief description of what this file contains]

### Tech Stack (`project/tech-stack.md`)
[Brief description of what this file contains]

### Architecture (`project/architecture.md`)
[Brief description of what this file contains - if exists]

---

## Technical Standards

### [Category Name] Standards

Located in `.claude-workflow/docs/standards/[category]/`

#### [Standard Name] (`standards/[category]/[name].md`)
[Practice-specific description — enumerate actual conventions, not generic text]

[... repeat for all categories and standards discovered in the directory ...]

---

## How to Use This Documentation

1. **Start Here**: Always read this INDEX.md first to see which documentation exists
2. **Project Context**: Read the relevant project documentation before you start working
3. **Standards**: This index only points at the standards — open and follow the particular standard files that apply to your task; don't depend on the index alone
4. **Keep Updated**: Update the documentation whenever you make significant changes
5. **Customize**: Tailor all documentation to the specific needs of your project

## Updating Documentation

- Update project documentation whenever goals, tech stack, or architecture change
- Update technical standards as team conventions evolve
- Always update INDEX.md when documentation is added, removed, or significantly changed
```
