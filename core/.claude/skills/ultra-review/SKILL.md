---
name: ultra-review
description: Multi-round, multi-agent adversarial deep review of a branch (discovery, cross-review false-positive hunt, finalization, digest). Trigger only on explicit "ultra review" or "ultra-review", or when invoked by team-lead at feature completion.
allowed-tools: *
---

# Ultra Review Workflow

Orchestrate a multi-round, multi-agent deep review. Goal: depth over speed. Maximize real problems found, minimize false positives via adversarial cross-critique.

The orchestrator never writes findings. Design the review, spawn agents, digest results.

## Invocation modes

- **Interactive** (user typed "ultra review"): run the STEP 1 interview. STEP 10 presents findings and offers to write `TASKS.md` and turn it into a new 10x change.
- **Autonomous** (team-lead invocation at feature completion): the caller supplies scope, risk hotspots, size, and confidence policy directly. Skip STEP 1's user questions. Skip STEP 10's chat presentation. Always write `TASKS.md`; never create changes or edit `plan.md`. Return the `TASKS.md` path to the caller.

## Core principles

- **Depth, not token-saving.** Spend whatever it takes. Use Explore subagents for code search, any MCP tools that are available in the session (database, observability, third-party service consoles, issue trackers, web research), and any other tooling the project provides.
- **Generic by design.** Roster, clusters, and focus areas are co-designed with the user every time. No fixed catalog.
- **80/20.** Agents spend ~80% on the few highest-risk areas (deep dive), ~20% sanity-scanning the rest.
- **No cap on agent count.** Match the change: a 20K-line branch touching money, integrations, and migrations may warrant 25+ agents; a small UI fix may warrant 4.
- **Multiple agents on hot areas.** Assign 3-4 agents to each high-risk area from different angles. Overlap is expected and strengthens signal.
- **Agents run independent and parallel.** No coordinating, no splitting work mid-flight.
- **False-positive hunt.** Round 2 disproves findings, not validates them. Survivors must be defensible.
- **Confidence is categorical**, not percentages:
  - **Certain** — verified; can reproduce, cite exact code paths, quote evidence.
  - **Likely** — strong evidence, one step short of full verification. Must state what would close the gap.
  - **Possible** — plausible from patterns or partial evidence; not verified. Must state the gap.
- **Confidence policy** (set in interview):
  - **Default policy**: "Certain only" (drop weaker) or "Allow Likely and Possible with explanation" (keep weaker findings, each with a "Why not Certain" note).
  - **High-impact exception**: agents flagged high-impact (security, data loss, privacy, regulatory) may always keep Likely and Possible findings with an uncertainty note, regardless of default. Better to surface a possible breach than drop it.

## Output structure

Resolve the output directory `<out>` once, at the start:

- **A 10x change exists** for this branch (`context/changes/<change-id>/` matching the branch name after stripping a `worktree-` prefix and anything up to the last `/`, referenced in commits/conversation, or named by the caller): `<out>` = `context/changes/<change-id>/reviews/ultra-review/<YYYYMMDD-HHmm>/` (durable, committed with the change).
- **No change**: `<out>` = `.workspace/<branch-name>/ultra-review/<YYYYMMDD-HHmm>/` (scratch, gitignored).

Resolve `<branch-name>` from `git branch --show-current` (strip a `worktree-` prefix). Use local-time `YYYYMMDD-HHmm`. Slugify agent names (lowercase, hyphenated). Every path below is relative to `<out>`; always substitute the full resolved path into agent prompts.

```
<out>/
├── CONTEXT.md              # Diff summary, change/plan excerpts, env, scope
├── ROSTER.md               # Final agent list with affinity clusters
├── round1/
│   └── <agent-slug>.md     # One file per agent
├── round2/
│   ├── ASSIGNMENT.md                 # Reviewer-to-author table from Round 1 triage
│   └── <reviewer>__on__<author>.md   # One file per cross-review pair
├── round3/
│   └── <agent-slug>.md     # One file per agent (final findings)
├── SUMMARY.md              # Orchestrator digest, deduplicated, prioritized
└── TASKS.md                # Findings sink (STEP 10)
```

