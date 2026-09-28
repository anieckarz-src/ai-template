# ai-template

Mój zestaw konfiguracji Claude Code do każdego projektu: workflow 10x (research → plan → implement → review), hooki pilnujące jakości, skille do commitów i PR-ów, agenci implementer/reviewer oraz opcjonalny zespół agentów. Kopiujesz ręcznie to, czego potrzebujesz.

```
core/          → zawsze, do roota projektu (dowolny stos)
packs/dotnet/  → dodatkowo w projektach .NET
team/          → opcjonalnie: pełny tryb zespołu agentów (eksperymentalny)
```

## 1. Setup w dowolnym projekcie (5 minut)

1. Skopiuj **zawartość** `core/` do roota projektu:
   ```powershell
   Copy-Item -Recurse -Force C:\Projects\ai-template\core\.claude  <projekt>\
   Copy-Item C:\Projects\ai-template\core\CLAUDE.md <projekt>\      # jeśli projekt ma już CLAUDE.md – scal ręcznie
   ```
2. Dopisz do `.gitignore` projektu zawartość `core/.gitignore.snippet` (`.workspace/`).
3. Otwórz `CLAUDE.md` i uzupełnij wszystkie `TODO` – najważniejsza jest sekcja **Project Commands** (`BUILD`, `TEST`, `FORMAT`, `LINT`). Z tych wartości korzystają wszyscy agenci i skille.
4. W `.claude/hooks/blocked-commands.sh` dopisz komendy, których agent nie powinien odpalać w tym repo.
5. Uruchom w projekcie `claude` i wykonaj `/10x-init` (tworzy `context/`).

Wymagania: Git Bash (hooki to skrypty bash; na Windowsie Claude Code uruchamia je przez Git Bash). `jq` **nie** jest potrzebne.

## 2. Projekt .NET

Po kroku 1 dodatkowo:
```powershell
Copy-Item -Recurse -Force C:\Projects\ai-template\packs\dotnet\.claude <projekt>\
```
Następnie wklej do `CLAUDE.md` sekcje z `packs/dotnet/CLAUDE.dotnet.md` (zastępują **Project Commands** i **Team Roster**).

Reguły z `.claude/rules/dotnet/optional-architecture/` (CQRS, DDD, strongly typed IDs) zostaw tylko, jeśli projekt faktycznie tak jest zbudowany – w przeciwnym razie usuń ten katalog.

## 3. Jak pracować na co dzień

| Sytuacja | Komenda |
|---|---|
| Nowa zmiana / feature / bug | `/10x-new` → `/10x-research` → `/10x-plan` → `/10x-plan-review` |
| Implementacja planu | `/10x-implement` (lub `/10x-tdd`, `/10x-e2e`; bez nadzoru: `/10x-goal-implement`) |
| Review implementacji vs plan | `/10x-impl-review` |
| Głęboki review przed merge | napisz „ultra review” |
| Commit / PR | „commit”, „create pull request” |
| Stara gałąź z konfliktami | skill `rebuild-branch` |
| Padające testy E2E | skill `fix-e2e-tests` |
| Zakończona zmiana | `/10x-archive` |
| Wejście w nowy projekt | `/10x-stack-assess`, `/10x-health-check`, `/10x-agents-md` |
| Powtarzający się błąd agenta | `/10x-lesson` |

### Tryb prosty (domyślny) – subagenci

Agenci `implementer` i `reviewer` (w .NET: `backend` i `backend-reviewer`) działają jak zwykli subagenci. Możesz poprosić wprost: *„użyj agenta backend do fazy 2 planu, potem backend-reviewer”*. Tani i przewidywalny – zacznij od tego.

### Tryb pełny – zespół agentów

`team-lead` koordynuje, inżynierowie i reviewerzy pracują równolegle, `guardian` jako jedyny commituje, `architect` pilnuje planu. Instrukcja: [`team/README.md`](team/README.md).

## Co robią hooki (`core/.claude/settings.json`)

| Hook | Działanie |
|---|---|
| `blocked-commands.sh` | blokuje wskazane komendy (domyślnie force-push i `git reset --hard`) |
| `pre-tool-use-excuse-check.sh` / `stop-excuse-check.sh` | gdy agent tłumaczy błąd jako „pre-existing”, dostaje przypomnienie, że ma go naprawić |
| `post-tool-use-bash.sh` | po `git commit` przypomina, że commity tylko na wyraźne polecenie |
| `check-interrupt.sh` | dostarcza przerwania w trybie zespołu (`team-interrupt`) |

`settings.json` zawiera tylko bezpieczną allowlistę komend git/gh do odczytu. **Nie** używaj `--dangerously-skip-permissions` w repo w pracy – dopisz potrzebne komendy (np. `Bash(dotnet build:*)`) do `permissions.allow`.

## Pochodzenie

- Skille `10x-*` – kurs 10xDevs 3.0 (odchudzone do codziennej pracy, odcięte od `10x sync`).
- Hooki, `commit`, `create-pull-request`, `ultra-review`, `rebuild-branch`, `fix-e2e-tests`, agenci i reguły .NET – zaadaptowane z [PlatformPlatform](https://github.com/platformplatform/PlatformPlatform) (MIT), bez zależności od ich `developer-cli`, Aspire i Azure.
