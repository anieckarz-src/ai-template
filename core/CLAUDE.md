# Project Instructions

<!-- ai-template: fill in every TODO below, then delete this comment. -->

## Behavioral Guidelines

1. **Think before coding.** State assumptions explicitly. If uncertain, ask rather than guess. When multiple interpretations exist, present them - don't pick silently.

2. **Goal-driven execution.** Define success criteria before iterating. Loop until verified. Strong success criteria let you loop independently; "make it work" requires constant clarification.

3. **Read before you write.** Before adding code in a file, read the file's exports, the immediate caller, and obvious shared utilities. "Looks orthogonal to me" is the most dangerous phrase in any codebase.

4. **Checkpoint significant steps.** After each step in a multi-step task, summarize what was done, what's verified, and what's left. Don't continue from a state you can't describe back.

5. **Fail loud.** Surface uncertainty, don't hide it. "Completed" is wrong if anything was skipped silently. "Tests pass" is wrong if any were skipped. "Feature works" is wrong if the edge case wasn't verified.

6. **Main is always clean.** Any build, test, format, or lint failure on the branch is ours to fix. "Pre-existing" is not an accepted excuse.

## Project Overview

TODO: 2-5 lines - what this project is, the main folders, and where the entry point lives.

## Project Commands

Whenever you see `[BUILD]`, `[TEST]`, `[FORMAT]`, `[LINT]`, `[RESTART_ENV]`, `[SMOKE]` or `[E2E]` in agents, skills, or rules, replace it with the value configured here. An empty value means "not available in this project - skip that step".

```
BUILD="TODO"         # e.g. dotnet build
TEST="TODO"          # e.g. dotnet test --no-build
FORMAT="TODO"        # e.g. dotnet format
LINT="TODO"          # e.g. dotnet format --verify-no-changes
RESTART_ENV=""       # optional: restart the local environment (docker compose, AppHost, ...)
SMOKE=""             # optional: fast smoke check run before every commit
E2E=""               # optional: end-to-end test command (e.g. npx playwright test)
BASE_BRANCH="main"
```

Run `[BUILD]` first. Then run `[FORMAT]` followed by `[LINT]` (format rewrites files, so lint must see the result), in parallel with `[TEST]`.

## Work Tracking (10x workflow)

Work is tracked in files, following the 10x skills. Terms used by agents and skills map as follows:

| Term | Meaning |
|---|---|
| `[feature]` | A change folder `context/changes/<change-id>/` (`change.md` + `plan.md`), created with `/10x-new` and planned with `/10x-plan` |
| `[task]` | One `## Phase N` of that `plan.md`. Its steps live in `## Progress` (see `.claude/skills/10x-plan/references/progress-format.md`) |
| `[Planned]` | Progress row `- [ ]` |
| `[Active]` / `[Review]` | Runtime state only (team task list or conversation) - never written to `plan.md` |
| `[Completed]` | Progress row `- [x] ... — <short sha>`, written after the commit lands |

Rules:
- Name the working branch after the change-id (`<change-id>` or `<prefix>/<change-id>`), so skills can find the active change from the branch.
- Progress step titles are immutable. Never renumber or rename them.
- Deviations from the plan go to `context/changes/<change-id>/divergence.md` (what changed, why, impact on later phases).
- Durable review output goes to `context/changes/<change-id>/reviews/`.
- Scratch files that should not be committed go to `.workspace/<branch-name>/` (gitignored).

Default flow: `/10x-new` → `/10x-research` → `/10x-plan` → `/10x-plan-review` → `/10x-implement` (or `/10x-tdd`, `/10x-e2e`) → `/10x-impl-review` → `commit` → `create-pull-request` → `/10x-archive`.

## Team Roster

Used by the `implementer`/`reviewer` agents (simple mode) and by `team-lead` (full agent-team mode, see `team/` in ai-template). One line per track: `track: engineer-agent + reviewer-agent`.

```
TRACKS:
  default: implementer + reviewer
```

## Git

Never commit, amend, push, or revert without explicit user instruction each time. A request to commit now is not permission for future commits.
Commit messages: one descriptive line in imperative form, no description body, no conventional-commit prefixes. TODO: adjust to the team's convention.

## Source of Truth

Always verify paths, names, and API routes against the actual codebase. Never rely on memory, cached context, or prior session knowledge for these. Only read files within the git repository unless explicitly asked to look elsewhere.

## Project Rules

Coding rules live in `.claude/rules/` and load automatically for matching paths (`paths:` frontmatter). When you learn a recurring pitfall, record it with `/10x-lesson`.
