---
name: create-pull-request
description: Create or update a GitHub pull request for the current branch using the gh CLI - validates, verifies the branch name, drafts title and description (linking the 10x change if present), pushes, and opens the pull request. Use when the user asks to open / create / update a pull request.
allowed-tools: *
---

# Create Pull Request Workflow

Project commands (`[BUILD]`, `[TEST]`, `[FORMAT]`, `[LINT]`, `[RESTART_ENV]`, `[SMOKE]`, `[E2E]`, `[BASE_BRANCH]`) come from the `## Project Commands` section of `CLAUDE.md`. An empty value means "skip that step". Below, `<base>` is `[BASE_BRANCH]` (default `main`) unless the user named another base.

## STEP 1: Gather Context

Run in parallel (quick reads, not background):

- `git status` - working tree state
- `git branch --show-current` - local branch
- `git --no-pager log --format=%s --reverse $(git merge-base HEAD <base>)..HEAD` - commits on the branch
- `git --no-pager diff <base>...HEAD` - full diff
- `git rev-parse @{u} 2>/dev/null` - upstream presence (already pushed?)
- `gh pr view --json number,url,state 2>/dev/null` (only if upstream exists) - check if the branch already has an open pull request
- `gh label list --limit 100 --json name,description 2>/dev/null` - labels that exist in the repository
- Check whether `.github/PULL_REQUEST_TEMPLATE.md` (or `.github/pull_request_template.md`) exists

## STEP 2: Kick Off Background Work

Everything in this step starts in the background (`run_in_background: true`) so the workflow proceeds without waiting. Results are reconciled in STEP 10.

### Validation

Skip anything already green this session. Only run what is genuinely uncertain.

When validation IS needed:

1. Run `[BUILD]` first.
2. After the build, in parallel:
   - `[RESTART_ENV]` - service wiring / environment configuration changed
   - `[FORMAT]`, `[LINT]` - code changed
   - `[TEST]` - logic changed
   - `[E2E]` - UI or shared E2E-covered code changed; use `[SMOKE]` instead for low-impact changes (judgment)

Use judgment to decide what a file affects (project / manifest / lock files affect their owning build, even when the extension is not obvious). Each item runs only if needed and not already green.

## STEP 3: Verify Branch Name

Three checks - all read-only at this stage; renames happen in STEP 8.

1. **Strip `worktree-` prefix.** Local-only convention; never push it.
2. **Naming convention.** Lowercase kebab-case (or the convention documented in `CLAUDE.md`).
3. **Drift check.** If the slug no longer describes the work (e.g. `fix-login-bug` whose commits do a refactor), draft a new name.

If check 1 or check 3 fires, stash the proposed new name; STEP 4 will ask the user to confirm.

## STEP 4: Ask the User

Ask everything upfront so the user does not wait through slow drafting just to be prompted at the end. Single AskUserQuestion call, up to four questions:

1. **Labels** (multi-select, zero or more) - only if STEP 1 found labels in the repository. Offer only labels that exist (`gh label list`), picking the 2-4 most relevant to this diff. Never invent labels. If the repository has no labels, skip this question.
2. **Pull request checklist** (single-select) - only if a pull request template with `[ ]` items exists. The recommended option spells out every `[ ]` item from the template in present tense (e.g. "Confirm you have added tests and updated the documentation"). The alternative is "Leave checklist items unchecked".
3. **Review before pushing** (single-select): "Show me the rendered title and description before pushing" / "Push immediately".
4. **Branch rename confirmation** (single-select), only if STEP 3 flagged a rename: "Rename `<current>` to `<proposed>`?" with options Yes / No / Use a different name (free-text).

Stash the answers; consumed in STEP 6, 7, 8, 11.

## STEP 5: Correlate to the 10x Change

Work is tracked in `context/changes/<change-id>/` (see `## Work Tracking` in `CLAUDE.md`).

1. **Find the change.** Look for `context/changes/<change-id>/` where `<change-id>` matches the branch name (strip a `worktree-` prefix and anything up to the last `/`, e.g. `feature/add-login` → `add-login`), or is referenced in commit messages or the conversation. If exactly one active change exists under `context/changes/`, treat it as a candidate and confirm it matches the diff. If ambiguous, ask.
2. **If a change is found**, read `change.md` and `plan.md` (and `divergence.md` if present). Use the intent, phases, and `## Progress` state to validate the draft in STEP 6 and spot drift:
   - Commits that implement work outside the plan's scope → mention them in the description and suggest recording them in `divergence.md`.
   - Progress rows still `- [ ]` for phases the diff appears to complete → mention it in the report (do not edit `plan.md` here).
3. **Detect unrelated commits (rare).** If some commits clearly belong to a different scope, surface them. Offer to capture them as a follow-up via `/10x-new` - written as a fresh problem statement (future tense, what needs to happen). The pull request continues with all commits unless the user says otherwise.
4. **If no change exists**, continue without one. Do not create a change unless the user asks.

## STEP 6: Draft Title and Description

### Title

Write a fresh title based on the actual diff, commits, and change context - not the branch name (branch names are often abbreviated and do not make good titles).

- Imperative form ("Fix", "Add", "Upgrade", "Refactor")
- Sentence case (not Title Case)
- No trailing period
- No "Pull Request" / "PR" / abbreviations
- No personal pronouns ("we", "our", "he", "she")
- No change IDs in the title

### Description

If a pull request template exists, follow its structure. Otherwise use:

```markdown
### Summary & Motivation

<lead with the most important change; what and why>

### Checklist

- [ ] <only if the project defines one>
```

Rules:

