# PlatformPlatform – surowe pliki AI (referencja)

Niezmienione kopie wszystkich plików związanych z AI z [platformplatform/PlatformPlatform](https://github.com/platformplatform/PlatformPlatform) @ `bcf283bb6` (licencja MIT, zob. `LICENSE`). Pliki odwołują się do ich `developer-cli`, Aspire i Azure – przed użyciem w innym projekcie trzeba je dopasować.

| Ścieżka | Co to jest |
|---|---|
| `AGENTS.md` | główne instrukcje dla agentów (`.claude/CLAUDE.md` jest pusty – Claude czyta AGENTS.md) |
| `.mcp.json` | serwery MCP: shadcn, Aspire, Azure (staging/production, read-only) |
| `.claude/settings.json` | hooki, env, pluginy (LSP C#/TS, Stripe) |
| `.claude/hooks/` | skrypty hooków |
| `.claude/agents/` | 12 agentów zespołu (team-lead, guardian, architect, backend/frontend/qa + reviewerzy, regression-tester, researcher, pair-programmer) |
| `.claude/skills/` | 23 skille (build/test/format/lint, commit, PR, ultra-review, e2e, rebrand, …) |
| `.claude/rules/` | reguły kodowania: backend (.NET), frontend (React), E2E, infrastruktura, developer-cli, ai-rules |
| `.claude/reference/` | integracje z narzędziami PM (Linear, Jira, Azure DevOps, Markdown) i przykładowe PRD/plany |
| `developer-cli/Commands/*` | kod C# ich CLI: uruchamianie agentów (`claude-agent`), sygnały przerwań, konfiguracja MCP, synchronizacja reguł do innych edytorów |
