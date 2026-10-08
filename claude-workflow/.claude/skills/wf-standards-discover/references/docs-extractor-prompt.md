# Documentation Standards Extractor — Subagent Prompt Template

Pull out the coding standards and conventions that the project's files document explicitly.

## Task

Locate and parse documentation files, extract the standards they state explicitly, and return the findings as YAML.

## Documentation Files to Analyze

1. **README.md** — Check for Code Style, Contributing Guidelines, Conventions, and Best Practices sections
2. **CONTRIBUTING.md** — PR requirements, commit conventions, testing requirements, code review standards
3. **ARCHITECTURE.md** / `docs/architecture/` — Design patterns, architectural decisions
4. **ADRs** (Architecture Decision Records) — `adr/`, `decisions/`, `docs/decisions/` directories
5. **CLAUDE.md** / `.claude/CLAUDE.md` — AI-specific coding instructions and project conventions
6. **Code of Conduct**, **STYLEGUIDE.md** — When present

## What to Extract

Search for explicit statements of a standard:
- "We use..." / "This project uses..."
- "Always..." / "Never..."
- "Prefer X over Y"
- "Required: ..." / "Must..."
- Code examples that show correct/incorrect patterns
- Numbered lists of rules or guidelines

**Extract only standards that are stated explicitly** — do not infer them from code examples alone.

## Categorization

Discover the existing categories from `.claude-workflow/docs/standards/*/`. Baseline categories: `global/`, `backend/`, `testing/`. If patterns do not fit the existing ones, propose new categories.

## Confidence Range

Documentation findings: **80-92%** confidence (explicitly documented = strong evidence).

Use the higher end (90+) when several docs agree or when the standard is stated as a mandatory rule.

## Output Format

Return YAML:

```yaml
findings:
  - category: "[category/subcategory]"
    standard_name: "[Short Name]"
    description: "[What the standard requires]"
    confidence: [80-92]
    evidence:
      - "[filename]: \"[exact quote or paraphrase]\""
    source: "documentation"
    examples:
      - "[Example from docs if provided]"
```

## Rules

- Put exact quotes or close paraphrases in the evidence
- Record which file each standard comes from
- If no documentation files are found, return an empty findings list
- Favor clear, actionable standards over vague guidance
- Do not repeat what config files already enforce — concentrate on human-written guidelines
- Do NOT write any other files to the project directory. Write your YAML results only to: `[output_file]` (the orchestrator replaces this placeholder with the working file path under `.claude-workflow/tmp/standards-discover-<timestamp>/` when invoking you).