- **Summary & Motivation**: lead with the most important change, explain what and why (not how), use bullets for multiple items, mention minor fixes last. **Do not end with a closing benefit summary** - it adds nothing and is the most common reason a description gets rejected.
- **Avoid the words "pull request" in the body.** Use "this change", "the change", etc.
- **Change link**: if STEP 5 found a change, add a short line near the end, e.g. `Change: context/changes/<change-id>/ (plan.md)`.
- **Checklist**: copy items from the template. Render every `[ ]` as `[x]` if the user picked the "confirm" option in STEP 4; otherwise leave them as `[ ]`.

Save the rendered title (as a level-1 heading) + body to `.workspace/<branch-name>/pull-request.md`. Use the un-prefixed branch name if STEP 3 stripped `worktree-`.

## STEP 7: Optional Review Gate

If the user picked "Show me before pushing" in STEP 4:

- Print the rendered title and the body inline.
- Ask "Open pull request with this content? (yes / edit)".
- On "edit", let the user dictate changes. Re-save the markdown. Re-confirm.

Otherwise skip this step.

## STEP 8: Branch Hygiene

If STEP 4 confirmed a rename, rename the branch (`git branch -m <new-name>`) and verify. Safe in a worktree (the directory path is independent of the branch name). The push step sets the new upstream.

## STEP 9: Push

1. Re-check upstream tracking with `git rev-parse @{u} 2>/dev/null`.
2. **If unset** (branch never pushed, or just renamed): ask "Branch is local-only. Push to origin?". On confirm, push with upstream tracking (`git push --set-upstream origin "$(git branch --show-current)"`).
3. **If upstream exists**, check divergence:
   - `git log --oneline @{u}..HEAD` (local-ahead)
   - `git log --oneline HEAD..@{u}` (remote-ahead)
   - If remote-ahead: surface the divergence and stop. Do not force-push without an explicit user request.
   - If only local-ahead: `git push`.

## STEP 10: Wait for Background Validation

Check the status of the background tasks started in STEP 2.

- **Done and passed**: continue silently.
- **Done and failed**: print the failure and pause. Do not open the pull request until the user decides (fix / open anyway / abort).
- **Still running**: surface the status. Ask "Wait for completion, or proceed?". If proceeding, mention that CI (if configured) will re-run these.
- **Killed earlier (user opt-out)**: skip.

## STEP 11: Create or Update the Pull Request via gh

Pre-flight: `gh auth status`. If not authenticated, surface and stop.

Use the existing pull request check result from STEP 1. Strip the level-1 heading from the body file before passing it (e.g. write the body without the heading to `.workspace/<branch>/pull-request-body.md`).

**If an open pull request already exists for this branch:**

```sh
gh pr edit <number> \
  --title "<title>" \
  --body-file ".workspace/<branch>/pull-request-body.md" \
  --add-label "<each-selected-label>"
```

Tell the user the pull request was updated, not newly created. Do not change draft/ready state without an explicit ask.

**If no pull request exists:**

```sh
gh pr create \
  --title "<title>" \
  --body-file ".workspace/<branch>/pull-request-body.md" \
  --base <base> \
  --assignee @me
```

Append `--label "<name>"` per label selected in STEP 4 (omit if none). `@me` resolves to the authenticated user. Do not pass `--draft` unless the user asked for a draft.

Capture the pull request URL from gh's output for STEP 12.

## STEP 12: Report

Print:

- The pull request URL (clickable)
- Title
- Labels applied (or "none")
- Linked 10x change (or "none")
- Any drift noted in STEP 5 (out-of-scope commits, unchecked Progress rows)
- Pull request markdown saved at the absolute path

End with a clickable link to the saved file.

## Examples

### Example 1 - Title

```
# DO: imperative, sentence case, no period
Add user profile image upload functionality
Fix session cookie not shared between API and web client
Upgrade dependency versions to latest stable releases

# DON'T: past tense, period, title case, prefixes
Added User Profile Image Upload Functionality.
PR: Implement new feature
Updating dependencies
```

### Example 2 - Description

```markdown
### Summary & Motivation

Share the session cookie between the API and the web client to fix login loops after the domain split. Previously, each host set its own cookie scope, so a session created by the API was not visible to the web client.

- Configure a common cookie domain for both hosts
- Align the cookie `SameSite` policy across environments

Change: context/changes/shared-session-cookie/ (plan.md)

# DO: stop here - no closing benefit summary

### Checklist

- [x] I have added tests, or done manual regression tests
- [ ] I have updated the documentation, if necessary
```

```markdown
### Summary

# DON'T: personal pronouns, past tense, "pull request" term, vague descriptions
In this pull request we fixed a bug causing issues with cookies.

- We added some configuration.
- Fixed a bug.

These changes make the system more robust and maintainable. # DON'T: closing summary
```

### Example 3 - Branch with `worktree-` prefix

Local: `worktree-fix-login-redirect` -> propose `fix-login-redirect` (rename in STEP 8, push in STEP 9).

### Example 4 - Branch drift

Local: `fix-login-redirect`. Actual work: refactored the login command and added auto-redirect.

Propose `refactor-login-command-with-auto-redirect`. Confirm in STEP 4; rename in STEP 8.

### Example 5 - Unrelated commits

Branch: `fix-login-redirect`. Commits: the redirect fix + an unrelated typo fix in README.

Surface the typo commit. Offer to capture a follow-up via `/10x-new`: "Fix typo in README troubleshooting section" (problem statement, future tense). The pull request continues with both commits.

### Example 6 - End-of-output report

```
Pull request opened: https://github.com/<owner>/<repo>/pull/123

Title:        Fix login redirect after OTP verification
Labels:       bug
Change:       context/changes/fix-login-redirect/
Drift:        none
Description:  /absolute/path/to/repo/.workspace/fix-login-redirect/pull-request.md
```
