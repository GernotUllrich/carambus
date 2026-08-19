---
phase: 40-mcp-server-clubcloud
plan: "06"
subsystem: mcp
tags: [mcp, tests, e2e, setup-docs, capistrano, d-16, d-09, d-17]

requires:
  - 40-01 (bin/mcp-server, Server.build, BaseTool, CcSession, MockClient)
  - 40-02 (WorkflowScenarios, WorkflowMeta resources)
  - 40-03 (ApiSurface resources, 15-Einträge-Allowlist)
  - 40-04 (10 Read-Tools)
  - 40-05 (cc_finalize_teilnehmerliste Write-Tool)

provides:
  - 11 Smoke-Tests (lookup_smoke_test.rb) — 7 Validierungs-Tests + 2 Registry-Tests + 2 Annotation-Tests
  - 6 E2E-Integrationstests (stdio_e2e_test.rb) — D-16 Pflichtanforderung
  - .mcp.json.example — D-09 MCP-Client-Konfigurationsvorlage
  - docs/managers/clubcloud-mcp-setup.de.md — D-17 Audience b (Sportwarts, Claude Desktop)
  - docs/developers/clubcloud-mcp-server.de.md — D-17 Audience a (Devs, Claude Code)
  - lib/capistrano/tasks/mcp_server.rake — RESEARCH Open Question §5 RESOLVED
  - Phase-40-Gesamttest-Suite: 65 Tests, 220 Assertions, 0 Failures, 0 Errors, 0 Skips

affects:
  - Phase 40.1 (Write-Tool-Erweiterungen: cc_create_team, cc_add_player_to_team,
    cc_upload_result, cc_release_endrangliste)

tech-stack:
  added: []
  patterns:
    - "EXPECTED_TOOL_NAMES frozen reference + dynamic enumeration = dual drift detection (Info 11)"
    - "Open3.popen2e für E2E-Subprocess-Test — STDOUT+STDERR merged, Non-JSON-Zeilen gefiltert"
    - "McpServer::Integration module inline definiert (test-only, kein Zeitwerk-Konflikt)"
    - "CI-Skip via ENV['CI'] für Rails-Boot-intensive E2E-Tests"
    - "Capistrano after 'bundle:install' Hook für chmod 0755 (idempotent)"

key-files:
  created:
    - test/mcp_server/tools/lookup_smoke_test.rb
    - test/mcp_server/integration/stdio_e2e_test.rb
    - .mcp.json.example
    - docs/managers/clubcloud-mcp-setup.de.md
    - docs/developers/clubcloud-mcp-server.de.md
    - lib/capistrano/tasks/mcp_server.rake
  modified:
    - .gitignore (/.mcp.json hinzugefügt)

decisions:
  - "server.tools liefert Arrays [name, klass] statt Objekten — Test angepasst (Array-first-Element als name)"
  - "McpServer::Integration-Modul inline in Testdatei definiert — Zeitwerk lädt test/ nicht, kein Konflikt"
  - "E2E-Tests überspringen auf CI (ENV['CI']) außer executable-bit Guard — Rails-Boot zu langsam"
  - "Capistrano-Hook an 'bundle:install' statt 'deploy:updated' — release_path ist nach bundle install verfügbar"
  - ".mcp.json.example hat frozen_string_literal NICHT (JSON-Datei, kein Ruby)"

requirements-completed: [D-09, D-16, D-17]

duration: "~20 min"
completed: "2026-05-07"
---

# Phase 40 Plan 06: Tests und Setup Summary

**11 Smoke-Tests + 6 E2E-Integrationstests + 3 Setup-Dokumente + 1 Capistrano-Hook — Phase 40 abgeschlossen; 65 Tests gesamt, 0 Failures**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-05-07
- **Tasks:** 4
- **Files erstellt:** 7 (6 neu + .gitignore modifiziert)

## Accomplishments

- **Task 1** — 11 Smoke-Tests in `test/mcp_server/tools/lookup_smoke_test.rb`:
  Je 1 Validierungs-Fehler-Test für LookupLeague, LookupTournament, LookupTeam,
  LookupClub, LookupSpielbericht, LookupCategory, LookupSerie; EXPECTED_TOOL_NAMES
  frozen reference + dynamische Enumeration (Info 11 dual drift detection);
  All-11-tools registry assert; Annotation-Disziplin (read_only_hint/destructive_hint)
- **Task 2** — 6 E2E-Integrationstests in `test/mcp_server/integration/stdio_e2e_test.rb`:
  Executable-bit Guard, initialize-Handshake, tools/list, resources/list,
  tools/call dry-run (D-19), invalid-JSON Probe → -32700 Parse error (RESEARCH §1)
- **Task 3** — `.mcp.json.example` + `.gitignore`-Eintrag + 2 DE-Setup-Dokumente (D-09/D-17)
- **Task 4** — `lib/capistrano/tasks/mcp_server.rake` (RESEARCH Open Question §5 RESOLVED)

## Task Commits

| Task | Name | Commit | Dateien |
|------|------|--------|---------|
| 1 | Smoke-Tests für 7 Read-Tools + Drift-Erkennung | `050848c5` | lookup_smoke_test.rb |
| 2 | E2E stdio Integrationstest | `1729d007` | stdio_e2e_test.rb |
| 3 | .mcp.json.example + DE Setup-Doku | `61a87063` | .mcp.json.example, .gitignore, 2 docs |
| 4 | Capistrano-Deploy-Task | `08da6d19` | mcp_server.rake |

## Phase-40-Gesamtergebnis

```
bin/rails test test/mcp_server/
65 runs, 220 assertions, 0 failures, 0 errors, 0 skips
```

