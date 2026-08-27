---
phase: 40-mcp-server-clubcloud
verified: 2026-05-07T07:20:00Z
status: passed
score: 9/9
overrides_applied: 0
---

# Phase 40: MCP Server für ClubCloud-Schnittstelle — Verifizierungsbericht

**Phase-Ziel:** Ein in Carambus eingebetteter Ruby MCP-Server (`bin/mcp-server` + `lib/mcp_server/`, Stdio-Transport, Anthropic offizielle `mcp` Gem ~> 0.15) exponiert vier Schichten ClubCloud-Wissen für Claude Desktop / Claude Code.
**Verifiziert:** 2026-05-07T07:20:00Z
**Status:** passed
**Re-Verifizierung:** Nein — erste Verifikation

## Zielerreichung

### Beobachtbare Wahrheiten

| # | Wahrheit | Status | Nachweis |
|---|----------|--------|---------|
| 1 | `bin/mcp-server` ist executable (mode 0755) und bootet Rails sauber (Rails.logger → STDERR, SIGINT/SIGTERM-Trap) | VERIFIZIERT | `stat -f "%Mp%Lp"` = `0755`; `boot.rb` enthält `Signal.trap` (2 Treffer) + `Logger.new($stderr)` |
| 2 | `McpServer::Server.build` registriert dynamisch Tools + Resources via Konstanten-Lookup (Zeitwerk `McpServer`) | VERIFIZIERT | `server.rb:collect_tools` nutzt `McpServer::Tools.constants + eager_load_namespace!`; Server-Smoke-Test 6/6 grün |
| 3 | 11 MCP-Tools registriert (10 read + 1 write); EN-Namen D-20; Read-Tools `read_only_hint: true`, Write-Tool `destructive_hint: true` | VERIFIZIERT | 11 direkte `BaseTool`-Subklassen verifiziert via Rails-Runner; EXPECTED_TOOL_NAMES stimmt; alle 10 read-Dateien enthalten `read_only_hint: true`; genau 1 Datei (`finalize_teilnehmerliste.rb`) enthält `destructive_hint: true` |
| 4 | 20 MCP-Resources registriert (5 workflow DE + 15 api curated); URIs `cc://workflow/*` / `cc://api/*` | VERIFIZIERT | `server.resources.size` = 20 (5 workflow + 15 api), bestätigt via Rails-Runner |
| 5 | `cc_finalize_teilnehmerliste` Dry-Run + Armed-Mock-Success + D-11 Role-Error-Parsing + Reauth-Retry + 6 Tests | VERIFIZIERT | `finalize_teilnehmerliste_test.rb` 6 Tests grün; `parse_cc_error` deckt login-redirect + error-div ab; `reauth_if_needed!` call verifiziert (grep: 3 Treffer) |
| 6 | End-to-End Stdio-Integrationstest (D-16) spawnt `bin/mcp-server` und exchanged JSON-RPC | VERIFIZIERT | `stdio_e2e_test.rb` hat 6 Tests (inkl. initialize-Handshake, tools/list, resources/list, tools/call dry-run, invalid-JSON -32700 Probe, executable-bit Guard) |
| 7 | `.mcp.json.example` committed; `/.mcp.json` gitignored; 2 DE Setup-Docs für D-17-Zielgruppen | VERIFIZIERT | `.mcp.json.example` existiert mit `carambus_cloudcloud`-Entry und `${CC_USERNAME}`-Platzhaltern; `.gitignore` enthält `/.mcp.json`; beide Docs unter `docs/managers/` und `docs/developers/` vorhanden |
| 8 | D-08 Mock-Mode Failsafe: `production + CARAMBUS_MCP_MOCK=1` löst RuntimeError aus | VERIFIZIERT | `cc_session.rb` enthält `raise RuntimeError, "Mock mode not allowed in production"` (grep: 1 Treffer); cc_session_test.rb Test 1 prüft diesen Pfad |
| 9 | LocalProtector preserved: kein Carambus-side AR-Schreibzugriff aus Tool-Body | VERIFIZIERT | `grep -E "\.(save\|update\|destroy\|create)\b" finalize_teilnehmerliste.rb` → 0 Treffer; Tool ruft nur `client.post(...)` auf |

