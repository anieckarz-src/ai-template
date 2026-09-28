# .NET pack: CLAUDE.md blocks

> Paste these into your project's `CLAUDE.md`: they **replace** the `## Project Commands` and `## Team Roster` sections and **add** a `## .NET Notes` section (put it after `## Project Overview`).

## Project Commands

Whenever you see `[BUILD]`, `[TEST]`, `[FORMAT]`, `[LINT]`, `[RESTART_ENV]`, `[SMOKE]` or `[E2E]` in agents, skills, or rules, replace it with the value configured here. An empty value means "not available in this project - skip that step".

```
BUILD="dotnet build"                          # add the solution path if it is not in the repo root, e.g. dotnet build src/MyApp.slnx
TEST="dotnet test --no-build"                 # run after BUILD; add --filter for a subset
FORMAT="dotnet format"                        # applies .editorconfig style and analyzer fixes
LINT="dotnet format --verify-no-changes"      # fails if FORMAT would change anything
RESTART_ENV=""                                # e.g. docker compose up -d --force-recreate
SMOKE=""                                      # e.g. curl -fsS http://localhost:5000/health
E2E=""                                        # e.g. npx playwright test
BASE_BRANCH="main"
```

Run `[BUILD]` first, then `[FORMAT]`, `[LINT]`, and `[TEST]`. `[FORMAT]` rewrites files, so run `[LINT]` after it, not in parallel.

## Team Roster

Used by the `implementer`/`reviewer` agents (simple mode) and by `team-lead` (full agent-team mode). One line per track: `track: engineer-agent + reviewer-agent`.

```
TRACKS:
  backend: backend + backend-reviewer
  default: implementer + reviewer
```

## .NET Notes

Rules for C#, tests, EF Core migrations, and integrations live in `.claude/rules/dotnet/`. Files in `.claude/rules/dotnet/optional-architecture/` (CQRS, DDD, strongly typed IDs) apply only if the project uses those patterns; delete the ones that don't apply.

TODO: fill in, then delete this line.

- [ ] Solution file: `TODO: path/to/MyApp.sln(x)`
- [ ] Target framework / SDK: `TODO: net8.0 / net9.0` (pinned in `global.json`? yes/no)
- [ ] Project layout: `TODO: e.g. src/MyApp.Api (host), src/MyApp.Core (domain + features), src/MyApp.Infrastructure (EF Core)`
- [ ] Test projects: `TODO: e.g. tests/MyApp.Tests`, naming `[Project].Tests`, xUnit + `TODO: FluentAssertions/Shouldly` + NSubstitute + Bogus
- [ ] Test database: `TODO: SQLite in-memory / Testcontainers / dedicated test DB`
- [ ] Nullable reference types enabled (`<Nullable>enable</Nullable>`) in all projects: `TODO: yes/no`
- [ ] Warnings as errors (`<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`), analyzers configured in `Directory.Build.props`: `TODO: yes/no`
- [ ] Central package management (`Directory.Packages.props`): `TODO: yes/no`
- [ ] EF Core migrations: `TODO: generated with dotnet ef (project: ..., startup project: ...) / hand-written`; database provider: `TODO: PostgreSQL / SQL Server / SQLite`
- [ ] Architecture patterns in use (keep only matching optional rules): `TODO: CQRS + MediatR? DDD aggregates? strongly typed IDs?`
- [ ] Local environment: `TODO: how to run the app and its dependencies (docker compose, user secrets, ...)`
