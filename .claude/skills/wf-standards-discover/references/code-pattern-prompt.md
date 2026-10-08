# Code Pattern Analyzer — Subagent Prompt Template

Examine the project's source code patterns to discover the coding conventions and standards it uses.

## Task

Sample code files, detect patterns that are consistent in naming/imports/structure, and return the findings as YAML.

## Sampling Strategy

For performance, sample instead of analyzing exhaustively:

- **Backend files**: Sample at most 50 files (`*.py`, `*.rb`, `*.java`, `*.go`, `*.rs`, `*.ts`, `*.js`)
- **Test files**: Sample at most 30 files (`*.test.*`, `*.spec.*`, `*_test.*`)

Find files with Glob, then Read a representative sample drawn from different directories.

## Patterns to Detect

1. **File Naming**: PascalCase, kebab-case, snake_case, camelCase — compute the consistency %
2. **Import Patterns**: Absolute vs relative, path aliases (`@/`), grouping/sorting of imports
3. **Error Handling**: try/catch usage, custom error classes, error wrapping, logging patterns
4. **API Patterns** (backend): Endpoint naming, resource naming (plural/singular), versioning
5. **Function Style**: Arrow functions vs declarations, async/await vs promises
6. **Type Patterns**: TypeScript strictness, type vs interface usage, generics patterns

## Consistency Threshold

Report only patterns that reach **>= 60% consistency** across the sampled files.

Calculate: `(files following pattern / total files sampled) * 100`

## Categorization

Discover the existing categories from `.claude-workflow/docs/standards/*/`. Baseline categories: `global/`, `backend/`, `testing/`. If patterns do not fit the existing ones, propose new categories.

## Confidence Range

Code pattern findings: **60-88%** confidence. Higher when consistency reaches >= 90%.

## Output Format

Return YAML:

```yaml
findings:
  - category: "[category/subcategory]"
    standard_name: "[Short Name]"
    description: "[What the convention is]"
    confidence: [60-88]
    evidence:
      - "[X] of [Y] files follow this pattern"
      - "Examples: [file1], [file2], [file3]"
    source: "code-patterns"
    examples:
      - "[Correct pattern example]"
```

## Rules

- Sample files at random across directories so the results are representative
- Include file counts in the evidence (e.g., "247 of 250 .ts files use kebab-case")
- Report only patterns with >= 60% consistency
- If no clear patterns emerge, return an empty findings list
- Concentrate on actionable, consistent patterns — not one-off occurrences
- Do NOT write any other files to the project directory. Write your YAML results only to: `[output_file]` (the orchestrator replaces this placeholder with the working file path under `.claude-workflow/tmp/standards-discover-<timestamp>/` when invoking you).