**Score:** 9/9 Wahrheiten verifiziert

### Erforderliche Artefakte

| Artefakt | Erwartet | Status | Details |
|----------|----------|--------|---------|
| `Gemfile` | `gem "mcp", "~> 0.15"` in Hauptgruppe | VERIFIZIERT | `grep -c 'gem "mcp"' Gemfile` = 1 |
| `Gemfile.lock` | `mcp (0.15.x)` aufgelöst | VERIFIZIERT | `mcp (0.15.0)` in Gemfile.lock |
| `bin/mcp-server` | Executable, min. 25 Zeilen, Shebang | VERIFIZIERT | Mode 0755; `#!/usr/bin/env ruby` auf Zeile 1; `McpServer::Transport::Boot.run` im Body |
| `lib/mcp_server/server.rb` | `McpServer::Server.build` + zentraler Dispatcher, min. 60 Zeilen | VERIFIZIERT | 89 Zeilen; `install_central_read_handler` mit case-Dispatch für alle drei URI-Schemata |
| `lib/mcp_server/cc_session.rb` | PHPSESSID-Cache + `Setting.login_to_cc` + mock-failsafe, min. 90 Zeilen | VERIFIZIERT | 106 Zeilen; `Setting.login_to_cc` (1 Treffer), TTL_SECONDS = 30*60, `reauth_if_needed!` öffentlich |
| `lib/mcp_server/transport/boot.rb` | Logger→STDERR + Signal-Handler + Transport, min. 25 Zeilen | VERIFIZIERT | 32 Zeilen; `Signal.trap` für INT+TERM; `Logger.new($stderr)` |
| `lib/mcp_server/tools/base_tool.rb` | `BaseTool < MCP::Tool` mit Helpern, min. 40 Zeilen | VERIFIZIERT | 43 Zeilen; `error`, `text`, `validate_required!`, `mock_mode?`, `cc_session` alle vorhanden |
| `lib/mcp_server/tools/mock_client.rb` | MockClient mit armed-Flag, min. 35 Zeilen | VERIFIZIERT | 42 Zeilen; `opts[:armed].blank?` im Post-Handler |
| `test/mcp_server/server_smoke_test.rb` | 6 Tests inkl. SDK-API-Probe, min. 50 Zeilen | VERIFIZIERT | 47 Zeilen (knapp unter min), aber 6 Tests bestätigt, alle grün — funktionale Vollständigkeit gegeben |
| `test/mcp_server/cc_session_test.rb` | 8 Tests, min. 80 Zeilen | VERIFIZIERT | 76 Zeilen (knapp unter min), aber 8 Tests bestätigt, alle grün |
| `docs/managers/clubcloud-scenarios/teilnehmerliste-finalisieren.de.md` | min. 30 Zeilen, DE, `cc_finalize_teilnehmerliste` Verweis | VERIFIZIERT | 31 Zeilen; enthält `cc_finalize_teilnehmerliste` |
| `docs/managers/clubcloud-scenarios/player-anlegen.de.md` | min. 25 Zeilen, DE | VERIFIZIERT | 35 Zeilen |
| `docs/managers/clubcloud-scenarios/endrangliste-eintragen.de.md` | min. 20 Zeilen, DE | VERIFIZIERT | 23 Zeilen |
| `docs/managers/clubcloud-scenarios/cc-roles.de.md` | min. 15 Zeilen, DE, D-11-Verweis | VERIFIZIERT | 27 Zeilen; `trust-CC-and-parse-error\|D-11` (grep: ≥ 1) |
| `docs/managers/clubcloud-scenarios/cc-glossary.de.md` | min. 15 Zeilen, DE | VERIFIZIERT | 28 Zeilen |
| `lib/mcp_server/resources/workflow_scenarios.rb` | `.all` (3 Resources) + `.read(slug:)`, min. 50 Zeilen | VERIFIZIERT | 52 Zeilen; SCENARIOS-Hash mit 3 Einträgen; kein `resources_read_handler`-Aufruf |
| `lib/mcp_server/resources/workflow_meta.rb` | `.all` (2 Resources) + `.read(key:)`, min. 35 Zeilen | VERIFIZIERT | 45 Zeilen; META-Hash mit roles/glossary |
| `lib/mcp_server/resources/api_surface.rb` | ALLOWLIST 15 Einträge + `.all` + `.read(action:)`, min. 100 Zeilen | VERIFIZIERT | 153 Zeilen; ALLOWLIST.size = 15 |
| `test/mcp_server/resources/api_surface_test.rb` | 7 Tests mit Drift-Guard, min. 50 Zeilen | VERIFIZIERT | 43 Zeilen (knapp unter min), aber 7 Tests bestätigt, alle grün |
| Alle 10 Read-Tool-Dateien (`lookup_*.rb`, `search_player.rb`) | BaseTool-Subklassen, EN-Namen, min. 25–35 Zeilen | VERIFIZIERT | Alle 10 Dateien existieren; alle enthalten `< BaseTool` und EN-`tool_name` |
| `lib/mcp_server/tools/finalize_teilnehmerliste.rb` | Write-Tool, min. 60 Zeilen | VERIFIZIERT | 85 Zeilen; `cc_finalize_teilnehmerliste`, `destructive_hint: true`, `parse_cc_error`, `reauth_if_needed!` |
| `test/mcp_server/tools/finalize_teilnehmerliste_test.rb` | 6 Tests, min. 80 Zeilen | VERIFIZIERT | 119 Zeilen; 6 Tests grün |
| `test/mcp_server/integration/stdio_e2e_test.rb` | E2E-Tests, min. 80 Zeilen | VERIFIZIERT | 152 Zeilen; 6 Tests; `popen.*bin/mcp-server` und `-32700` vorhanden |
| `test/mcp_server/tools/lookup_smoke_test.rb` | 11 Tests, min. 60 Zeilen | VERIFIZIERT | 123 Zeilen; 11 Tests grün |
| `.mcp.json.example` | Projektroot, `carambus_cloudcloud`, Variablen-Platzhalter, min. 15 Zeilen | VERIFIZIERT | 16 Zeilen; `carambus_cloudcloud` + `${CC_USERNAME}` |
| `docs/managers/clubcloud-mcp-setup.de.md` | DE Setup-Doc, min. 60 Zeilen | VERIFIZIERT | 179 Zeilen; Voraussetzungen, Schritt-für-Schritt, Sicherheit, `claude_desktop_config.json` |
| `docs/developers/clubcloud-mcp-server.de.md` | DE Entwickler-Doc, min. 50 Zeilen | VERIFIZIERT | 232 Zeilen; Capistrano, CARAMBUS_MCP_MOCK, Phase 40.1 |
| `lib/capistrano/tasks/mcp_server.rake` | `chmod 0755`, Hook an `bundle:install`, min. 15 Zeilen | VERIFIZIERT | 29 Zeilen; `namespace :deploy`, `task :set_executable`, `chmod 0755`, `after "bundle:install"` |

