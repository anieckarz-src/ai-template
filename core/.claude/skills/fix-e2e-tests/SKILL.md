---
name: fix-e2e-tests
description: Systematically fix all failing E2E tests using a phased diagnostic approach. Classifies tests as passing, flaky, or permanently failing, then fixes them one by one with progressive scope expansion (smoke → full suite, one browser → all browsers). Framework-agnostic; runs the project's [E2E] command.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Fix E2E Tests

Systematically fix all failing end-to-end tests by diagnosing first, then fixing one by one, expanding scope progressively. Optimizes for speed of fixing over exhaustive analysis.

The test command is `[E2E]` from the `## Project Commands` section of `CLAUDE.md` (and `[SMOKE]` if configured). If `[E2E]` is empty, stop and ask the user how E2E tests are run. Examples below use Playwright flags (`--project=chromium`, `--retries=1`, `--grep @smoke`, `--repeat-each`); translate them to the project's runner (Cypress, WebdriverIO, etc.). If the project has no browser matrix or no smoke tag, collapse the corresponding steps.

Before making changes, read any E2E rules under `.claude/rules/` (e.g. files whose `paths:` cover the test folder) and `context/foundation/lessons.md` if it exists. If the `/10x-e2e` skill is present, its `references/` (rules and anti-patterns) apply to every test you touch.

## Core Principles

1. **Test bug or app bug?** For every failure, critically evaluate: is the test wrong, or is the application wrong? A failing test might be correctly catching an application bug. If the application is broken, fix the application -- do not make the test pass by weakening it
2. **Focus on the first failing step only.** Do not attempt to fix later steps in a test until the first step passes. You do not know if later steps would actually fail
3. **Never predict failures.** Do not speculatively fix things that look like they might fail. Only fix what is actually failing right now
4. **Apply global fixes.** When a fix applies across multiple tests (e.g., a renamed button), apply it everywhere before re-running. Do not fix one test at a time when the same change applies to many
5. **One test at a time.** After global fixes, run each failing test individually. Fix the first step. Re-run. Iterate

## STEP 1: Diagnostic Run -- Smoke Tests in One Browser

Run all smoke tests in a single browser (e.g. Chromium) with retries=1 to classify every test (e.g. `[E2E] --project=chromium --grep @smoke --retries=1`):
- **Passing**: Passes on first attempt
- **Flaky**: Fails first attempt, passes on retry
- **Permanently failing**: Fails both attempts

Save a diagnostic report to `.workspace/<branch-name>/e2e-diagnostic.md` with test counts and, for each failure, the test file, test name, first failing step, and error message.

If all tests pass, skip to STEP 4.

## STEP 2: Fix Permanently Failing Tests

Work through permanently failing tests one at a time:

1. **Run the failing test in isolation** to confirm it is truly permanently failing and not flaky. A test that failed in the full suite might pass when run alone (resource contention, test ordering). If it passes in isolation, reclassify it as flaky and handle it in STEP 3
2. **Read the first failing step** and its error message
3. **Evaluate: test bug or app bug?** Did we deliberately change something the test is catching? Would a real user see this as broken? If it is an app bug, report it and move on -- do not fix the test
4. **Check for global applicability.** Does the same fix apply to other tests? Apply globally first, then re-run diagnostics
5. **Fix the first step.** Make the minimal change. Do not touch later steps
6. **Re-run the individual test.** If it passes, move to the next failing test. If a new step fails, repeat from step 1

Update the diagnostic report after each fix.

## STEP 3: Address Flaky Tests

After permanently failing tests are fixed:

1. Run each flaky test multiple times individually to confirm flakiness (e.g. `--repeat-each=10`)
2. Identify the root cause -- do not add arbitrary waits or timeouts (never `waitForTimeout` or sleeps; wait for state instead)
3. Review the E2E rules in `.claude/rules/` for known patterns
4. Fix the root cause. If the flakiness is caused by an application bug, report it to the user -- the application must be fixed
5. Re-run the test multiple times to confirm it is now stable. Do not move on until it passes consistently

## STEP 4: Expand to All Browsers -- Smoke Tests

Run smoke tests across all configured browsers. Fix any browser-specific failures using the same one-at-a-time process from STEP 2.

## STEP 5: Expand to All Tests in One Browser

Run all tests (smoke + comprehensive, excluding tests tagged as slow if the project has such a tag) in the single browser from STEP 1. Fix any failures using the same process.

## STEP 6: Expand to All Tests in All Browsers

Run the full test suite across all browsers. Fix any remaining failures.

## STEP 7: Final Validation

Run the full test suite across all browsers one final time. Every test must pass. Zero failures, zero flaky tests. This skill is not complete until all tests pass consistently.

Update `.workspace/<branch-name>/e2e-diagnostic.md` with:
- Final test counts: all must be passing
- Summary of changes made (test fixes and application fixes)
- Application bugs that were found and fixed

## Key Rules

- Run tests for the specific failing file, not the whole suite, when fixing individual tests
- Apply global fixes before re-running diagnostics
- Do not run all browsers until the first browser passes
- Only fix what is actually failing -- do not refactor passing tests
- Read the E2E rules in `.claude/rules/` before making changes
- A changed selector may be fixed in the test; a changed business behavior must not be "fixed" by rewriting the assertion -- that masks the bug
- If stuck after 3 fix attempts on the same test, escalate to the user
- Zero tolerance: this skill is not complete until every test passes in every browser