## Workflow

### STEP 1: Interview

Infer first:
- **Scope**: current branch (`git branch --show-current`) and full diff vs `[BASE_BRANCH]` from `CLAUDE.md` (or the base the user named).
- **Change context**: the 10x change for this branch, if any - read `change.md`, `plan.md` (phases, `## Progress`), and `divergence.md` if present. Also scan commits and conversation for references.
- **Environment**: current worktree, running locally as configured (`[RESTART_ENV]` in `CLAUDE.md` if set).

Then use `AskUserQuestion` to confirm and fill gaps. Batch up to 4 questions per call. Cover:

1. **Scope** — confirm what is being reviewed.
2. **Environment** — anything non-standard agents should know.
3. **Risk hotspots** — areas the user wants extra eyes on.
4. **Deprioritize** — areas to skip or treat lightly.
5. **Size** — small (~5 agents), medium (~10-15), or large (20+). Default from diff size.
6. **Confidence policy** (single-select): "Certain only" (drop weaker) or "Allow Likely and Possible with explanation" (keep weaker with a "Why not Certain" note — recommended for thorough reviews where missing a real issue is worse than surfacing a maybe).

### STEP 2: Pre-fetch shared context

Write `<out>/CONTEXT.md` with the small, shared inputs every agent needs. The diff itself does not go here — each agent pulls its own slice.

Include:
- Branch and base (so agents run their own diff/log commands).
- Short category breakdown of changed files (counts per area, e.g. domain / API / UI / migrations / tests / config).
- Change excerpts: intent from `change.md`, the relevant phases from `plan.md`, deviations from `divergence.md` (pointers plus short excerpts).
- Special environment notes from the interview.
- Pointers (not contents) to relevant `.claude/rules/` files and `context/foundation/lessons.md` if it exists.
- Available tooling: which MCP servers are connected in this session, and the project commands from `CLAUDE.md`.

### STEP 3: Co-design the agent roster

Propose a tailored roster from the diff (file paths, commit messages, change context). No fixed catalog.

**Keep scopes open-ended.** The biggest failure mode is the orchestrator confining agents to narrow checklists and missing what the orchestrator did not think of. Name AREAS worth a deep dive — do not pre-investigate them. A one-line scope naming an area and an angle is right. Five lines listing specific classes, files, methods, columns, or outcomes is wrong: it tells the agent what to find instead of letting them discover it.

You do not deeply read code in this step. Agents do.

Guidelines:
- Identify which areas the diff touches and which carry highest risk (domain logic, security, migrations, third-party integrations, concurrency, authorization / data isolation, data consistency, API contracts).
- Propose 3-4 agents per hot area from different angles (e.g. "correctness of the math", "behavior under failure", "what happens during a deploy"), 1-2 on lighter areas.
- Each scope is one line, two at most: "<Area> — <angle / concern>". Examples:
  - "Authentication and session handling — token lifecycle, replay, timing-sensitive checks"
  - "Schema migrations — backwards compatibility and backfill correctness"
- Do NOT enumerate specific classes, methods, files, columns, line numbers, or outcomes in the scope.
- No "general" agents. Every agent has a sharp focus.
- Flag each agent as **high-impact** (yes/no) — areas where false negatives are worse than false positives (security, data loss, privacy, regulatory). High-impact agents may always keep Likely and Possible findings with an uncertainty note, regardless of STEP 1 policy.

Present the roster (name, scope, high-impact flag, subagent type, rationale) and use `AskUserQuestion` to confirm and iterate.

### STEP 4: Co-design review affinities

Cluster the roster into 3-5 affinity clusters (e.g. "Domain Logic", "Integrations", "UI & UX"). Clusters are orchestrator-side hints for Round 2 reviewer selection — never shown to agents, never hard partitions. Round 2 assignment is dynamic and may cross clusters.

