# ai-template

Surowe, niezmienione materiały AI (konfiguracja Claude Code) z dwóch źródeł – do przeglądania i wybierania, co przenieść do własnych projektów.

| Katalog | Źródło | Zawartość |
|---|---|---|
| [`10x/`](10x/) | kurs 10xDevs 3.0 – `npx @przeprogramowani/10x-cli sync --all` (wszystkie 28 lekcji, m0l0–m5l5) | `.claude/skills/` (30 skilli `10x-*`, `pack-init`, `setup-cicd`, `tf-registry`), `.claude/prompts/` (30 promptów z lekcji), `.claude/config-templates/` (5 szablonów z m5l4), `CLAUDE.md` (blok reguł kursu), manifest CLI |
| [`platform-platform/`](platform-platform/) | [platformplatform/PlatformPlatform](https://github.com/platformplatform/PlatformPlatform) @ `bcf283bb6` (MIT) | cały `.claude/` (agenci, skille, reguły, hooki, referencje, `settings.json`), `AGENTS.md`, `.mcp.json`, kod AI z ich `developer-cli` – opis w [`platform-platform/README.md`](platform-platform/README.md) |

## Jak użyć w projekcie

Skopiuj wybrane elementy do `.claude/` projektu, np.:

```powershell
Copy-Item -Recurse C:\Projects\ai-template\10x\.claude\skills\10x-plan  <projekt>\.claude\skills\
Copy-Item -Recurse C:\Projects\ai-template\platform-platform\.claude\skills\ultra-review  <projekt>\.claude\skills\
```

Pliki z `platform-platform/` odwołują się do ich `developer-cli`, Aspire i Azure – przed użyciem trzeba je dopasować do swojego projektu.

Licencje i pochodzenie: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