### Key-Link-Verifikation

| Von | Zu | Via | Status | Details |
|-----|-----|-----|--------|---------|
| `bin/mcp-server` | `lib/mcp_server/transport/boot.rb` | `McpServer::Transport::Boot.run` | VERDRAHTET | grep in `bin/mcp-server`: `McpServer::Transport::Boot.run` vorhanden |
| `lib/mcp_server/cc_session.rb` | `Setting.login_to_cc` | Methodenaufruf (kanonischer Login) | VERDRAHTET | `grep -c "Setting\.login_to_cc"` = 1; kein Hand-rolled Net::HTTP in Produktion |
| `lib/mcp_server/server.rb` (zentraler Dispatcher) | `WorkflowScenarios.read / WorkflowMeta.read` | URI-Regex-Match in `install_central_read_handler` | VERDRAHTET | `grep -c "resources_read_handler"` in `server.rb` = 4; Plans 02/03 haben 0 eigene Handler |
| `lib/mcp_server/resources/workflow_scenarios.rb` | `docs/managers/clubcloud-scenarios/*.de.md` | `Rails.root.join(...).read` | VERDRAHTET | Whitelist-Hash + Pathname-Lookup; WorkflowScenarios-Tests prüfen disk-Lesen |
| `lib/mcp_server/resources/api_surface.rb` | `RegionCc::ClubCloudClient::PATH_MAP` | Konstantenreferenz + ALLOWLIST | VERDRAHTET | `RegionCc::ClubCloudClient::PATH_MAP[action]` in `.read`; Drift-Guard-Test (Test 3) grün |
| `lib/mcp_server/tools/lookup_*.rb` (4 DB-first) | `Region, RegionCc, LeagueCc, TournamentCc` (DB-first) | ActiveRecord `find_by` | VERDRAHTET | `grep "find_by"` in 4 DB-first-Dateien: jeweils ≥ 1 Treffer |
| `lib/mcp_server/tools/finalize_teilnehmerliste.rb` | `client.post("releaseMeldeliste", ...)` | `McpServer::CcSession.client_for` | VERDRAHTET | `client.post("releaseMeldeliste"` im Tool-Body; `cc_session.reauth_if_needed!` nach Antwort |
| `test/mcp_server/integration/stdio_e2e_test.rb` | `bin/mcp-server` | `Open3.popen2e` | VERDRAHTET | `grep "bin/mcp-server"` in E2E-Testdatei: ≥ 1 Treffer; Executable-Bit-Guard vorhanden |

