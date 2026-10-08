# Katalog Claude Workflow — skille, agenci, komendy

Minimalna baza pod backend: jeden workflow developerski, standardy projektu i jedno review.
Bez UI, mockupów, Playwrighta, dashboardu i raportów HTML. Wszystkie artefakty to markdown w `.claude-workflow/`.

## Jak to działa w skrócie

- **Komendy** (`/wf-...`) to punkty wejścia dla użytkownika.
- **`/wf-dev`** jest jedynym orkiestratorem. Prowadzi zadanie fazami, zapisuje stan w
  `.claude-workflow/tasks/development/RRRR-MM-DD-nazwa/orchestrator-state.yml`, po istotnych fazach
  zatrzymuje się na bramkach (pytanie do użytkownika) i daje się wznowić (`--from=FAZA`).
  Zasady pracy orkiestratora są w `skills/wf-dev/references/workflow-rules.md`.
- **Skille wewnętrzne** to silniki, które development i init wywołują same.
- **Agenci (subagenci)** to wyspecjalizowani wykonawcy, uruchamiani przez skille. Ręcznie wołasz
  tylko reviewera, przez `/wf-review`.
- **Dokumentacja projektu** leży w `.claude-workflow/docs/` (INDEX.md, project/, standards/). Tworzy ją
  `/wf-init`, a workflow czytają z niej standardy kodowania.

---

## 1. Komendy

| Komenda | Co robi |
|---------|---------|
| `/wf-init [--standards-from=PATH]` | Inicjalizuje framework w projekcie. Analizuje kod (`wf-project-analyzer`), generuje `.claude-workflow/docs/` (vision, roadmap, tech-stack, architektura), wgrywa bazowe standardy (global / backend / testing) albo kopiuje je z innego projektu, a do CLAUDE.md dopisuje regułę czytania dokumentacji przed zmianami. |
| `/wf-dev "opis"` | Workflow do każdej zmiany w kodzie: bugfix (z bramkami TDD), rozszerzenie, nowa funkcja, poprawa wydajności, migracja wersji lub technologii. Fazy opisuje sekcja 2. |
| `/wf-quick-plan "opis"` | Lekka ścieżka: przechodzi w tryb planowania Claude Code, dobiera pasujące standardy z INDEX.md i dopisuje do planu checklistę zgodności ze standardami. Nie tworzy plików zadania ani faz. |
| `/wf-review [ścieżka \| katalog zadania] [--focus=...]` | Jedno review w trzech częściach: (A) jakość i bezpieczeństwo, (B) przekombinowanie i możliwe uproszczenia, (C) gotowość produkcyjna z werdyktem GO / NO-GO. `--focus=quality\|simplicity\|production` zawęża zakres. Raport trafia do `.claude-workflow/reviews/RRRR-MM-DD-review.md` albo do `verification/` zadania. |
| `/wf-standards-discover [--scope=...]` | Wykrywa standardy, które projekt już stosuje. Równolegle przegląda 4 źródła: pliki konfiguracyjne, wzorce w kodzie, dokumentację oraz PR-y i CI. Pokazuje wyniki z oceną pewności do akceptacji i zapisuje zatwierdzone do `.claude-workflow/docs/standards/`. |
| `/wf-standards-update "opis" [--from=PATH]` | Dodaje lub zmienia standard na podstawie opisu albo bieżącej rozmowy (np. „zawsze paginuj endpointy listujące”). Z `--from` synchronizuje standardy z innego projektu. |

---

## 2. `/wf-dev` — fazy

| Faza | Co się dzieje |
|------|---------------|
| 1. Codebase Analysis | Równoległa analiza kodu (`wf-codebase-analyzer`) i pytania doprecyzowujące |
| 2. Gap Analysis | `wf-gap-analyzer` porównuje stan obecny z docelowym i wykrywa cechy zadania (np. czy błąd jest reprodukowalny, czy zmienia się istniejący kod) |
| 3. TDD Red Gate | Tylko przy błędach: test, który reprodukuje defekt i nie przechodzi |
| 5. Requirements & Spec | Wymagania (konsumenci API, kontrakty, integracje), potem `wf-specification-creator` pisze `spec.md` |
| 6. Spec Audit | Zalecany przy złożonych zadaniach (`wf-spec-auditor`) |
| 7. Implementation Planning | `wf-implementation-planner` dzieli pracę na grupy zadań z testami i zależnościami |
| 8. Implementation | `wf-implementation-plan-executor` wykonuje plan falami, równolegle tam, gdzie się da |
| 9. TDD Green Gate | Tylko przy błędach: test z fazy 3 musi teraz przechodzić |
| 10. Verification Options | Wybór: code review (zalecane) i reality check |
| 11. Verification | `wf-implementation-verifier` i pętla poprawek, którą zatwierdza użytkownik |
| 14. Finalization | Podsumowanie, uzgodnienie artefaktów i zamknięcie zadania |

Numery 4, 12 i 13 są wolne, bo te fazy (mockupy UI, E2E, dokumentacja ze screenshotami) wycięliśmy.
Pozostałych faz nie przenumerowałem, żeby nie psuć odwołań między plikami.

Flagi: `--from=FAZA` (wznowienie od wskazanej fazy), `--reset-attempts`, `--sequential` (grupy implementacji jedna po drugiej).

---

## 3. Skille wewnętrzne