Verteilung:
- `cc_session_test.rb`: 8 Tests (Plan 01)
- `server_smoke_test.rb`: 6 Tests (Plan 01)
- `lookup_region_test.rb`: 4 Tests (Plan 04)
- `lookup_teilnehmerliste_test.rb`: 3 Tests (Plan 04)
- `search_player_test.rb`: 3 Tests (Plan 04)
- `finalize_teilnehmerliste_test.rb`: 6 Tests (Plan 05)
- `lookup_smoke_test.rb`: 11 Tests (Plan 06, Task 1) — NEU
- `stdio_e2e_test.rb`: 6 Tests (Plan 06, Task 2) — NEU (inkl. 5 Rails-Boot-Subtests die lokal alle PASS)
- Ressource-Tests (Plans 02-03): 18 Tests

## RESEARCH Open Questions — Alle 5 RESOLVED

| Open Question | Status | Code/Doku-Level |
|---------------|--------|-----------------|
| §1 Invalid-JSON SDK-Verhalten (welcher error code?) | RESOLVED | E2E-Test: -32700 Parse error bestätigt |
| §2 Single-Thread-Assumption Stdio-Mode | RESOLVED | cc_session.rb Kommentar (Plan 01) |
| §3 MockClient HTTP-only in Mock-Mode | RESOLVED | mock_client.rb (Plan 01) |
| §4 15 separate api/* Resources | RESOLVED | api_surface.rb, 15 Einträge (Plan 03) |
| §5 Capistrano executable-bit | RESOLVED | mcp_server.rake (Task 4) + E2E File.executable? Guard (Task 2) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] server.tools liefert Arrays statt Objekte**
- **Found during:** Task 1 (Test `all 11 expected tools registered`)
- **Issue:** `McpServer::Server.build.tools` liefert `Array<[name_string, klass]>` statt
  `Array<MCP::Tool-Subclass>`. Das Plan-Template nutzte `t.tool_name.to_s` / `t.name.to_s`
  — beides schlägt auf Arrays fehl.
- **Fix:** Map-Block erkennt Arrays via `t.is_a?(Array) ? t.first.to_s : ...`
- **Files modified:** `test/mcp_server/tools/lookup_smoke_test.rb`
- **Commit:** `050848c5`

**2. [Rule 1 - Bug] McpServer::Integration Namespace undefiniert**
- **Found during:** Task 2 (erster Testlauf)
- **Issue:** `McpServer::Integration` existiert nicht als Zeitwerk-Konstante — Zeitwerk
  lädt `test/` nicht, aber Ruby erwartet beim `class McpServer::Integration::StdioE2ETest`
  die existierende Konstante `McpServer::Integration`.
- **Fix:** Modul inline in der Testdatei definiert:
  `module McpServer; module Integration; end; end`
- **Files modified:** `test/mcp_server/integration/stdio_e2e_test.rb`
- **Commit:** `1729d007`

**3. [Rule 1 - Bug] Plan-Template nutzte response.error statt response.error?**
- **Found during:** Task 1 Review (Code-Analyse vor Schreiben)
- **Issue:** Plan-Vorlage enthält `assert response.error` — SDK 0.15 hat nur `#error?`
  (Predicate). Hätte einen NoMethodError ergeben.
- **Fix:** Alle Validierungs-Tests verwenden `assert response.error?` per Plan 01 SDK-Abweichung.
- **Files modified:** `test/mcp_server/tools/lookup_smoke_test.rb`
- **Commit:** `050848c5`

## E2E-Test Messung: Rails-Boot-Zeit

Gemessen lokal (2026-05-07, macOS Darwin, Bootsnap warm):
- `stdio_e2e_test.rb` gesamt: ~5s für 6 Tests
- Einzelner `with_server`-Block: ~1-2s Rails-Boot + JSON-RPC-Roundtrip
- Empfehlung in Setup-Doku: `MCP_TIMEOUT=15000` bleibt angemessen (Plan 01 Messung: ~1s warm Boot)

## Credential-Sicherheit

- `.mcp.json.example` enthält ausschließlich `${VAR}`-Platzhalter und Defaultwerte — keine echten Credentials
- `/.mcp.json` ist via `.gitignore` geschützt (T-40-06-01 mitigiert)
- E2E-Tests erzwingen `CARAMBUS_MCP_MOCK=1` im Subprocess-Env (T-40-06-03 mitigiert)
- Setup-Doku verwendet `<DEIN-USER>`, `deine-cc-email@example.com` (T-40-06-02 mitigiert)
- `File.executable?`-Guard + Capistrano-Hook (T-40-06-05 mitigiert)

## Known Stubs

Keine produktionsrelevanten Stubs. Die live-only Tools geben HTTP-Status-Metadaten zurück
(kein HTML-Parsing), was intentional ist — Phase 40.1 kann HTML-Parsing ergänzen.

## Threat Surface Scan

Keine neuen Netzwerk-Endpunkte, Auth-Pfade oder Schema-Änderungen durch Plan 06 eingeführt.
Plan 06 fügt nur Tests + Docs + Capistrano-Hook hinzu. Keine Threat Flags.

## Phase 40.1 Deferred Items

Folgende Write-Tools wurden bewusst auf Phase 40.1 verschoben (D-19 Scope):

| Tool | CC-Action | Tracking |
|------|-----------|---------|
| `cc_create_team` | `addTeam` | Phase 40.1 |
| `cc_add_player_to_team` | `addPlayer` | Phase 40.1 |
| `cc_upload_result` | `uploadErgebnis` (TBD) | Phase 40.1 |
| `cc_release_endrangliste` | `releaseEndrangliste` | Phase 40.1 |

Die armed-flag + parse_cc_error + Reauth-Retry Architektur (Plan 05) ist als Vorlage bereit.

## Self-Check: PASSED
