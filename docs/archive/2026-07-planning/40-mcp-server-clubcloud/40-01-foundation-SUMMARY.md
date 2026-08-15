---
phase: 40-mcp-server-clubcloud
plan: "01"
subsystem: infra
tags: [mcp, ruby-sdk, rails, stdio, clubcloud, zeitwerk]

requires: []

provides:
  - Ausführbares bin/mcp-server (Stdio-Transport, Rails-Boot)
  - McpServer::Server.build mit zentralem resources_read_handler-Dispatcher (Blockers 2+3)
  - McpServer::CcSession mit PHPSESSID-Cache, 30-min TTL, Setting.login_to_cc-Delegation, Mock-Failsafe
  - McpServer::Tools::BaseTool (error/text/validate_required!/mock_mode? Helpers)
  - McpServer::Tools::MockClient (Drop-in für CARAMBUS_MCP_MOCK=1)
  - McpServer::Transport::Boot (Logger→STDERR, Signal-Handler, StdioTransport.open)
  - 14 Tests grün (8 CcSession + 6 ServerSmoke)
  - SDK-API-Kontrakte gesperrt für Plans 04+05

affects:
  - 40-02-workflow-resources (nutzt McpServer::Resources::WorkflowScenarios.read + McpServer::Resources::WorkflowMeta.read)
  - 40-03-api-resources (nutzt McpServer::Resources::ApiSurface.read)
  - 40-04-read-tools (nutzt BaseTool, CcSession, MockClient)
  - 40-05-write-tool (nutzt CcSession.reauth_if_needed!, MockClient, armed-Flag)

tech-stack:
  added:
    - "mcp 0.15.0 (Anthropic Official Ruby SDK, released 2026-05-04)"
    - "json-schema 6.2.0 (Auto-Dependency von mcp)"
  patterns:
    - "Zeitwerk-strenge Konstantennamen: McpServer (camelCase), NICHT MCPServer"
    - "Zentraler resources_read_handler-Dispatcher in server.rb (ein Handler pro Server)"
    - "Constants-Enumeration für Auto-Registry: McpServer::Tools.constants + .select { k < MCP::Tool }"
    - "Rails.logger → STDERR in bin/mcp-server (JSON-RPC STDOUT sauber halten)"
    - "Setting.login_to_cc als kanonischer CC-Login-Flow (kein Hand-rolled Net::HTTP::Post)"
    - "mock_mode? via ENV['CARAMBUS_MCP_MOCK'] == '1' mit Production-Failsafe"

key-files:
  created:
    - bin/mcp-server
    - lib/mcp_server/server.rb
    - lib/mcp_server/cc_session.rb
    - lib/mcp_server/transport/boot.rb
    - lib/mcp_server/tools/base_tool.rb
    - lib/mcp_server/tools/mock_client.rb
    - test/mcp_server/server_smoke_test.rb
    - test/mcp_server/cc_session_test.rb
  modified:
    - Gemfile
    - Gemfile.lock

key-decisions:
  - "SDK-API DEVIATION: MCP::Tool::Response hat #error? (Predicate), NICHT #error — Plans 04+05 müssen response.error? verwenden"
  - "Setting.login_to_cc ist der kanonische CC-Login (kein Hand-rolled Net::HTTP in cc_session.rb)"
  - "Zeitwerk auto-loaded lib/mcp_server/ via vorhandene config.autoload_lib — keine config/application.rb-Änderung nötig"
  - "Bootsnap-warmer Boot: ~1s (deutlich unter 3-5s Cold-Boot-Schätzung aus Research) → MCP_TIMEOUT=15000 bleibt empfohlenes Minimum"
  - "Einzelner zentraler resources_read_handler in server.rb — Plans 02+03 registrieren KEINEN eigenen Handler"

