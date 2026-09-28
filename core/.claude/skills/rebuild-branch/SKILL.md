---
name: rebuild-branch
description: Rebuild a stale branch by cherry-picking each commit onto a fresh branch off the base branch, validating every commit (build, test, format, lint, optional e2e) before moving on. Resumable via a commits checklist. Use when a branch has gone stale, has merge conflicts with the base, or needs to be split out of a long-lived feature branch.
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion, EnterWorktree
---

# Rebuild Branch

Drive a branch rebuild end to end: discovery and planning (STEP 1-6), then an explicit commit-by-commit loop (STEP 7). All state lives in a checklist file, so the loop can be stopped at any point and resumed by invoking this skill again.

Project commands (`[BUILD]`, `[TEST]`, `[FORMAT]`, `[LINT]`, `[RESTART_ENV]`, `[SMOKE]`, `[E2E]`, `[BASE_BRANCH]`) come from the `## Project Commands` section of `CLAUDE.md`. An empty value means "skip that step". Below, `<base>` defaults to `[BASE_BRANCH]`.

## STEP 1: Determine source branch

The user may have named the source branch as the skill argument. If not, ask which branch to rebuild.

If the source branch is not crystal-clear (multiple matches, ambiguous shorthand), confirm the resolved name with the user before proceeding.

## STEP 2: Detect resume vs. fresh start

Compute the root repo path (the main worktree, not the current one):

```bash
ROOT_REPO=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
CURRENT_BRANCH=$(git branch --show-current)
```

A run is in progress if the current branch ends with `-rebuild` AND `$ROOT_REPO/.workspace/<source-branch>/commits.md` exists (the source branch is the current branch without the `-rebuild` suffix).

**If resuming:**
1. Read `commits.md` and count `[x]` vs `[ ]` lines. Identify the next pending commit.
2. Read `learnings.md` and surface the last 3 entries.
3. Show the user a status panel: branch name, N of M commits done, next commit hash + title, last learnings.
4. Use AskUserQuestion to confirm continuing and offer a run-mode change. Options: keep current mode, switch to autonomous, switch to interview-on-problem.
5. Skip to STEP 7.

**If fresh:** continue to STEP 3.

## STEP 3: Verify clean working tree

```bash
git status --porcelain
```

If there are uncommitted changes, stop and ask the user to stash or commit first. Do not proceed.

## STEP 4: Discover commits

Determine the base. If currently on `<base>`, use it. Otherwise use AskUserQuestion to ask whether to base on `<base>` or on the current branch.

List commits oldest-first:

```bash
git log <base>..<source-branch> --reverse --format='%h %s'
```

Show the list newest-first to the user with hash + title and confirm the range. If empty, stop and report nothing to do.

## STEP 5: Worktree decision

Use AskUserQuestion to ask whether to create a worktree. (Some projects do not support worktrees well, so always ask — never assume.)

**If yes:**
```bash
git worktree add -b <source-branch>-rebuild .claude/worktrees/<source-branch>-rebuild <base>
```
Then call the `EnterWorktree` tool to switch context.

**If no:** create the rebuild branch in the current repo:
```bash
git switch --create <source-branch>-rebuild <base>
```

## STEP 6: Run mode and write planning files

Use AskUserQuestion to ask which run mode the loop should use:
- **autonomous** — the loop plows through, fixes problems on its own, never asks
- **interview-on-problem** — the loop pauses and asks via AskUserQuestion when it cannot make progress

Also ask whether `[E2E]` should run as part of validation (only if `[E2E]` is configured): never / smoke per commit and full suite every 5 commits / full suite every commit.

Write the planning files in the **root repo** (not the worktree) so they survive worktree deletion:

```
$ROOT_REPO/.workspace/<source-branch>/commits.md
$ROOT_REPO/.workspace/<source-branch>/learnings.md
```

**`commits.md` format:**
```markdown
<!-- mode: <run-mode> | e2e: <never|periodic|every> | source: rebuild-branch | started: <YYYY-MM-DD> -->
N commits to apply.

[ ] <hash> <subject>
[ ] <hash> <subject>
...
```

Lines are oldest-first (the order they will be applied).

**`learnings.md`** starts as just a heading:
```markdown
# Learnings — <source-branch> rebuild
```

## STEP 7: The rebuild loop

Repeat the iteration below until every line in `commits.md` is `[x]`. Re-read `commits.md` at the start of every iteration — it is the single source of truth, not your memory. After each iteration, print a one-line checkpoint: `<done>/<total> — <hash> <subject> — <clean | conflicts resolved | reshaped>`.

