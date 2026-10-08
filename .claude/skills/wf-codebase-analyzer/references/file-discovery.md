# File Discovery — Prompt Templates

Substitute the actual task description for `[description]`.

## Bug
```
IMPORTANT: Do NOT create, write, or modify any files. Output all findings as text in your response only.

Explore the codebase to find files related to: "[description]"

Focus on:
1. Find files where the bug likely occurs (search for error keywords, related functionality)
2. Trace the code path - entry points, handlers, processing logic
3. Look for related error handling, validation, edge cases
4. Find configuration files that might affect this behavior

Output a list of relevant files with their paths and why they're relevant.
Be thorough - check multiple naming conventions (PascalCase, kebab-case, snake_case).
```

## Enhancement
```
IMPORTANT: Do NOT create, write, or modify any files. Output all findings as text in your response only.

Explore the codebase to find files that implement: "[description]"

Focus on:
1. Find the main files for this feature (services, controllers, handlers, repositories)
2. Look for related files (types, DTOs, utilities, configuration)
3. Check multiple naming patterns: *{keyword}*, {Domain}{Service}, {Domain}Controller, etc.
4. Search in likely directories: src/services/, src/controllers/, src/features/, src/domain/

Output a ranked list of files with confidence indicators.
Include file paths, approximate line counts, and why each file is relevant.
```

## Feature
```
IMPORTANT: Do NOT create, write, or modify any files. Output all findings as text in your response only.

Explore the codebase to find patterns and integration points for: "[description]"

Focus on:
1. Find similar existing features/modules to use as templates
2. Identify where this new feature should live (directory structure)
3. Look for shared utilities, middleware, or base classes to extend
4. Find entry points where this feature needs to integrate (routes, DI registration, message handlers, scheduled jobs, etc.)

List the files that serve as good examples or integration points.
Include reasoning for why each pattern/location is appropriate.
```
