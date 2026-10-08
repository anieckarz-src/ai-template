# Pattern Mining — Prompt Template

Intended mainly for features, but also usable for enhancements. Substitute the actual task description for `[description]`.

```
IMPORTANT: Do NOT create, write, or modify any files. Output all findings as text in your response only.

Find similar implementations and reusable patterns for: "[description]"

Focus on:
1. Find the most similar existing feature/module in the codebase
2. Identify reusable abstractions, base classes, or utilities that can be extended
3. Document the conventions these similar implementations follow (file structure, naming, patterns)
4. Note any generators, templates, or scaffolding tools available
5. Identify shared middleware, mixins, or helper functions that should be reused

Output:
- Best template/example to replicate (with file paths)
- Reusable abstractions and utilities (with file paths)
- Convention checklist to follow
- Anti-patterns observed in existing similar features (what NOT to copy)
```
