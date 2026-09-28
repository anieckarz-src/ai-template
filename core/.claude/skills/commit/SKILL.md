---
name: commit
description: Commit session changes to git. Identify files from session context, ask the user to pick a message, run validation only if needed. Use when the user wants to commit / save / land changes.
allowed-tools: *
---

# Commit Workflow

**Asked to commit now != permission for future commits.** Each commit needs an explicit user instruction. No amend, revert, or push without an explicit ask.

Speed is critical. No slow commands unless the changes warrant them.

Project commands (`[BUILD]`, `[TEST]`, `[FORMAT]`, `[LINT]`, `[RESTART_ENV]`, `[SMOKE]`, `[E2E]`) come from the `## Project Commands` section of `CLAUDE.md`. An empty value means the step does not exist in this project - skip it silently.

## Identify Files

- Prefer session context over re-running `git status` / `log` / `diff`.
- Clean session (you have no context of what changed): all changed files. With context: only the files you changed this session.

## Validation (judgment)

Skip any command that already ran clean this session on the same files. No re-run, no offer.

When validation is needed:

1. Run `[BUILD]` first. Build the whole project when a change can ripple across boundaries (e.g. a backend API change can break a client through its contract).
2. After the build, in parallel:
   - `[FORMAT]` and `[LINT]` - when code changed
   - `[TEST]` - when logic changed
   - `[RESTART_ENV]` - when service wiring / environment configuration changed (large changes only)
   - `[E2E]` - large UI or shared E2E-covered change; `[SMOKE]` for low-impact changes (rare pre-commit)
3. If `[SMOKE]` is configured and the project uses it as a pre-commit gate, run it before committing.

Judge the impact by file (project / manifest / lock files affect their owning build, even when the extension is non-obvious).

If validation fails: stop, show the failure, and do not commit. "Pre-existing" is not an accepted excuse - see `CLAUDE.md`.

## Ask User

Simple, focused commit: propose one message and commit.

Complex (multiple unrelated changes, doesn't fit one line, validation choices needed, file set ambiguous): use AskUserQuestion - 2-4 message options + conditionals in one call. No back-and-forth. Follow up only on "Other" or unexpected input.

Commit message: follow the commit message rule in the `## Git` section of `CLAUDE.md` (default: one descriptive line in imperative form, no body, no conventional-commit prefixes such as `feat:`, `fix:`, `docs:`, `chore:`).

Conditional questions:
- Validation commands (multi-select), only those flagged as needed. Default: skip.
- File selection, if ambiguous.

## Stage and Commit

Stage explicit files. Never `git add -A` or `git add .`.

Commit exactly once. Report the short SHA.

## After Commit

If the work belongs to a 10x change (`context/changes/<change-id>/`), remind the user that the `## Progress` SHA suffix (` — <short sha>`) is written by the implementing skill (`/10x-implement`, `/10x-tdd`, `/10x-e2e`, `/10x-goal-implement`) or the team guardian - not by this skill. Do not edit `plan.md` here unless the user explicitly asks.

---

Asked to commit now != permission for future commits.