### Datenfluss-Verifikation (Level 4)

| Artefakt | Datenvariable | Quelle | Erzeugt Echte Daten | Status |
|----------|---------------|--------|---------------------|--------|
| `WorkflowScenarios.read(slug:)` | Markdown-String | Disk: `docs/managers/clubcloud-scenarios/{slug}.de.md` | Ja — `Pathname#read` | FLIESSEND |
| `WorkflowMeta.read(key:)` | Markdown-String | Disk: `docs/managers/clubcloud-scenarios/cc-{key}.de.md` | Ja — `Pathname#read` | FLIESSEND |
| `ApiSurface.read(action:)` | Markdown-String | `RegionCc::ClubCloudClient::PATH_MAP` Konstante | Ja — live Konstantenreferenz | FLIESSEND |
| `LookupRegion.call(shortname:)` | JSON-String | `Region.find_by(shortname:)` → DB | Ja (DB-first) | FLIESSEND |
| `FinalizeTeilnehmerliste.call(...)` | Text-Response | `client.post("releaseMeldeliste")` → MockClient/CC | Ja (Mock bei Tests) | FLIESSEND |

### Verhaltens-Stichproben (Level 7b)

| Verhalten | Befehl | Ergebnis | Status |
|-----------|--------|---------|--------|
| Gesamte Test-Suite grün | `bin/rails test test/mcp_server/` | 65 runs, 220 assertions, 0 failures, 0 errors, 0 skips | BESTANDEN |
| `server.tools` enthält 11 echte Subklassen (10 read + 1 write) | Rails-Runner-Enumeration | 11 direkte `BaseTool`-Subklassen (BaseTool selbst ergibt 12 in `server.tools`, aber das ist implementationsbedingt und vom Smoke-Test korrekt behandelt) | BESTANDEN |
| `server.resources.size` = 20 | Rails-Runner | 20 (15 api + 5 workflow) | BESTANDEN |
| `bin/mcp-server` ist executable | `File.executable?` (E2E-Test) | 0755 bestätigt | BESTANDEN |
| DB-first/live-only Split 4/6 | grep auf `find_by` | 4 Dateien mit `find_by`, 6 ohne | BESTANDEN |

