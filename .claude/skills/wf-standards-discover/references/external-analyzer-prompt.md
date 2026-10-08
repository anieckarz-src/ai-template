# External Standards Analyzer — Subagent Prompt Template

Examine pull requests, CI/CD configurations, and pre-commit hooks to discover the standards they enforce.

## Task

Mine the external sources for evidence of standards and return the findings as YAML.

## Sources to Analyze

### 1. Pull Requests (via gh CLI)

**Check availability first:**
```bash
which gh && gh auth status
```

When the gh CLI is available:
- Fetch the last `[pr_count]` merged PRs: `gh pr list --state merged --limit [pr_count] --json number,title`
- For every PR, look through review comments for feedback patterns that repeat
- Search for: "Please use...", "Always...", "Avoid...", "Per our convention...", "Style:", "Nit:"
- Report only patterns that show up in **3+ different PRs** (significant feedback, not a one-off)

When the gh CLI is unavailable: skip the PR analysis and note it in the output; this is not an error.

### 2. CI/CD Workflows

- **GitHub Actions**: `.github/workflows/*.yml`
- **GitLab CI**: `.gitlab-ci.yml`
- **Other**: `Jenkinsfile`, `.circleci/config.yml`, `.travis.yml`

Extract: lint steps, test requirements, coverage thresholds, build quality gates, pre-deployment checks.

### 3. Pre-commit Hooks

- **Husky**: `.husky/` directory (pre-commit, pre-push scripts)
- **pre-commit framework**: `.pre-commit-config.yaml`
- **lint-staged**: `lint-staged` config in `package.json` or `.lintstagedrc`

Extract: mandatory checks, formatting enforcement, commit message validation.

## Confidence Ranges

| Source | Confidence Range | Rationale |
|--------|-----------------|-----------|
| CI/CD enforced standards | 85-95% | Automation enforces it — highly reliable |
| Pre-commit hooks | 80-90% | Actively enforced on each commit |
| PR review patterns (5+ PRs) | 70-80% | Strong team consensus |
| PR review patterns (3-4 PRs) | 60-70% | Emerging pattern |

## Output Format

Return YAML:

```yaml
github_available: true  # or false
findings:
  - category: "[category/subcategory]"
    standard_name: "[Short Name]"
    description: "[What the standard requires]"
    confidence: [60-95]
    evidence:
      - "[source]: [specific evidence]"
    source: "[pr-reviews|ci-config|pre-commit]"
    examples: []
```

## Rules

- Handle the gh CLI gracefully — return `github_available: false` with empty PR findings rather than an error
- Report only PR patterns that appear in 3+ different PRs
- For CI/CD: pull out the specific thresholds and rules, not merely "runs tests"
- If no external sources are available, return an empty findings list
- Be specific: "80% coverage required" rather than "has coverage check"
- Do NOT write any other files to the project directory. Write your YAML results only to: `[output_file]` (the orchestrator replaces this placeholder with the working file path under `.claude-workflow/tmp/standards-discover-<timestamp>/` when invoking you).
