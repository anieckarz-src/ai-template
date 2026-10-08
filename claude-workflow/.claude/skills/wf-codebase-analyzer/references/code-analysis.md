# Code Analysis — Prompt Templates

Substitute the actual task description for `[description]`.

## Bug
```
IMPORTANT: Do NOT create, write, or modify any files. Output all findings as text in your response only.

Analyze the code related to: "[description]"

Focus on:
1. Trace execution flow from input to output
2. Identify state changes and side effects
3. Look for edge cases, error conditions, race conditions
4. Find validation logic and where it might fail
5. Check for recent changes that might have introduced the bug

Output:
- Execution flow diagram (text-based)
- Key functions/methods involved
- Potential problem areas
- Persistence and transaction handling approach
```

## Enhancement
```
IMPORTANT: Do NOT create, write, or modify any files. Output all findings as text in your response only.

Analyze the existing implementation of: "[description]"

Focus on:
1. Understand current functionality and capabilities
2. Identify the service/module architecture
3. Document the data flow (requests, service calls, persistence, external API calls)
4. Note coding patterns used (classes, functional, dependency injection)
5. Assess complexity (simple/moderate/complex)

Output:
- Current functionality summary
- Architecture overview
- Key functions and their purposes
- Coding patterns observed
```

## Feature
```
IMPORTANT: Do NOT create, write, or modify any files. Output all findings as text in your response only.

Analyze the codebase architecture for adding: "[description]"

Focus on:
1. Understand the overall project structure
2. Identify architectural patterns in use (layered, hexagonal, CQRS, etc.)
3. Document naming conventions and code style
4. Find the data layer patterns (API, repositories, persistence)
5. Note any relevant abstractions or base classes

Output:
- Project structure overview
- Architectural patterns to follow
- Naming conventions to match
- Recommended approach for new feature
```
