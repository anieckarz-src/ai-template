# Aggregation Strategy — Confidence Scoring & Deduplication

## Deduplication Rules

Findings are grouped by `category + standard_name`. When several findings match:

1. **Merge evidence** — Combine every evidence item from every source
2. **Track sources** — Record which phases contributed (config, code, docs, external)
3. **Take strongest description** — Prefer documented > config > code-inferred
4. **Preserve examples** — Combine the unique examples

## Confidence Scoring

Compute the final confidence from the following factors:

### Source Count (max 45 points)
- Each distinct source: +15 points (config, code-patterns, documentation, pr-reviews, ci-config, pre-commit)
- Capped at 45 points (3+ sources)

### Consistency (max 20 points)
- >= 90% consistency across the sampled files: +20
- 70-89% consistency: +10
- < 70% consistency: +0

### Explicitness (max 15 points)
- Found in a config file (explicit rule): +15
- Found in documentation (stated explicitly): +10
- Only inferred from code patterns: +5

### Evidence Strength (max 20 points)
- Each evidence item: +5 points, capped at 20 (4+ evidence items)

### PR Feedback Boost (max 10 points)
- Mentioned in 5+ PR reviews: +10
- 3-4 PR reviews: +5

**Final score**: The sum of the factors, capped at 100.

## Conflict Detection

Flag a conflict when two findings about the same aspect give contradictory guidance:

- Same tool, different settings (e.g., ESLint and Prettier disagreeing on semicolons)
- The documentation says one thing while the config enforces another
- Code patterns do not match the documented standards

Show each conflict to the user with both sides and their evidence.

## Confidence Categories

| Level | Range | Guidance |
|-------|-------|----------|
| High | >= 80% | Strong evidence from multiple sources. Safe to apply. |
| Medium | 60-79% | Some evidence, clarification may be needed. Review recommended. |
| Low | < 60% | Weak or inconsistent patterns. May point to an area that needs standardization. |

## Presentation Order

1. High confidence findings (batch approval option)
2. Medium confidence findings (individual review)
3. Conflicts (resolution required)
4. Low confidence findings (informational, skip option)

## Presentation Format

Ahead of any approval prompts, show a **full summary table** grouped by confidence level. Every finding row contains:

- **Standard name** and **category**
- **Confidence score** (numeric, 0-100)
- **Sources** — every contributing source listed (e.g., "config, code, docs"). This matters for user trust and decision-making.
- **Brief description** (a single line, truncated when needed)

When drilling into an individual finding (medium confidence, or a drill-down the user asked for), show:
- The full description and examples (preferred/avoid patterns)
- Evidence items with source attribution (which source supplied each piece of evidence)
- Confidence score breakdown: the points from each factor (source count, consistency, explicitness, evidence strength, PR boost), so the user understands why the score is what it is