Examples (design fresh per review): a domain-heavy review may cluster Domain Logic / Integrations / Code Quality / UI & UX; a security-heavy review may cluster AuthN/AuthZ / Data Exposure / Input Validation / Reliability.

Present clusters with rationale. Confirm via `AskUserQuestion`. Write the final roster + clusters to `<out>/ROSTER.md`.

### STEP 5: Round 1 — Discovery (all agents in parallel)

Launch every agent in **a single message with one Agent tool call per agent**.

Pick the subagent type per scope:
- Area owned by a reviewer agent in the `## Team Roster` section of `CLAUDE.md` (e.g. the `reviewer` of the matching track) → that reviewer agent. Reviewer agents know the project's rules for their area.
- Anything else (cross-cutting security, infra, integration analysis, areas no roster track covers) → `general-purpose`.
- Only if a listed agent type does not exist in `.claude/agents/`, fall back to `general-purpose`.

Explore subagents are for broad code search inside an agent's investigation, not as reviewers themselves.

Each agent's prompt:

```
You are an Ultra Review agent. Your scope is narrow and focused.

THIS IS NOT A NORMAL REVIEW
Not a line-by-line review. Not the validation pass you usually run alongside an engineer. You run solo, in parallel with many peers, against a large branch. Find REAL problems — bugs, defects, risks, design flaws, edge cases that break under load, data corruption paths, security gaps, anything that should not ship. Skip nitpicks, style, surface-level checks. Spend effort on the highest-risk areas of your scope. Round 2 reviewers will try to disprove your findings — commit only to claims you can defend with concrete evidence.

YOUR SCOPE
<scope from roster — 1-2 lines>

OTHER AGENTS WORKING IN PARALLEL
<full roster — name and scope per agent — overlap is expected and welcome>

CONTEXT
Read in order before starting:
1. <out>/CONTEXT.md
2. <out>/ROSTER.md

SHARED ENVIRONMENT
Current worktree, running locally. Use whatever tooling CONTEXT.md lists as available (MCP servers, read-only database access, project commands). Non-standard items: see CONTEXT.md "Special environment notes". Never modify code, data, or git state.

YOUR JOB
Find real problems in your scope. Your scope names an area, not a checklist — the orchestrator deliberately did NOT pre-list classes, files, edge cases, or outcomes. You are the domain expert. Drive your own investigation.

Phase 1 — Discovery (first): read the code and build a mental model (entry points, boundaries, invariants, dependencies). Identify risk — where math is hard, state is mutated, failures cascade, assumptions about external systems live, what is new vs. the existing pattern. Commit to deep-diving the few highest-risk subareas.

Phase 2 — Deep dive (80%): investigate chosen subareas thoroughly. Read every relevant path. Run read-only queries where available. Reproduce edge cases. Verify external assumptions with available MCP tools or web research.

Phase 3 — Sanity scan (20%): sweep the rest of your area lightly. Note anything off that does not merit a deep dive.

Tools: read code, grep/find, Explore subagents (subagent_type=Explore) for broad search, web research, and any MCP tools available in this session. Do not save tokens.

Be specific. Cite file:line. Quote code, query results, and external sources.

OUTPUT
Write findings to: <out>/round1/<your-slug>.md using the template below.
Return ONLY this one-line triage (nothing else):

`DONE: <path> | findings=<N> | critical=<N> | high=<N> | medium=<N> | low=<N> | uncertain=<N> | hottest=<short title or "—">`
(`uncertain` = Likely + Possible. `hottest` = your most concerning finding or `—`. Findings live in the file, never returned as prose.)

TEMPLATE

# Round 1 — <Agent name>

## Scope
<one paragraph — your framing, derived from the code you read>

## Discovery
<area map: entry points, invariants, risky subareas and why. Then the subareas you deep-dived vs. sanity-scanned, one-line reason each.>

## Method
<files read, queries run, sources consulted>

## Findings

### F1: <short title>
**Severity (preliminary):** Critical | High | Medium | Low
**Confidence:** Certain | Likely | Possible
**Location:** <file:line, or "system-wide">
**Description:** <what's wrong>
**Evidence:**
<code snippet, query result, or quoted source>
**Why it matters:** <impact>
**Rough fix idea:** <optional, hand-wavy OK at this stage>
**Open questions:** <what you couldn't verify>

### F2: ... (repeat per finding)

## What you looked at and found clean
<short list — helps Round 2 reviewers calibrate>

## What you couldn't reach
<gaps — areas you couldn't fully assess and why>
```