patterns-established:
  - "Pattern: SDK Tool DSL — tool_name, description, input_schema, annotations als Class-level Makros"
  - "Pattern: BaseTool.error/text als kanonische Response-Konstruktoren"
  - "Pattern: eager_load_namespace! via Dir.glob vor Tool-Registry (Zeitwerk-vorgeladen reicht nicht für Runtime-Enumeration)"

requirements-completed: [D-12, D-13, D-14, D-15, D-08, D-10]

duration: 5min
completed: "2026-05-07"
---

# Phase 40 Plan 01: Foundation Summary

**mcp 0.15.0 (Anthropic SDK) integriert — bootfähiges bin/mcp-server via Stdio mit Zeitwerk-geladenem McpServer-Namespace, PHPSESSID-Cache-Session (Setting.login_to_cc), zentralem resources_read_handler-Dispatcher und 14 grünen Tests**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-07T04:19:10Z
- **Completed:** 2026-05-07T04:24:04Z
- **Tasks:** 3
- **Files modifiziert:** 10

## Accomplishments

- `mcp 0.15.0` (Anthropic Official Ruby SDK) zur Haupt-Gemfile-Gruppe hinzugefügt; Zeitwerk lädt `lib/mcp_server/` automatisch via bestehendes `config.autoload_lib` (keine Konfigurationsänderung nötig)
- `bin/mcp-server` (0755) bootet Rails, leitet Logger → STDERR, öffnet StdioTransport — JSON-RPC-STDOUT bleibt sauber
- `McpServer::Server.build` installiert EINEN zentralen `resources_read_handler`-Dispatcher für `cc://workflow/scenarios/*`, `cc://workflow/(roles|glossary)` und `cc://api/*` — Plans 02+03 registrieren keinen eigenen Handler (Wave-2-Konfliktfreiheit gesichert)
- `McpServer::CcSession` delegiert Login an `Setting.login_to_cc` (kanonischer Flow) — kein Hand-rolled Net::HTTP in cc_session.rb (Blocker 4 + Warning 7 erfüllt)
- SDK-API-Kontrakte per Smoke-Probe gesperrt: `tool_name`/`description`/`input_schema`/`annotations` existieren als Class-Makros; `Response#error?` (Predicate, NICHT `#error`) + `#content` sind die realen Accessoren

## Task Commits

Jeder Task wurde atomar committed:

1. **Task 1: mcp-Gem + McpServer-Skelett + bin/mcp-server** — `e610f0ac` (feat)
2. **Task 2: CcSession + MockClient + Tests** — `13eb4761` (feat)
3. **Task 3: Server-Smoke-Test + SDK-API-Probe** — `57ca5f71` (test)

## Files Created/Modified

- `Gemfile` — `gem "mcp", "~> 0.15"` zur Hauptgruppe hinzugefügt
- `Gemfile.lock` — mcp 0.15.0 + json-schema 6.2.0 aufgelöst
- `bin/mcp-server` — Ausführbares Entrypoint (0755)
- `lib/mcp_server/server.rb` — McpServer::Server.build + zentraler Dispatcher + eager_load_namespace!
- `lib/mcp_server/cc_session.rb` — PHPSESSID-Cache, TTL, Setting.login_to_cc, Mock-Failsafe, reauth_if_needed!
- `lib/mcp_server/transport/boot.rb` — Logger→STDERR, Signal-Handler, StdioTransport
- `lib/mcp_server/tools/base_tool.rb` — BaseTool < MCP::Tool mit error/text/validate_required!/mock_mode?
- `lib/mcp_server/tools/mock_client.rb` — MockClient mit armed-Flag-Konvention und Call-Tracking
- `test/mcp_server/server_smoke_test.rb` — 6 Smoke-Tests inkl. SDK-API-Probe
- `test/mcp_server/cc_session_test.rb` — 8 CcSession-Tests

## Decisions Made