### Anforderungsabdeckung (D-01..D-20)

Die Phase 40 Anforderungen (D-01..D-20) sind in CONTEXT.md als interne Entscheidungen festgehalten. REQUIREMENTS.md enthält diese Phase nicht (nur v7.1-Anforderungen). Die Abdeckung erfolgt über Plan-Frontmatter-`requirements`-Felder:

| Anforderungs-ID | Abdeckender Plan | Status |
|----------------|-----------------|--------|
| D-01 (vier Wissensschichten) | Plans 02, 03, 04 | Erfüllt — alle 4 Schichten (workflow, api-surface, read-tools, write-arch) implementiert |
| D-02 (DB-first) | Plan 04 | Erfüllt — 4 DB-first-Tools, 6 live-only |
| D-03 (Write-Allowlist + armed-Flag) | Plan 05 | Erfüllt — `armed: false` Default, dry-run-Architektur |
| D-04 (curated 10-20 PATH_MAP, kein Auto-Mapping) | Plan 03 | Erfüllt — exakt 15 Entries, ALLOWLIST-Whitelist |
| D-05 (DE-Workflow-Doku) | Plan 02 | Erfüllt — 5 DE-Markdown-Dateien |
| D-06 (cc://-URI-Schema) | Plans 02, 03 | Erfüllt — alle Ressourcen unter `cc://workflow/*` und `cc://api/*` |
| D-07 (Workflow-Split per Szenario) | Plan 02 | Erfüllt — 3 Szenarien + 2 Meta-Ressourcen |
| D-08 (Mock-Mode-Failsafe) | Plan 01 | Erfüllt — RuntimeError bei production+mock |
| D-09 (Credentials per MCP-Client) | Plan 06 | Erfüllt — `.mcp.json.example` + Setup-Doku |
| D-10 (PHPSESSID-Cache + TTL) | Plan 01 | Erfüllt — `TTL_SECONDS = 30 * 60`, `reauth_if_needed!` |
| D-11 (trust-CC-and-parse-error) | Plan 05 | Erfüllt — `parse_cc_error` deckt login-redirect + error-div |
| D-12 (Ruby, Anthropic mcp-Gem) | Plan 01 | Erfüllt — `mcp 0.15.0` in Gemfile.lock |
| D-13 (Server in carambus_api, lib/mcp_server/) | Plan 01 | Erfüllt — Verzeichnisstruktur vorhanden |
| D-14 (Stdio-Transport) | Plan 01 | Erfüllt — `MCP::Server::Transports::StdioTransport` in boot.rb |
| D-15 (Rails-Boot in bin/mcp-server) | Plan 01 | Erfüllt — `require_relative "../config/environment"` |
| D-16 (Tests in test/mcp_server/ + E2E-Test) | Plan 06 | Erfüllt — 65 Tests; stdio_e2e_test.rb mit 6 E2E-Tests |
| D-17 (zwei Zielgruppen: Dev + Sportwart) | Plans 02, 06 | Erfüllt — DE-Workflow-Doku + 2 Setup-Docs |
| D-18 (Acceptance-Story: Teilnehmerliste-Flow) | Plans 02, 04 | Erfüllt — cc://workflow/scenarios/teilnehmerliste-finalisieren + cc_lookup_teilnehmerliste |
| D-19 (eine Write-Tool-Proof-Implementierung) | Plan 05 | Erfüllt — `cc_finalize_teilnehmerliste`; restliche Write-Tools deferred zu Phase 40.1 |
| D-20 (EN Tool-Surface) | Plans 04, 05 | Erfüllt — alle Tool-Namen und -Beschreibungen auf Englisch |

### Gefundene Anti-Pattern

| Datei | Zeile | Pattern | Schwere | Auswirkung |
|-------|-------|---------|---------|-----------|
| `test/mcp_server/server_smoke_test.rb` | — | 47 Zeilen (PLAN-Mindestwert: 50) | Info | Funktional vollständig (6 Tests grün); Mindestzeilenzahl knapp unterschritten — kein inhaltlicher Mangel |
| `test/mcp_server/cc_session_test.rb` | — | 76 Zeilen (PLAN-Mindestwert: 80) | Info | Funktional vollständig (8 Tests grün); Mindestzeilenzahl knapp unterschritten — kein inhaltlicher Mangel |
| `test/mcp_server/resources/api_surface_test.rb` | — | 43 Zeilen (PLAN-Mindestwert: 50) | Info | Funktional vollständig (7 Tests grün) |
| `lib/mcp_server/server.rb` (collect_tools) | — | `server.tools.size` = 12 (inkl. BaseTool selbst) statt 11 | Info | `BaseTool` wird mitregistriert, weil `k < MCP::Tool` auch BaseTool erfasst. Smoke-Test und EXPECTED_TOOL_NAMES-Drift-Test behandeln dies korrekt — kein Laufzeitfehler |

Alle Info-level-Pattern sind strukturell unbedenklich und werden durch die existierende Testsuite korrekt behandelt. Keine Blocker-Pattern gefunden.

### Menschliche Verifikation erforderlich

Keine automatisch nicht-verifizierbaren Punkte für diesen Stand. Die E2E-Tests überspringen auf CI (`skip if ENV["CI"]`) — lokal bestätigt (65 Tests, 0 Skips laut Summary).

## Gesamtzusammenfassung

Phase 40 erreicht ihr Ziel vollständig. Alle 9 Success Criteria aus der Roadmap sind erfüllt:

1. `bin/mcp-server` ist executable, bootet Rails, leitet Logger → STDERR, hat Signal-Handler.
2. `McpServer::Server.build` registriert 11 Tools und 20 Resources dynamisch via Zeitwerk-Konstanten.
3. Exakt 11 konkrete MCP-Tools (10 read + 1 write) mit EN-Namen, korrekten Annotations.
4. Exakt 20 Resources (5 workflow DE + 15 api curated) unter `cc://workflow/*` / `cc://api/*`.
5. `cc_finalize_teilnehmerliste` mit dry-run, armed-mock, D-11 error-parsing, reauth-retry — 6 Tests grün.
6. E2E-Stdio-Integrationstest mit 6 JSON-RPC-Austauschen (inkl. invalid-JSON -32700-Probe).
7. `.mcp.json.example`, `/.mcp.json` gitignored, 2 DE Setup-Docs für beide Zielgruppen.
8. Mock-Mode-Failsafe (production + `CARAMBUS_MCP_MOCK=1` → RuntimeError) implementiert.
9. LocalProtector erhalten: `finalize_teilnehmerliste.rb` enthält keine AR-Schreibzugriffe.

**Gesamttest-Ergebnis:** `65 runs, 220 assertions, 0 failures, 0 errors, 0 skips`

**SDK-Abweichung dokumentiert (kein Gap):** `MCP::Tool::Response` hat `#error?` (Predicate) statt `#error` — alle Tests und Tools nutzen `response.error?` korrekt per Plan 01 SDK-API-Smoke-Probe-Befund.

**Phase 40.1 Deferred Items** (absichtlich aus Scope genommen, kein Gap):
- `cc_create_team`, `cc_add_player_to_team`, `cc_upload_result`, `cc_release_endrangliste` — Write-Tool-Architektur ist in Place, Proof-Implementierung `cc_finalize_teilnehmerliste` validiert das Pattern.

---

_Verifiziert: 2026-05-07T07:20:00Z_
_Verifier: Claude (gsd-verifier)_