After launching, wait for all agents. Do not read findings into context. Verify each agent returned a `DONE:` triage line and the file exists. On failure, decide: retry, reassign, or proceed without.

### STEP 6: Triage Round 1 results and build the Round 2 assignment

Use the triage summaries (NOT the full findings) to design the assignment.

Goals:
- Reviewers spend time where signal lives: an author with 0 findings needs one quick sanity check; the most concerning results (multiple Critical/High, or a single alarming "hottest") deserve 6-8 independent reviewers.
- Each reviewer carries ~2-3 reviews; every author gets at least one external reviewer. Top reviewers for hot authors come from the matching affinity cluster but may cross clusters when scope demands.

Heuristic (adjust freely):
- Findings = 0 → 1 reviewer (light sanity check)
- Findings ≤ 3 and no Critical/High → 2 reviewers
- Critical/High findings or a serious "hottest" → 4-8 reviewers, scaled by severity
- +1-2 reviewers if the author is high-impact

Write the explicit reviewer-to-author table (with round1 file paths) to `<out>/round2/ASSIGNMENT.md` before launching Round 2.

### STEP 7: Round 2 — Cross-review (all reviewers in parallel)

Launch all reviewers in **a single message with one Agent tool call per reviewer**. Reuse each reviewer's Round 1 subagent type.

Each reviewer's prompt:

```
You are <Agent X>. In Round 1 you produced findings on your own scope (<scope>). In Round 2 you read a list of peers' findings and try to PROVE THEM WRONG.

THIS IS NOT A NORMAL REVIEW
Adversarial false-positive hunt, not a friendly walkthrough. Skip nitpicks and style. Focus on whether each claim is real, reachable, and at the right severity. Default to skepticism — adversarial confirmation is the strongest signal a finding can get.

YOUR ASSIGNMENT
Review these peers. Use the exact write paths below — do not invent filenames.
- <Author A> (scope: <scope>)
  Read:  <out>/round1/<author-a>.md
  Write: <out>/round2/<your-slug>__on__<author-a>.md
- <Author B>, <Author C>, ... — same pattern, substitute each author's slug.

CONTEXT
CONTEXT.md and ROSTER.md were loaded in Round 1. Re-read only to refresh a specific detail.

YOUR JOB
For each peer:
1. Read their Round 1 file.
2. For each finding, try to invalidate it independently. Look at the code yourself. Run read-only queries. Spawn Explore subagents. Use web research and available MCP tools. Quote counter-evidence.
3. Write your critique to the exact path above, using the template.

You are an adversary, not a cheerleader. Severity inflation is a false positive. Common false positives: missing context the author overlooked, framework guarantees the author missed, issue exists but is unreachable in practice, two different code paths conflated. When you can confirm a finding, say so plainly with reproduced evidence.

OUTPUT
One file per peer. When all done, return: "DONE: reviewed <N> peers".

TEMPLATE (one per peer)

# Round 2 — <Your name> reviewing <Author name>

Author findings file: <path>

## Verdicts

### On <Author>'s F1: <title>
**Verdict:** Confirmed | Confirmed but severity wrong | Partial — <what holds> | False positive | Cannot verify
**Counter-evidence / corroboration:**
<what you found in the code, data, or online>
**Suggested severity:** Critical | High | Medium | Low
**Notes:** <anything the author missed or got wrong>

### On <Author>'s F2: ... (repeat per finding)

## Findings the author missed (in their scope)
<optional — additional issues your research surfaced>
```

Wait for all reviewers. Verify all critique files exist.

