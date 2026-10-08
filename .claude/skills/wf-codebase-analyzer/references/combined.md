# Combined Prompts — Guidance

When folding several roles into one agent, combine their concerns logically instead of just concatenating the prompts. First read the individual role templates, then merge them into one coherent prompt.

## Example: File Discovery + Code Analysis (Bug)

```
IMPORTANT: Do NOT create, write, or modify any files. Output all findings as text in your response only.

Explore and analyze the codebase for: "[description]"

1. Find files where the bug likely occurs (search for error keywords, related functionality)
2. Trace the code path through these files - entry points, handlers, processing logic
3. Identify state changes, side effects, and potential failure points
4. Look for edge cases, validation logic, and error handling
5. Check for related configuration that might affect behavior

Output:
- Relevant files with paths and why they matter
- Execution flow through identified files
- Key functions/methods and their roles
- Potential problem areas and root cause hypotheses
```

## Merging Principles

- Bring the focus areas together into one logical flow (rather than simply listing both sets of bullet points)
- Merge the output sections — avoid asking for the same thing twice
- Keep the overall prompt concise (target 8-12 focus items at most)
- The merged prompt should read like one coherent task, not like two tasks stitched together
- Always include the no-write constraint: "IMPORTANT: Do NOT create, write, or modify any files. Output all findings as text in your response only."
