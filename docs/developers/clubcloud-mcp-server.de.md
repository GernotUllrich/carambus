# ClubCloud-MCP-Server: Entwickler-Setup

## Architektur-Übersicht

Der MCP-Server (Phase 40) liegt vollständig unter `lib/mcp_server/` und wird über
`bin/mcp-server` als Stdio-Subprocess gespawnt:

```
lib/
├── mcp_server/
│   ├── server.rb             # MCP::Server.build — Auto-Registry + zentraler read_handler
│   ├── cc_session.rb         # PHPSESSID-Cache, TTL 30min, Setting.login_to_cc Delegation
│   ├── tools/
│   │   ├── base_tool.rb      # BaseTool < MCP::Tool — error/text/validate_required! Helpers
│   │   ├── mock_client.rb    # Drop-in MockClient für CARAMBUS_MCP_MOCK=1
│   │   ├── lookup_*.rb       # 10 Read-Tools (DB-first + live-only)
│   │   └── finalize_teilnehmerliste.rb  # 1 Write-Tool (Phase 40 Proof, D-19)
│   ├── resources/
│   │   ├── workflow_scenarios.rb  # cc://workflow/scenarios/* (DE)
│   │   ├── workflow_meta.rb       # cc://workflow/roles + glossary
│   │   └── api_surface.rb         # cc://api/* (15-Einträge-Allowlist)
│   └── transport/
│       └── boot.rb           # Logger→STDERR, Signal-Handler, StdioTransport.open
bin/
└── mcp-server                # Executable — require config/environment + boot.rb
test/
└── mcp_server/
    ├── cc_session_test.rb
    ├── server_smoke_test.rb
    ├── tools/
    │   ├── lookup_region_test.rb
    │   ├── lookup_teilnehmerliste_test.rb
    │   ├── search_player_test.rb
    │   ├── finalize_teilnehmerliste_test.rb
    │   └── lookup_smoke_test.rb   # Plan 06 — 11 Smoke-Tests + Drift-Erkennung
    └── integration/
        └── stdio_e2e_test.rb      # Plan 06 — 6 E2E-Tests (D-16)
```

Planstruktur (Phase 40, alle 6 Pläne abgeschlossen):
- **40-01**: Foundation — bin/mcp-server, Server.build, CcSession, BaseTool, MockClient
- **40-02**: Workflow-Resources — 5 Szenarien + Rollenmodell + Glossar als cc://workflow/*
- **40-03**: API-Surface-Resources — 15-Einträge-Allowlist als cc://api/*
- **40-04**: 10 Read-Tools (4 DB-first + 6 live-only)
- **40-05**: 1 Write-Tool (cc_finalize_teilnehmerliste, armed-flag, D-19)
- **40-06**: Tests + Doku + Capistrano-Deploy-Hook (dieses Dokument)

## Dependencies

**Gem:** `mcp ~> 0.15` (Anthropic Official Ruby SDK, seit 2026-05-04 verfügbar)

```ruby
# Gemfile (Hauptgruppe — kein :development/:test)
gem "mcp", "~> 0.15"
```

**CC-Transport:** `RegionCc::ClubCloudClient` (bereits vorhanden) — kein neuer HTTP-Layer.

**Mock-Mode:** `CARAMBUS_MCP_MOCK=1` — gibt `McpServer::Tools::MockClient.new` zurück
statt echtem `RegionCc::ClubCloudClient`. Failsafe: Mock-Mode ist in
`Rails.env.production?` technisch gesperrt (CcSession wirft RuntimeError).

**Zeitwerk:** Der Namespace heißt `McpServer` (camelCase), NICHT `MCPServer`. Zeitwerk
lädt `lib/mcp_server/` via `config.autoload_lib(ignore: ...)` in `config/application.rb`.
Keine Konfigurationsänderung nötig.

## Project-Scope MCP-Setup für Claude Code

Das empfohlene Setup für Carambus-Devs nutzt Claude Code mit Project-Scope `.mcp.json`:

```bash
# Schritt 1: Vorlage kopieren
cp .mcp.json.example .mcp.json

# Schritt 2: Eigene CC-Zugangsdaten eintragen
# .mcp.json ist via .gitignore geschützt (enthält Klartextpasswort)
$EDITOR .mcp.json
```

Die Variable-Expansion `${VAR}` und `${VAR:-default}` wird von Claude Code beim
Starten des Servers aufgelöst. Alternativ direkt eintragen:

```json
{
  "mcpServers": {
    "carambus_clubcloud": {
      "command": "/Users/<dein-user>/DEV/carambus/carambus_api/bin/mcp-server",
      "args": [],
      "env": {
        "CC_USERNAME": "deine@email.de",
        "CC_PASSWORD": "dein-passwort",
        "CC_FED_ID": "20",
        "CARAMBUS_MCP_MOCK": "0",
        "RAILS_ENV": "development"
      }
    }
  }
}
```

**Wichtig:** `.mcp.json` ist in `.gitignore` eingetragen — nur `.mcp.json.example`
(mit `${VAR}`-Platzhaltern) ist im Repository.

## User-Scope Alternative

Wenn du den MCP-Server in allen Projekten global zur Verfügung haben möchtest:

```bash
claude mcp add carambus_clubcloud \
  --scope user \
  --command /Users/<dein-user>/DEV/carambus/carambus_api/bin/mcp-server \
  --env CC_USERNAME=deine@email.de \
  --env CC_PASSWORD=dein-passwort \
  --env CC_FED_ID=20 \
  --env CARAMBUS_MCP_MOCK=0 \
  --env RAILS_ENV=development
```