### STEP 8: Round 3 — Final findings + implementations (all agents in parallel)

Each Round 1 agent produces their final document, taking critiques into account. Launch in parallel, reusing each agent's original subagent type.

Each agent's prompt:

```
You are <Agent X>. You wrote round1/<your-slug>.md and peers critiqued each finding in round2/*__on__<your-slug>.md. In Round 3 you finalize.

THIS IS NOT A NORMAL REVIEW
Finalization pass. Decide which Round 1 findings survive adversarial critique and are real enough to act on. Drop weak claims. Strengthen survivors with evidence and concrete implementation. Severity reflects impact, not how hard the finding was to find.

CONTEXT
CONTEXT.md and ROSTER.md were loaded earlier; re-read only to refresh. Read:
- <out>/round1/<your-slug>.md
- All critiques at <out>/round2/*__on__<your-slug>.md

CONFIDENCE POLICY
- Default policy: <"Certain only" or "Allow Likely and Possible with explanation" — from STEP 1>
- High-impact agent: <yes / no — from roster>

Confidence is categorical: Certain (verified, reproducible), Likely (strong evidence, one step short), Possible (plausible, not verified).
- "Certain only" and NOT high-impact: drop anything weaker than Certain.
- "Allow Likely and Possible" OR high-impact: keep Likely/Possible findings, each with a "Why not Certain" note stating the gap. Better to surface a possible issue than drop it.

YOUR JOB
For each Round 1 finding:
1. Read the critiques.
2. Do more research as needed: read more code, run more read-only queries, Explore subagents, web research, MCP tools.
3. Decide: KEEP at Critical/High/Medium with a confidence level, DOWNGRADE, or DROP — per policy.
4. Severity reflects impact, not confidence. A Certain Medium is fine. A Likely/Possible finding with a "Why not Certain" note is fine when policy permits.
5. For each kept finding, write a CONCRETE implementation: code, queries, migrations, config — whatever applies. Make a future engineer's job nearly mechanical.
6. Add new findings if your additional research surfaced any, under the same policy.

OUTPUT
Write to <out>/round3/<your-slug>.md using the template.

Return only: "DONE: <path>".

TEMPLATE

# Round 3 — <Agent name> — Final

## Scope (recap)
<one line>

## Critical (must fix before merge)

### C1: <title>
**Location:** <file:line>
**Confidence:** Certain | Likely | Possible
**Description:** <what's wrong>
**Evidence:**
<code, query result, source>
**Why critical:** <user impact, data corruption, security exposure, regulatory, etc.>
**Round 2 critiques addressed:**
- <Reviewer X>: <what they said, how you resolved it>
**Why not Certain** (only when Likely or Possible): <what's missing, what would close the gap>
**Implementation:**
<concrete change — code, migration, config>
**Test:** <how to verify the fix>

### C2: ...

## High (should fix before merge) / ## Medium (worth considering)
Same template. Medium: only findings the policy permits.

## Dropped findings (from Round 1)
- F-X: <title> — Dropped because <reason, citing reviewer or own re-investigation>

## Notes for the orchestrator
<known overlaps with other agents' scopes, etc.>
```

Wait for all agents.

### STEP 9: Round 4 — Orchestrator digest

Read every `round3/*.md` file. This is the only point findings enter your context.

Produce `<out>/SUMMARY.md`:

```markdown
# Ultra Review — <timestamp>

**Scope:** <branch / diff range>
**Agents:** <N> (<G> affinity clusters)
**Change context:** <context/changes/<change-id>/ or "none">

## Critical (must fix before merge)

### C1: <consolidated title>
**Raised by:** <agent-a>, <agent-b>  *(independent confirmation)*
**Location:** <file:line>
**Summary:** <consolidated description>
**Why critical:** <impact>
**Implementation:**
<best implementation across agents — pick the most concrete and complete>
**Test:** <how to verify>
**Source files:** round3/<agent-a>.md, round3/<agent-b>.md

### C2: ...

## High / ## Medium
Same structure as Critical. Medium can be terser.

## Dropped during review
(one line each — raised in Round 1, dropped after critique. Audit trail.)

## Coverage map
Table: Area | Agent(s).

## Notable disagreements between agents
<short list — Round 2 critiques that flipped severity or dropped findings, especially the interesting ones>
```