- **Zeitwerk ohne Konfigurationsänderung:** `config.autoload_lib(ignore: %w[assets generators tasks templates])` in `config/application.rb:86` ist bereits vorhanden — `lib/mcp_server/` wird automatisch geladen. Keine `config/application.rb`-Änderung nötig.
- **Bootsnap-warmer Boot ~1s:** Research schätzte 3-5s; tatsächliche Messung 1.06s. MCP_TIMEOUT=15000ms bleibt Empfehlung für MCP-Client-Konfiguration (Plan 06 Setup-Doc).
- **resources_read_handler als zentraler Dispatcher:** Einer pro Server-Instanz. Plans 02+03 exponieren nur `.read(slug:|action:)` Class-Methoden.

## SDK-API Smoke Probe Findings

**(Warning 8 resolved — Plans 04+05 verwenden diese Contracts als fixe Referenz)**

| API | Erwartet (Research) | Tatsächlich (SDK 0.15.0) | Status |
|-----|---------------------|--------------------------|--------|
| DSL-Makro `tool_name` | vorhanden | ✓ vorhanden | OK |
| DSL-Makro `description` | vorhanden | ✓ vorhanden | OK |
| DSL-Makro `input_schema` | vorhanden | ✓ vorhanden | OK |
| DSL-Makro `annotations` | vorhanden | ✓ vorhanden | OK |
| `Response#error` | vorhanden | ✗ FEHLT — hat stattdessen `#error?` | **DEVIATION** |
| `Response#error?` | nicht erwähnt | ✓ vorhanden | Korrekt |
| `Response#content` | vorhanden | ✓ vorhanden | OK |
| `MCP::Server.new(name:, tools:, resources:)` | vorhanden | ✓ vorhanden | OK |
| `server.resources_read_handler { \|params\| }` | vorhanden | ✓ vorhanden | OK |

**Action für Plans 04+05:** `response.error?` nutzen (nicht `response.error`). `BaseTool.error` und `BaseTool.text` konstruieren korrekte Response-Objekte — nur der Accessor-Name ist abweichend.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] SDK-API `Response#error?` statt `Response#error`**
- **Found during:** Task 3 (SDK-API Smoke Probe)
- **Issue:** Plan-Spec erwartete `MCP::Tool::Response` mit `#error`-Accessor. SDK 0.15.0 hat `#error?` (Boolean-Predicate), NICHT `#error`.
- **Fix:** Smoke-Test nutzt `response.error?` + `assert_respond_to response, :error?`; BaseTool-Kommentar aktualisiert. BaseTool.error/text helper-Methoden sind korrekt (sie *erzeugen* Responses, nutzen `#error` nicht als Accessor).
- **Files modified:** `test/mcp_server/server_smoke_test.rb`, `lib/mcp_server/tools/base_tool.rb`
- **Verification:** 14/14 Tests grün
- **Committed in:** `57ca5f71` (Task 3 commit)

---

**Total Deviations:** 1 auto-fixed (Rule 1 — Bug)
**Impact:** Notwendige Korrektur — stellt sicher dass Plans 04+05 den richtigen Accessor verwenden. Kein Scope-Creep.

## Issues Encountered

Keine. Alle Akzeptanzkriterien auf Anhieb erfüllt.

## User Setup Required

Keine — Foundation-Plan erzeugt keine externe Service-Konfiguration. Für tatsächliche MCP-Client-Konfiguration (Claude Desktop / Claude Code `mcp.json`) wird Plan 06 (Setup-Doc) einen Installations-Leitfaden erstellen.

## Next Phase Readiness

- **Plans 02 (workflow-resources) + 03 (api-resources):** Können unabhängig voneinander implementieren. Beide exponieren nur `.read(slug:|action:)` Class-Methoden — kein `install_read_handler`-Aufruf nötig.
- **Plans 04 (read-tools) + 05 (write-tool):** `BaseTool`, `CcSession`, `MockClient` sind vollständig. SDK-API-Kontrakte aus Smoke-Probe verwenden. `response.error?` (nicht `response.error`).
- **Kein Blocker** für Wave-2-Ausführung.

---
*Phase: 40-mcp-server-clubcloud*
*Completed: 2026-05-07*
