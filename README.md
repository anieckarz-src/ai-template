# ai-template

Surowe, niezmienione materiały AI (konfiguracja Claude Code) z dwóch źródeł – do przeglądania i wybierania, co przenieść do własnych projektów.

| Katalog | Źródło | Zawartość |
|---|---|---|
| [`10x/`](10x/) | kurs 10xDevs 3.0 – `npx @przeprogramowani/10x-cli sync --all` (stan po wszystkich 28 lekcjach) | `.claude/skills/`: wszystkie 30 skilli (`10x-*`, `pack-init`, `setup-cicd`, `tf-registry`). Materiały lekcyjne (prompty, szablony, reguły lekcji) pominięte – w razie potrzeby pobierzesz je tym samym CLI |
| [`platform-platform/`](platform-platform/) | [platformplatform/PlatformPlatform](https://github.com/platformplatform/PlatformPlatform) @ `bcf283bb6` (MIT) | cały `.claude/` (agenci, skille, reguły, hooki, referencje, `settings.json`), `AGENTS.md`, `.mcp.json`, kod AI z ich `developer-cli` – opis w [`platform-platform/README.md`](platform-platform/README.md) |
| [`claude-workflow/`](claude-workflow/) | własny zestaw pod backend .NET | gotowy `.claude/` (skille, agenci, komenda `/wf-review`, hooki w `settings.json`): workflow spec → plan → implementacja → weryfikacja, standardy projektu i review. Kopiujesz cały `.claude/` (+ `.gitattributes`); dane trafiają do `.claude-workflow/` w projekcie. Opis w [`claude-workflow/KATALOG.md`](claude-workflow/KATALOG.md) |

## Jak użyć w projekcie

Skopiuj wybrane elementy do `.claude/` projektu, np.:

```powershell
Copy-Item -Recurse C:\Projects\ai-template\10x\.claude\skills\10x-plan  <projekt>\.claude\skills\
Copy-Item -Recurse C:\Projects\ai-template\platform-platform\.claude\skills\ultra-review  <projekt>\.claude\skills\
```

Pliki z `platform-platform/` odwołują się do ich `developer-cli`, Aspire i Azure – przed użyciem trzeba je dopasować do swojego projektu.

Licencje i pochodzenie: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