Deduplication rules:
- Two agents at the same location → merge. Note both under "Raised by". Independent confirmation is strong signal — call it out, and bump confidence one level if both are Likely (two independent Likelys ≈ Certain).
- Disagreement on severity → take the higher (carry its uncertainty note if below Certain). Disagreement on implementation → prefer the more concrete one, note the alternative.
- Likely/Possible findings → preserve the "Why not Certain" note in the summary.

### STEP 10: Present + write findings sink

**Autonomous mode:** skip presentation. Write `<out>/TASKS.md` (format below) and return its path to the caller. Done.

**Interactive mode:** present `SUMMARY.md` in chat — Critical first, then High, then a one-line list of Medium titles. Do not paste Medium implementations unless asked. Wait for the user (discuss, won't-fix, reprioritize, deeper investigation).

Once satisfied, write `<out>/TASKS.md` with one row per Critical, High, and Medium the user did not reject. Then `AskUserQuestion`:
- Turn TASKS.md into a new 10x change — run `/10x-new` with a change-id such as `<branch-or-change-id>-review-fixes` and the TASKS.md path as intent, so it flows through `/10x-plan` like any other change
- Let me select which findings go into the new change (then run `/10x-new` with only those)
- Keep TASKS.md only — handle manually

If the review ran against an existing change and the fixes must land before that change merges, mention that the user may prefer to record the fixes as a deviation in `context/changes/<change-id>/divergence.md` and extend its plan instead - but never edit `plan.md` or `divergence.md` without an explicit ask.

### TASKS.md format

```markdown
# Ultra Review Tasks — <timestamp>

<one-line summary>. Full per-agent reports in `round3/`. Consolidated digest in `SUMMARY.md`.

**Merge blockers:** <comma-separated IDs of Critical + High>.

## Tally
- Critical: <N> (<IDs>)
- High: <N> (<IDs>)
- Medium: <N>
- Low / Nit: <N>

## Tasks

| ID | Status | Severity | Title | Files | Fix size | Source |
| --- | --- | --- | --- | --- | --- | --- |
| C-1 | ⏳ Open | Critical | <title> | <file:line, ...> | <~lines or n/a> | <agent-slug> |
| H-1 | ⏳ Open | High | ... | ... | ... | ... |

ID format: `<severity>-<index>` where severity is `C` (Critical), `H` (High), `M` (Medium), `L` (Low), `N` (Nit).

Status values (mirror the standard task lifecycle):
- `⏳ Open` — initial, not yet picked up
- `🔧 In progress` — engineer is working on the fix
- `👀 In review` — reviewer has it
- `✅ Done (<commit>)` — committed
- `🚫 Blocked — <reason>` — needs user input or external access

## Details

### C-1 — <title>
**Why**: <root cause>.
**Blast radius**: <impact>.
**Fix**: <concrete change>.
**Rule citation** (when applicable): <path>.

### H-1 — ...
```

## Guidelines

DO:
- Co-design roster and clusters with the user every time. Tailor to the diff.
- Launch each round in a single parallel message.
- Make agents write findings to disk and return only `DONE:` lines. Never return findings as text.
- Read agent outputs only at digest time (Round 4).
- Be specific in agent prompts — "review for security" is too vague; "review every new endpoint and handler for missing authorization checks on the resource owner" is right.

DON'T:
- Use a fixed agent catalog. Every review is custom.
- Cap agent count arbitrarily. Match the change.
- Let agents coordinate or split work mid-flight.
- Treat overlap as wasted work. Overlap is signal.
- Read agent findings into context before Round 4.
- Create a new change (`/10x-new`) before presenting findings to the user and getting approval.
- Commit, push, or amend anything. Findings are the output. Fixes are a separate workflow.