| Skill | Kto woła | Co robi |
|-------|----------|---------|
| `wf-codebase-analyzer` | development (faza 1) | Analizuje kod równoległymi agentami Explore. Role dobiera do zadania: File Discovery, Code Analysis, Context Discovery, Pattern Mining. Wyniki scala `wf-codebase-analysis-reporter`. |
| `wf-implementation-plan-executor` | development (faza 8) | Wykonuje `implementation-plan.md`: z zależności wylicza fale, każdą grupę deleguje do `wf-task-group-implementer`, odhacza kroki, prowadzi `work-log.md` i doczytuje standardy według słów kluczowych. |
| `wf-implementation-verifier` | development (faza 11) | Weryfikuje bez zmian w kodzie. Najpierw testy (`wf-test-suite-runner`), potem równolegle kompletność (`wf-implementation-completeness-checker`), review (`wf-code-reviewer`) i opcjonalnie reality check (`wf-reality-assessor`). Wszystko składa w raport weryfikacyjny. |
| `wf-docs-manager` | init, standards-* (przez `wf-docs-operator`) | Operacje na `.claude-workflow/docs/`: tworzenie plików, generowanie INDEX.md, integracja z CLAUDE.md. Zawiera bazowe standardy i szablony. |

---

## 4. Agenci (12)

| Agent | Kto woła | Co robi |
|-------|----------|---------|
| `wf-project-analyzer` | init | Wykrywa stack, architekturę i konwencje projektu na potrzeby dokumentacji. Działa na modelu haiku. |
| `wf-docs-operator` | init, standards-* | Wykonuje operacje `wf-docs-manager` i wraca do wywołującego workflow. |
| `wf-codebase-analysis-reporter` | codebase-analyzer | Scala wyniki agentów Explore w jeden raport: usuwa duplikaty, łączy kod z testami, ocenia ryzyko. |
| `wf-gap-analyzer` | development (faza 2) | Analiza luk: wpływ na konsumentów API i cykl życia danych (np. dane zapisywane, ale nigdzie nieodczytywane). Sprawdza 3 warstwy: istnieje → podpięte (DI/routing) → osiągalne dla konsumenta. |
| `wf-specification-creator` | development (faza 5) | Pisze `spec.md` z gotowych wymagań: wyszukuje kod do ponownego użycia i sprawdza pokrycie wymagań. |
| `wf-spec-auditor` | development (faza 6) | Niezależny audyt specyfikacji: kompletność, niejednoznaczności, sprzeczności, wykonalność. |
| `wf-implementation-planner` | development (faza 7) | Dzieli spec na grupy zadań (baza, domena/serwis, API, integracje, testy) z podejściem test-first, zależnościami i kryteriami akceptacji. |
| `wf-task-group-implementer` | plan-executor | Realizuje jedną grupę zadań: testy, kod, uruchomienie testów, raport. Destrukcyjne komendy git blokuje mu hook. |
| `wf-test-suite-runner` | verifier | Uruchamia cały zestaw testów, kategoryzuje błędy i wskazuje regresje w niezwiązanych obszarach. |
| `wf-implementation-completeness-checker` | verifier | Sprawdza, czy plan jest wykonany (zagląda kontrolnie do kodu), czy kod jest zgodny ze standardami i czy dokumentacja zadania jest kompletna. |
| `wf-code-reviewer` | verifier, `/wf-review` | Review w trzech częściach: jakość i bezpieczeństwo, przekombinowanie, gotowość produkcyjna. Werdykt GO / NO-GO. |
| `wf-reality-assessor` | verifier (opcjonalnie) | Sprawdza, czy praca naprawdę rozwiązuje problem end-to-end: deklarowane vs faktyczne wykonanie, ścieżki błędów, integracje. |

---

## 5. Hooki (`.claude/settings.json`)

| Zdarzenie | Skrypt | Co robi |
|-----------|--------|---------|
| SessionStart | `skill-invocation-reminder.sh` | Przypomina, żeby `/wf-*` zawsze wykonywać przez skill i zatrzymywać się na każdej bramce faz. |
| SessionStart (po kompaktowaniu) | `post-compact-reminder.sh` | Jeśli istnieje `.claude-workflow/tasks`, każe odczytać `orchestrator-state.yml` i wznowić od właściwej fazy. |
| PreToolUse (Bash, PowerShell) | `block-destructive-commands.sh` | Subagentom (poza `wf-test-suite-runner` i `wf-docs-operator`) blokuje `git stash`, `reset --hard`, `checkout .`, `restore .`, `clean`, `push --force`, `rm -rf`, `Remove-Item -Recurse`, `rd /s` i `del /s`. Główny agent nie jest ograniczany. |

---

## 6. Co powstaje w projekcie

```
.claude-workflow/
├── docs/                    # tworzy /wf-init
│   ├── INDEX.md             # mapa dokumentacji i standardów — czytana na starcie workflow
│   ├── project/             # vision, roadmap, tech-stack, architecture
│   └── standards/           # global/, backend/, testing/
├── tasks/development/RRRR-MM-DD-nazwa/
│   ├── orchestrator-state.yml   # stan workflow (źródło prawdy przy wznawianiu)
│   ├── analysis/                # analiza kodu, gap analysis, requirements.md
│   ├── implementation/          # spec.md, implementation-plan.md, work-log.md
│   └── verification/            # raporty weryfikacji i review
└── reviews/                 # raporty z /wf-review
```
