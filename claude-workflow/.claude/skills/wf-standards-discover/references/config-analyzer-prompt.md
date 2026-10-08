# Config Standards Analyzer — Subagent Prompt Template

Examine the project's configuration files to discover its coding standards and conventions.

## Task

Locate and analyze configuration files, extract the standards they imply, and return structured findings as YAML.

## Configuration Files to Analyze

1. **Linter configs**: `.eslintrc.*`, `.prettierrc*`, `pylintrc`, `.pylintrc`, `.rubocop.yml`, `biome.json`
2. **Compiler configs**: `tsconfig.json`, `jsconfig.json`
3. **Package managers**: `package.json` (scripts, conventions), `requirements.txt`, `Gemfile`, `pom.xml`, `go.mod`
4. **Editor configs**: `.editorconfig` (indentation, line endings, charset)
5. **Container configs**: `Dockerfile`, `docker-compose.yml`

## What to Extract

From every config file you find, pull out the rules/settings that point to coding standards:

- **ESLint**: Naming conventions, code style (quotes, semicolons, indentation), framework patterns, import rules
- **Prettier**: Formatting rules (semi, singleQuote, trailingComma, tabWidth, printWidth)
- **TypeScript**: Compiler strictness (strict, noImplicitAny), module resolution, path aliases
- **Package.json**: Script patterns, testing conventions, pre-commit hooks (husky/lint-staged)
- **EditorConfig**: Indentation style/size, charset, line endings, trailing whitespace
- **Biome**: Combined lint + format rules

## Categorization

Discover the existing categories from `.claude-workflow/docs/standards/*/`. Baseline categories:
- `global/` — Language-agnostic (indentation, line endings, general error handling)
- `backend/` — Server-specific (API rules, database conventions)
- `testing/` — Test-related (test frameworks, coverage requirements)

If findings do not fit the existing ones, propose new categories.

## Confidence Range

Config-based findings: **70-85%** confidence (explicit configuration = strong evidence).

## Output Format

Return YAML:

```yaml
findings:
  - category: "[category/subcategory]"
    standard_name: "[Short Name]"
    description: "[What the standard requires]"
    confidence: [70-85]
    evidence:
      - "[config-file]: [specific rule or setting]"
    source: "config"
    examples:
      - "[Brief correct example if applicable]"
```

## Rules

- Include only findings backed by clear evidence from real config files
- Keep descriptions specific (not "follow ESLint rules" but "use single quotes for strings")
- Put exact file paths in the evidence
- If no config files are found, return an empty findings list
- Concentrate on actionable, verifiable standards
- Do NOT write any other files to the project directory. Write your YAML results only to: `[output_file]` (the orchestrator replaces this placeholder with the working file path under `.claude-workflow/tmp/standards-discover-<timestamp>/` when invoking you).
