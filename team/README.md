# team/ — pełny tryb zespołu agentów

Opcjonalny dodatek do ai-template. Zamiast jednej sesji, która implementuje plan (`/10x-implement`), uruchamiasz **team-leada**, który prowadzi jedną zmianę (`context/changes/<change-id>/plan.md`) faza po fazie zespołem równoległych agentów:

- **team-lead** — koordynator. Nigdy nie pisze kodu; planuje, spawnuje agentów, pilnuje cyklu życia.
- **architect** — trzyma `plan.md` w zgodzie z rzeczywistością: czyta `divergence.md` po każdej fazie, aktualizuje nadchodzące `## Phase N`, dopisuje nowe kroki zgodnie z kontraktem Progress.
- **guardian** — jedyny, kto stage'uje, commituje, restartuje środowisko i odhacza wiersze Progress (`- [x] ... — <sha>`). Zero tolerancji dla czerwonych testów.
- **researcher** — research API/bibliotek (Perplexity/Context7 MCP jeśli są, inaczej WebSearch/WebFetch).
- **pary engineer + reviewer** na każdy track z `## Team Roster` w `CLAUDE.md`, świeże na każdą fazę (np. `implementer-<change-id>-p2` + `reviewer-<change-id>-p2`).

Wykorzystuje eksperymentalne Agent Teams w Claude Code (TeamCreate, SendMessage, wspólny TaskList, config w `~/.claude/teams/<team>/config.json`).

## Wymagania

1. Najpierw skopiowany **`core/`** (CLAUDE.md z wypełnionymi `## Project Commands` i `## Team Roster`, skille 10x, skill `team-interrupt`, skill `ultra-review`, hook `check-interrupt.sh` i `.claude/scripts/send-interrupt.sh`).
2. Agenci engineer/reviewer dla każdego tracku z rostera — albo domyślni `implementer` + `reviewer` z core, albo z packa (np. .NET: `backend: backend + backend-reviewer`).
3. Skopiuj `team/.claude/agents/*.md` do `.claude/agents/` projektu.
4. Zmerguj `settings.team.snippet.json` do `.claude/settings.json` (klucz `env`). To włącza Agent Teams na stałe dla projektu; alternatywnie ustawiaj zmienną tylko przy uruchomieniu (niżej).

## Uruchomienie

PowerShell:

```powershell
$env:CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="1"; claude --agent team-lead
```

bash / Git Bash:

```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --agent team-lead
```

W pierwszej wiadomości podaj change-id (np. `Run add-invoices`). Bez niego team-lead wylistuje `context/changes/` i zapyta. Nazwa zespołu = bieżący branch git.

`team-lead` to agent najwyższego poziomu — nie wywołuj go jako sub-agenta.

## Typowy przepływ

1. `/10x-new` — utwórz zmianę
2. `/10x-plan` — plan z fazami i sekcją `## Progress`
3. `/10x-plan-review` — przegląd planu
4. `claude --agent team-lead` z change-id — team-lead przedstawia plan zespołu, czekasz na akceptację, potem zespół pracuje autonomicznie
5. Na końcu: architect final review → autonomiczny ultra-review i poprawki → raport (w tym wiersze `#### Manual` do ręcznej weryfikacji)
6. `/10x-impl-review`, PR, `/10x-archive`

## Ostrzeżenia

- **Koszt.** Kilka-kilkanaście równoległych sesji (persistent + para na każdy track w fazie, okno dwóch faz). Zużycie tokenów wielokrotnie wyższe niż `/10x-implement`. Do małych zmian używaj trybu prostego.
- **Funkcja eksperymentalna.** API Agent Teams może się zmienić bez ostrzeżenia; po restarcie Claude Code procesy agentów giną (team-lead ma procedurę Session Recovery, ale nie odtwarza zespołu bez twojej zgody).
- **Nie używaj `--dangerously-skip-permissions`** w repozytoriach roboczych. Zamiast tego dodaj allowlistę w `permissions.allow` w `.claude/settings.json` (komendy z `## Project Commands`, `git add`, `git commit`, `git status`, `git diff`, `bash .claude/scripts/send-interrupt.sh`).
- **Guardian commituje sam** w trakcie sesji — uruchomienie team-leada na zmianie traktuj jako zgodę na commity tej zmiany. Push, amend, rebase tylko na twoje wyraźne polecenie.
- **Hooki na Windows wymagają Git Bash** (`check-interrupt.sh`, `send-interrupt.sh`). Bez `bash` w PATH przerwania (interrupts) nie działają.