If the session is interrupted or the context grows too large, stop after completing the current iteration (clean tree, `[x]` written). The user re-invokes this skill; STEP 2 resumes from the next pending line.

### Iteration

1. **Pick the next commit** — the first line in `commits.md` without `[x]`. If every line is marked, go to STEP 8.

2. **Land the commit cleanly** — `git cherry-pick <hash>` and resolve any conflicts so the working tree reflects the intended state of that commit. Note whether conflicts were manually resolved — this drives the validation order in step 4.

3. **Sanitize the commit message** — follow the commit message rule in the `## Git` section of `CLAUDE.md` (default: a single line). Strip any `# Conflicts:` block that git inserts after a conflicted cherry-pick, and any other `#`-prefixed comment lines. Verify with `git log -1 --format=%B`.

4. **Validate the change** — order depends on whether conflicts were resolved in step 2. Skip any command that is empty in `CLAUDE.md`.

   **Conflicts resolved (code was touched by hand):**
   1. `[BUILD]` (must succeed)
   2. `[FORMAT]` (must run before lint, since manual edits often need formatting that would otherwise show up as lint findings)
   3. In parallel: `[TEST]`, `[RESTART_ENV]` (if service wiring changed), `[E2E]` per the chosen e2e policy (`[SMOKE]` or a smoke subset for small changes; full suite for large changes)
   4. `[LINT]`
   5. If lint or any earlier step changed files, restart this validation from 4.1

   **No conflicts (clean cherry-pick):**
   1. `[BUILD]` (must succeed)
   2. In parallel: `[TEST]`, `[FORMAT]`, `[LINT]`, `[RESTART_ENV]` (if needed), `[E2E]` per policy
   3. If any parallel step changed files, restart this validation from 4.1

   Run E2E in fail-fast mode when the runner supports it. If anything fails, fix it and do not move on until it is green. If something is missing because a later commit introduces it, pull only the minimum needed lines forward and note it under that future commit in `commits.md` as an indented line: `(partially pulled into earlier commit)`.

5. **Fold all fixes into the cherry-picked commit** — `git commit --amend --no-edit` (after staging explicit files) so the commit is standalone: it builds, tests, lints, and passes e2e on its own. Re-run the sanitize step if the amend re-introduces any `# Conflicts:` block or `#`-prefixed lines.

6. **Verify the working tree is clean** — `git status` must show zero changes after the amend. If anything remains, you missed folding it in. Fix and amend again.

7. **Mark the commit done** — change `[ ]` to `[x]` on its line in `commits.md`.

8. **Log learnings** — append a one-line entry to `learnings.md` for any non-trivial adaptation, conflict resolution choice, or skipped piece. Format: `- <hash> — <one-line note>`. Skip routine cherry-picks that landed cleanly.

### Mode-specific behavior

- **autonomous:** do not ask the user anything. Make every judgment call yourself. Note unusual choices in `learnings.md`.
- **interview-on-problem:** when you cannot make progress (irreconcilable conflict, ambiguous intent, change that no longer makes sense in the new codebase), use AskUserQuestion. Bake the answer into your next attempt and log it in `learnings.md`.

### Operating principles

- Never stop on a hard commit. If a commit cannot be made to work as-is, reshape the plan: collapse it with a neighbor, split it, reorder it, or drop changes that are no longer needed. Update `commits.md` to reflect the reshaped plan and log why. The goal is a working rebuild, not literal preservation of every original commit.
- Smallest possible change when borrowing forward — pull only the lines required to compile or pass tests, never whole files or unrelated changes.
- Every iteration ends with a clean tree, a passing build, passing tests, passing lint, passing e2e (per policy), and one more `[x]` in `commits.md`.
- The amend in step 5 only touches the commit just cherry-picked onto the rebuild branch — it never rewrites the source branch. Never push, force-push, or delete the source branch.

## STEP 8: Finish

When all lines are `[x]`:

1. Run the full validation once more on the final state: `[BUILD]`, then `[FORMAT]`, `[LINT]`, `[TEST]`, and the full `[E2E]` suite if e2e was enabled.
2. Compare the end result with the source branch: `git diff <source-branch> <source-branch>-rebuild --stat`. Explain every remaining difference (expected adaptations to the new base vs. accidental drops).
3. Report: rebuild branch name, commit count (original vs. rebuilt, noting collapsed/split/dropped commits), the `learnings.md` highlights, and the paths to `commits.md` and `learnings.md`.
4. Do not push, rename, or replace the source branch. Ask the user what to do next (e.g. open a pull request with the `create-pull-request` skill).