User-Scope schreibt nach `~/.claude.json` (macOS). Vorteil: einmalig einrichten,
überall verfügbar. Nachteil: Passwort liegt in User-Home statt im Repo-lokalen `.mcp.json`.

## Lokales Testen

**Manueller Starttest (Mock-Mode):**

```bash
CARAMBUS_MCP_MOCK=1 RAILS_ENV=development bin/mcp-server
```

Server startet, wartet auf JSON-RPC über STDIN. Zum Testen:

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | \
  CARAMBUS_MCP_MOCK=1 RAILS_ENV=development bin/mcp-server
```

Erwartete Antwort: JSON-Objekt mit `result.serverInfo.name = "carambus_clubcloud"`.

**Eigenes Tool testen:**

```bash
# Snippet mit jq für lesbares JSON
echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"cc_lookup_region","arguments":{"shortname":"BCW"}}}' | \
  CARAMBUS_MCP_MOCK=1 RAILS_ENV=development bin/mcp-server | grep '^{' | jq .
```

## Test-Suite

```bash
# Alle MCP-Tests
bin/rails test test/mcp_server/

# Nur Smoke-Tests (schnell, kein Rails-Boot-Subprocess)
bin/rails test test/mcp_server/tools/

# E2E-Tests (langsam — spawnen echten bin/mcp-server Subprocess)
bin/rails test test/mcp_server/integration/stdio_e2e_test.rb

# Gesamtanzahl nach Plan 06: >= 32 Tests
```

Die E2E-Tests in `stdio_e2e_test.rb` überspringen sich automatisch auf CI
(`skip if ENV["CI"]`), da Rails-Boot pro Subprocess ~1-5s dauert.

## Pitfalls

### STDOUT-Verschmutzung (Pitfall 1 — KRITISCH)

JSON-RPC läuft über STDOUT. Jede Ausgabe auf STDOUT (Rails-Logger, `puts`, `pp`,
`binding.pry`, etc.) bricht den JSON-RPC-Stream und führt zu "Server disconnected"
im MCP-Client.

**Regel:** Immer `Rails.logger.info "..."` statt `puts`. `bin/mcp-server` leitet
`Rails.logger` explizit auf STDERR um (in `lib/mcp_server/transport/boot.rb`).

### Zeitwerk-Konstantenname

Der Namespace ist `McpServer` (camelCase), NICHT `MCPServer`. Zeitwerk mappt
`lib/mcp_server/` → `McpServer`. Falsche Konstantennamen → `NameError` beim
Autoload-Lookup.

### PHPSESSID-Reauth bei 30-Minuten-Idle

Die CC-Session läuft nach 30 Minuten ab. `CcSession.cookie` erkennt den Ablauf
und ruft automatisch `login!` → `Setting.login_to_cc` auf. Falls das fehlschlägt
(z.B. falsche Credentials), gibt die Tool-Response einen `error?`-Envelope zurück.

### Mock-Mode-Leak in Production

`CcSession.client_for` wirft `RuntimeError` wenn `mock_mode? && Rails.env.production?`.
Das ist eine Produktionssicherung — verhindert, dass ein vergessenes
`CARAMBUS_MCP_MOCK=1` in Production Mock-Daten ausgibt.

### response.error? (Predicate), NICHT response.error

SDK 0.15.0: `MCP::Tool::Response` hat `#error?` (Boolean-Predicate), nicht `#error`.
In allen Tests und Tool-Implementierungen `response.error?` verwenden.
Dokumentiert in Plan 01 SUMMARY (SDK-API-Abweichung).

## Capistrano-Deploy

Capistrano-Deployments verlieren gelegentlich das executable-Bit auf `bin/mcp-server`
(abhängig vom Server-OS und den `linked_files`-Einstellungen). Plan 06 Task 4 liefert
einen Deploy-Hook, der dieses Problem automatisch behebt:

```ruby
# lib/capistrano/tasks/mcp_server.rake (automatisch geladen via Capfile)
# Führt nach bundle:install ein chmod 0755 auf bin/mcp-server aus.
```

Wird via `Capfile` automatisch geladen:
```ruby
Dir.glob("lib/capistrano/tasks/*.rake").each { |r| import r }
```

Nach jedem `cap production deploy` ist `bin/mcp-server` garantiert ausführbar.
Dies löst RESEARCH Open Question §5 auf Code-Ebene (Capistrano + E2E-Test).

## Referenz auf Phase 40.1

Die Write-Tool-Architektur (armed-flag + parse_cc_error + Reauth-Retry) aus Plan 05
ist als Vorlage für weitere Write-Tools in Phase 40.1 gedacht:

| Geplantes Tool | CC-Action | Notizen |
|----------------|-----------|---------|
| `cc_create_team` | `addTeam` | branchId + fedId + teamName Required |
| `cc_add_player_to_team` | `addPlayer` o.ä. | Spieler-CRUD in CC |
| `cc_upload_result` | `uploadErgebnis` (TBD) | Ergebnis-Upload |
| `cc_release_endrangliste` | `releaseEndrangliste` | Ranglisten-Freigabe |

Phase 40.1 kann diese Tools ohne Re-Architektur ergänzen — das Pattern ist in
`lib/mcp_server/tools/finalize_teilnehmerliste.rb` vollständig dokumentiert.
