# Phase 40: MCP Server für ClubCloud-Schnittstelle - Research

**Researched:** 2026-05-07
**Domain:** Model Context Protocol (MCP) Ruby SDK + Rails 7.2-Embedded Server + ClubCloud-Wiederverwendung
**Confidence:** HIGH (SDK, mcp.json, Rails autoload), MEDIUM (Allowlist-Auswahl, JSON-Schema-Validation Strenge), LOW (StdioTransport Signal-Handling — undokumentiert)

## Summary

Phase 40 baut einen Ruby MCP-Server unter `lib/mcp_server/` mit Entry-Point `bin/mcp-server`, der bei jedem MCP-Client-Spawn die volle Rails-Umgebung bootet (~3–5 s einmalig), die offizielle `mcp` Gem (Anthropic, v0.15.0, Mai 2026) für JSON-RPC-Stdio-Dispatch nutzt, und drei Schichten exponiert: **(1) Workflow-Doku als statische Resources** (`cc://workflow/scenarios/*`, DE), **(2) Read-Lookups als Tools** über `RegionCc`/`LeagueCc`/`TournamentCc`-DB-Models mit Force-Refresh-Fallback auf den existierenden `RegionCc::ClubCloudClient`, **(3) Allowlist-Write-Tools** (Phase 40 ships ein Proof-Tool: `cc_finalize_teilnehmerliste` → CC-Action `releaseMeldeliste`).

Der entscheidende Hebel: `RegionCc::ClubCloudClient` ist bereits vollständig — HTTP, Session-Cookie, Multipart-POST, `armed`-Dry-Run-Konvention. Phase 40 muss **keine** neue HTTP-Schicht bauen, sondern instanziiert den Client mit Credentials aus ENV-Vars (`CC_USERNAME`, `CC_PASSWORD`, `CC_FED_ID`) und ruft seine bestehende API auf.

Drei kritische Pitfalls identifiziert: (a) **stdout-Verschmutzung** bricht JSON-RPC sofort — Rails.logger MUSS auf STDERR oder Datei umgeleitet werden, (b) **`lib/`-Autoload** ist in Rails 7.2 default-aktiv via `config.autoload_lib(ignore: …)` — `lib/mcp_server/` muss zur ignore-Liste **gerade nicht** hinzugefügt werden, da es Rails-Code enthält, ABER Zeitwerk's strenge Konstantennamenkonvention muss eingehalten werden, (c) **Signal-Handling in StdioTransport ist undokumentiert** — das Phase 40-Pattern muss SIGINT/SIGTERM selbst trappen.

**Primary recommendation:** Gem `mcp` ~> 0.15 zur Hauptgruppe des Gemfile, `bin/mcp-server` lädt `config/environment` und ruft `MCP::Server.new(name:, tools:, resources:)` mit `resources_read_handler`-Lambda für custom `cc://`-URIs, `MCP::Server::Transports::StdioTransport.new(server).open`. Read-Lookups sind `MCP::Tool`-Subklassen, die ApplicationRecord-Queries in-process ausführen. Write-Tools rufen `RegionCc::ClubCloudClient#post(action, params, armed: true)` auf.

## User Constraints (from CONTEXT.md)

### Locked Decisions

**A. Knowledge Surface**
- **D-01:** Vier Schichten — (1) Workflow-Doku als MCP-Resources, (2) technische CC-API-Surface (PATH_MAP) als Resources, (3) Read-Lookups als MCP-Tools, (4) Write-Aktionen als MCP-Tools (Allowlist).
- **D-02:** Live Lookups → Carambus-DB (`RegionCc`/`LeagueCc`/`TournamentCc`) by default; Force-Refresh / Cache-Miss → live `RegionCc::ClubCloudClient.get`.
- **D-03:** Write-Tools = Allowlist; jede erlaubte CC-Action = eigenes MCP-Tool mit JSON-Schema. Nicht-allowlisted Mutationen = unreachable.
- **D-04:** Curated ~10–20 high-value Aktionen aus PATH_MAP (~100), manuell mit Description + JSON-Schema, **keine Auto-Mapping**.
- **D-05:** Workflow-Doku-Resources in **DE** (Source ist DE, Audience DE).
- **D-06:** Custom URI-Schema `cc://...`. Beispiele: `cc://workflow/scenarios/teilnehmerliste-finalisieren`, `cc://api/showLeagueList`, `cc://carambus/region/2`.
- **D-07:** Workflow-Appendix (`clubcloud-admin-appendix-DRAFT.md`) per-Scenario gesplittet (5–7 Scenarios + Meta-Resources Rollenmodell + Glossar).

**B. Auth & CC-Backend**
- **D-08:** Default-Backend = **Production CC-API**. Mock-Mode via ENV-Flag `CARAMBUS_MCP_MOCK=1` für lokal/CI.
- **D-09:** Credentials per MCP-Client-Installation via `mcp.json`. Server liest `CC_USERNAME`, `CC_PASSWORD`, `CC_FED_ID` aus ENV. Jeder MCP-Client = Rechte des Users.
- **D-10:** Lazy-Login + In-Memory PHPSESSID-Cache mit TTL ~30 min. Auto-Reauth bei Session-Expiry.
- **D-11:** Permission-Validation für Write-Tools = **trust-CC-and-parse-error**. Keine Pre-Flight-Role-Lookups.

**C. Architektur & Stack**
- **D-12:** **Ruby**, Anthropic offizielle `mcp` Gem.
- **D-13:** Code unter `lib/mcp_server/`; Executable `bin/mcp-server`.
- **D-14:** **Stdio-only** in Phase 40. Kein Port, kein HTTP. HTTP/SSE deferred.
- **D-15:** `bin/mcp-server` bootet volle Rails-Env (`require_relative '../config/environment'`). ~3–5s Boot-Latenz einmalig.
- **D-16:** Tests unter `test/mcp_server/` mit Minitest. Mock-Mode für CC-Stubs. Coverage = Smoke-Test pro Tool/Resource + 1 E2E-Integrationstest.

**D. Zielgruppe**
- **D-17:** Zwei Audiences: (a) Carambus-Devs in Claude Code, (b) Turnierleiter/Sportwarts in Claude Desktop. Kein External, kein CI/Automation.
- **D-18:** Acceptance-Story: Turnierleiter fragt "wie finalisiere ich die Teilnehmerliste" → bekommt `cc://workflow/scenarios/teilnehmerliste-finalisieren` → Folgefrage "gibt es eine Teilnehmerliste in CC für Turnier X" → Read-Lookup-Tool antwortet.
- **D-19:** Write-Architektur **vollständig** implementiert; **eine** Write-Tool-Proof: `cc_finalize_teilnehmerliste` gegen Mock-Backend. Restliche ~3–5 Tools → Phase 40.1.
- **D-20:** Tool-Namen / Descriptions / JSON-Schemas in **EN**. Resource-Content bleibt DE (D-05).

### Claude's Discretion

- Exakte JSON-Schema-Field-Shapes pro Tool — Researcher und Planner verfeinern pro Tool.
- Interne Modul-Struktur unter `lib/mcp_server/` (Carambus-Konventionen anwenden).
- Logging-Strategy (Rails.logger vs. dedizierter MCP_LOGGER).
- Welche 5–7 Scenarios → D-07-Resources first.
- Form von `cc://api/*`-Resources (Raw PATH_MAP-Excerpt vs. strukturiert).
- Mock-Mode-Detail (VCR vs. handwritten Stubs).

### Deferred Ideas (OUT OF SCOPE)

- Full Write-Allowlist (~3–5 weitere Tools) → Phase 40.1.
- HTTP/SSE-Transport → Multi-User-Phase.
- External / API-Consumer-Audience → v8.0+.
- CI / Automation Use Case → Future Phase.
- PATH_MAP Auto-Mapping → No Phase Planned.
- `[SME-CONFIRM]` Auflösung → Phase 36c → v7.1 Phase F.
- Multi-Tenancy → out of scope.
- Pre-cached Role-Lookup → explizit verworfen.

## Project Constraints (from CLAUDE.md)

| Constraint | Compliance Required In Phase 40 |
|------------|--------------------------------|
| Ruby 3.2.1, Rails 7.2 | Verifiziert: `mcp` Gem fordert Ruby >= 2.7, kompatibel [VERIFIED: rubygems.org] |
| Minitest (NOT RSpec) | `test/mcp_server/*_test.rb` mit `ActiveSupport::TestCase` / `Minitest::Test` |
| `frozen_string_literal: true` in jedem `.rb` | Alle neuen Files unter `lib/mcp_server/` und `bin/mcp-server` |
| German Business-Comments / English Technical-Terms | Workflow-Resource-Content DE; Tool-Code-Comments DE für Business, EN für Technik |
| Service-Namespace `app/services/{ns}/` | NICHT anwendbar — MCP-Server lebt in `lib/`, nicht `app/services/` (D-13) |
| `LocalProtector` (`id < 50_000_000`) | MCP-Write-Tools, die CC-side-Records erzeugen, müssen lokale Server-Discipline respektieren. Tests deaktivieren via `LocalProtectorTestOverride` aus `test_helper.rb` |
| Conventional Commit Messages | `docs(40): …` / `feat(40): …` |
| `strong_migrations` enforced | Phase 40 ships keine Migrations — irrelevant |

## Phase Requirements

> **Hinweis:** CONTEXT.md liefert 20 lockierte Decisions (D-01..D-20) statt formaler REQ-IDs. Der Planner leitet REQ-IDs ab. Folgende Mapping-Tabelle macht die Forschungsbasis pro Decision explizit.

| Decision-ID | Description | Research Support |
|-------------|-------------|------------------|
| D-01 | Vier Schichten Knowledge | SDK unterstützt Tools + Resources + ResourceTemplates [VERIFIED: github.com/modelcontextprotocol/ruby-sdk] |
| D-02 | DB-first, CC-API-Fallback | `RegionCc`, `LeagueCc`, `TournamentCc` Models existieren; `RegionCc::ClubCloudClient.get` ist re-usable [VERIFIED: codebase] |
| D-04 | Curated PATH_MAP-Allowlist | PATH_MAP hat ~100 Entries; 9 Syncer zeigen welche Composite-Operations real genutzt werden [VERIFIED: club_cloud_client.rb, *_syncer.rb] |
| D-06 | `cc://...` URI-Scheme | SDK akzeptiert beliebige URI-Strings, kein Schema-Whitelist [VERIFIED: SDK README — "no special handling for custom schemes—they are treated as opaque identifiers"] |
| D-07 | 5–7 Scenarios als Resources | Appendix-DRAFT enthält 4 nummerierte Scenarios + 1 Rollenmodell-Sektion + 1 Credential-Delegation-Sektion (siehe §"Workflow Appendix Split" unten) |
| D-09 | Credentials per `mcp.json` ENV | Sowohl Claude Desktop als auch Claude Code unterstützen `env: {KEY: value}` in `mcpServers`-Config [VERIFIED: modelcontextprotocol.io/docs, code.claude.com/docs/en/mcp] |
| D-12 | Ruby Anthropic offizielle Gem | Gem `mcp` v0.15.0, Mai 2026, Owner Model Context Protocol/Shopify [VERIFIED: rubygems.org/gems/mcp] |
| D-13 | `lib/mcp_server/` Autoload | Rails 7.2 hat `config.autoload_lib(ignore: %w[assets generators tasks templates])` aktiv per Default — `lib/mcp_server/` wird automatisch durch Zeitwerk geladen [VERIFIED: config/application.rb:86] |
| D-14 | Stdio-only | `MCP::Server::Transports::StdioTransport` ist explizit in der Gem [VERIFIED: SDK README] |
| D-15 | Rails-Boot in `bin/mcp-server` | Standard Rails-Pattern via `require_relative '../config/environment'` [CITED: Rails Guides] |
| D-16 | Minitest unter `test/mcp_server/` | Konsistent mit Carambus-Konventionen (siehe `test/services/`, `test/integration/`) [VERIFIED: codebase] |
| D-19 | Proof-Tool `cc_finalize_teilnehmerliste` | PATH_MAP enthält `releaseMeldeliste` (Zeile 332) — exakt die Finalisierungs-Action, `read_only: false` [VERIFIED: club_cloud_client.rb:332-337] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `mcp` | ~> 0.15 (0.15.0 released 2026-05-04) | Official Anthropic MCP Ruby SDK | Einzige offizielle Anthropic-Implementierung. Alternative Gems (`fast-mcp`, `model-context-protocol-rb`, `ruby_llm-mcp`) sind Community-Forks ohne Anthropic-Sponsoring. D-12 verlangt explizit "Anthropic's offizielle Gem". [VERIFIED: rubygems.org/gems/mcp, github.com/modelcontextprotocol/ruby-sdk] |

**Installation:**

```ruby
# Gemfile (Hauptgruppe — production braucht es, kein :development)
gem "mcp", "~> 0.15"
```

```bash
bundle install
```

**Verifizierte Version (2026-05-07):**
```bash
$ npm view mcp version  # falsch — ist Ruby Gem
# Korrekt:
$ gem search ^mcp$ --remote --exact
*** REMOTE GEMS ***
mcp (0.15.0)   # Released 2026-05-04, 5,314,374 total downloads
```

[VERIFIED: rubygems.org/gems/mcp, fetched 2026-05-07]

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `json-schema` | >= 4.1 | Runtime dependency of `mcp` gem | Auto-installed; nutzbar für eigene Schema-Validation falls SDK-internal nicht ausreicht |
| `webmock` | bereits in `:test` | HTTP-Mocking für CC-API in Tests | D-08 Mock-Mode wenn `CARAMBUS_MCP_MOCK=1` — Pattern wie bestehende RegionCc-Tests |
| `vcr` | bereits in `:test` | Snapshot-basiertes HTTP-Recording | Optional für `test/snapshots/vcr/region_cc_*.yml`-Stil — bestehender Carambus-Standard |
| Minitest (Rails-builtin) | — | Test-Framework | D-16, project-standard |

**Bereits im Gemfile vorhanden, kein Add nötig:** `webmock`, `vcr`, `minitest` (via Rails), `nokogiri` (für CC-HTML-Parsing reuse).

### Alternatives Considered

| Instead of `mcp` | Could Use | Tradeoff |
|------------------|-----------|----------|
| `mcp` (Anthropic) | `fast-mcp` (yjacquin) | Schneller, aber Community-Fork, kein Anthropic-Backing — verletzt D-12 |
| `mcp` | `model-context-protocol-rb` (dickdavis) | Stdio + HTTP+Redis Production-Path; aber kleinere Community, D-12-Verletzung |
| `mcp` | `rails-mcp-server` (maquina-app) | Pre-built generic Rails-Server, aber generisch (nicht ClubCloud-spezifisch) und re-implementiert was wir custom brauchen |
| Stdio | HTTP/SSE | Phase 40 D-14 verbietet HTTP — Stdio ist gesetzt |
| `webmock`-only Mock | VCR-Cassettes | VCR matcht Carambus-Bestandsmuster (`test/snapshots/vcr/region_cc_*.yml`); WebMock einfacher für unit-level Stubs. **Empfehlung:** WebMock für Tool-Unit-Tests (handwritten Responses pro Action), VCR für E2E-Integration-Test (volle Roundtrip-Snapshots) |

## Architecture Patterns

### Recommended Project Structure

```
lib/
├── mcp_server/
│   ├── server.rb                    # MCP::Server-Wiring + Tool/Resource-Registry
│   ├── cc_session.rb                # In-Memory PHPSESSID-Cache mit TTL (D-10)
│   ├── tools/                       # 1 File pro Tool (EN-Names per D-20)
│   │   ├── base_tool.rb             # Common Helpers (cc_client, mock_mode?, error envelope)
│   │   ├── lookup_region.rb         # Read: cc_lookup_region
│   │   ├── lookup_league.rb         # Read: cc_lookup_league
│   │   ├── lookup_tournament.rb     # Read: cc_lookup_tournament
│   │   ├── lookup_teilnehmerliste.rb# Read: cc_lookup_teilnehmerliste (D-18 acceptance story)
│   │   └── finalize_teilnehmerliste.rb # Write proof tool (D-19) → releaseMeldeliste
│   ├── resources/
│   │   ├── workflow_scenarios.rb    # cc://workflow/scenarios/* (DE per D-05)
│   │   ├── workflow_meta.rb         # cc://workflow/roles, cc://workflow/glossary
│   │   └── api_surface.rb           # cc://api/<action> aus PATH_MAP-Excerpts
│   └── transport/
│       └── boot.rb                  # Rails-Env-Boot + StdioTransport-Open
bin/
└── mcp-server                       # Executable, ruft lib/mcp_server/transport/boot.rb
test/
└── mcp_server/
    ├── tools/
    │   ├── lookup_region_test.rb
    │   ├── lookup_teilnehmerliste_test.rb
    │   └── finalize_teilnehmerliste_test.rb
    ├── resources/
    │   └── workflow_scenarios_test.rb
    └── integration/
        └── stdio_e2e_test.rb        # Spawn bin/mcp-server, send JSON-RPC, assert
```

**Note:** Plan 38.4-D-13 etablierte `app/services/{ns}/` als Service-Konvention; aber MCP-Server lebt **außerhalb** der Standard-Rails-Request-Pipeline, also gehört unter `lib/`. Konsistent mit `lib/scenario_generator.rb`, `lib/markdown_converter.rb`, `lib/tournament_monitor_state.rb` (alle bereits unter `lib/`).

### Pattern 1: Server-Bootstrap in `bin/mcp-server`

**What:** Executable, das von MCP-Client gespawnt wird, Rails bootet, MCP-Server konfiguriert, blockierende Stdio-Loop startet.
**When to use:** Genau einmal als Entry-Point (D-13).
**Example:**

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true
# Source: SDK-README + Rails-Pattern für `bin/`-Executables

# 1. Rails-Boot — vor dem ersten require/MCP-call
ENV["RAILS_ENV"] ||= "production"
require_relative "../config/environment"

# 2. STDOUT muss SAUBER bleiben — JSON-RPC-Channel
# Rails.logger auf STDERR umlenken, damit `puts`/Logger-Output JSON-RPC nicht zerstört
Rails.logger = Logger.new($stderr)
Rails.logger.level = Logger::INFO
$stdout.sync = true

# 3. Server-Wiring
require "mcp_server/server"
server = McpServer::Server.build

# 4. Signal-Handler (SDK-undokumentiert, eigenes Pattern)
%w[INT TERM].each do |sig|
  Signal.trap(sig) do
    Rails.logger.info "[mcp-server] caught SIG#{sig}, exiting"
    exit 0
  end
end

# 5. Stdio-Transport öffnen (blockiert bis stdin EOF / Signal)
transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open
```

[CITED: github.com/modelcontextprotocol/ruby-sdk README — minimal stdio example]

### Pattern 2: Tool als Klasse (read_lookup-Beispiel)

```ruby
# frozen_string_literal: true
# lib/mcp_server/tools/lookup_region.rb

module McpServer
  module Tools
    class LookupRegion < MCP::Tool
      description "Look up a Carambus region by shortname (e.g. 'BCW') or CC fed_id."
      input_schema(
        properties: {
          shortname: { type: "string", description: "Region shortname like 'BCW'" },
          fed_id:    { type: "integer", description: "ClubCloud federation ID" },
          force_refresh: { type: "boolean", default: false, description: "Bypass DB cache, query CC live" }
        },
        # SDK validates types but anyOf-style required is manual:
        anyOf: [
          { required: ["shortname"] },
          { required: ["fed_id"] }
        ]
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(shortname: nil, fed_id: nil, force_refresh: false, server_context:)
        region = if force_refresh
          # D-02 Fallback: live CC-Call
          McpServer::CcSession.client.get("home", { fedId: fed_id })
          # ... parse + return
        else
          Region.find_by(shortname: shortname) || Region.joins(:region_cc).find_by(region_ccs: { cc_id: fed_id })
        end

        return error("Region not found") if region.nil?

        MCP::Tool::Response.new([{
          type: "text",
          text: region.to_json(only: [:id, :shortname, :name], include: { region_cc: { only: [:cc_id] } })
        }])
      end

      def self.error(msg)
        MCP::Tool::Response.new([{ type: "text", text: msg }], error: true)
      end
    end
  end
end
```

[CITED: SDK README — `MCP::Tool` subclass pattern]

### Pattern 3: Custom URI-Scheme `cc://...` Resource

```ruby
# frozen_string_literal: true
# lib/mcp_server/resources/workflow_scenarios.rb

module McpServer
  module Resources
    class WorkflowScenarios
      SCENARIOS = {
        "teilnehmerliste-finalisieren" => "Finalisierung der Teilnehmerliste in ClubCloud",
        "result-upload"                => "Upload von Spielergebnissen aus Carambus nach CC",
        "player-anlegen"               => "Anlegen eines neuen Spielers in der CC-Spielerdatenbank",
        "endrangliste-eintragen"       => "Manuelle Eintragung der Endrangliste in CC",
        "upload-fehler-recover"        => "Recovery bei fehlgeschlagenem Result-Upload"
      }.freeze

      def self.register(server)
        SCENARIOS.each do |slug, title|
          # SDK akzeptiert beliebige URI-Strings — `cc://...` wird als opaque identifier behandelt
          server.resources << MCP::Resource.new(
            uri: "cc://workflow/scenarios/#{slug}",
            name: "workflow-#{slug}",
            title: title,
            description: "ClubCloud-Workflow-Anleitung (DE) — Scenario: #{title}",
            mime_type: "text/markdown"
          )
        end

        server.resources_read_handler do |params|
          uri = params[:uri]
          if (slug = uri[%r{\Acc://workflow/scenarios/(.+)\z}, 1])
            md = read_scenario_markdown(slug)
            [{ uri: uri, mimeType: "text/markdown", text: md }]
          # ... weitere Branches für cc://workflow/roles, cc://api/*, etc.
          end
        end
      end

      def self.read_scenario_markdown(slug)
        # Workflow-Doku liegt in .planning/clubcloud-admin-appendix-DRAFT.md
        # Phase 40 splittet sie in docs/managers/clubcloud-scenarios/{slug}.de.md
        path = Rails.root.join("docs/managers/clubcloud-scenarios/#{slug}.de.md")
        path.exist? ? path.read : "# Scenario nicht gefunden\n\nUnknown scenario: #{slug}"
      end
    end
  end
end
```

[VERIFIED: SDK README — "Resource URIs are accepted as-is; no special handling for custom schemes — they are treated as opaque identifiers"]

### Pattern 4: Rails 7.2 `lib/`-Autoload via Zeitwerk

**Was Carambus heute hat** (`config/application.rb:86`):
```ruby
config.autoload_lib(ignore: %w[assets generators tasks templates])
```

Das bedeutet: **`lib/mcp_server/` wird automatisch von Zeitwerk geladen** — keine extra `autoload_paths`-Konfiguration nötig. Der `ignore`-Filter listet nur Subdirs ohne Ruby-Klassen. `lib/mcp_server/` enthält Ruby-Code → wird geladen. Alle Konstanten **müssen** Zeitwerk-Konvention folgen:

| File-Path | Required Constant |
|-----------|-------------------|
| `lib/mcp_server/server.rb` | `McpServer::Server` |
| `lib/mcp_server/tools/lookup_region.rb` | `McpServer::Tools::LookupRegion` |
| `lib/mcp_server/cc_session.rb` | `McpServer::CcSession` |
| `lib/mcp_server/resources/workflow_scenarios.rb` | `McpServer::Resources::WorkflowScenarios` |

**Pitfall:** "MCP" oder "mcp_server" als top-level Konstante würde Zeitwerk-Fehler werfen (Ruby-camelCase-Konvention: `McpServer`, NICHT `MCPServer`). Inflector-Custom-Acronyms wären möglich aber unnötiger Komplexität — `McpServer` reicht.

[VERIFIED: config/application.rb:86, Rails 7.2 autoload_lib docs]

### Anti-Patterns to Avoid

- **`puts`/`print`/`p` im Server-Code:** Bricht JSON-RPC-Protokoll. Alle Diagnostik geht über `Rails.logger` (auf STDERR umgeleitet) oder explizit via `MCP::Server#notify_log_message`. [VERIFIED: SDK README — "Never use puts or print, as they write to standard output (stdout) by default. Writing to stdout will corrupt the JSON-RPC messages and break your server."]
- **Re-Implementierung der HTTP-Schicht:** `RegionCc::ClubCloudClient` ist vollständig (GET/POST/Multipart, Cookie, Dry-Run). Neuer HTTP-Code in `lib/mcp_server/` = Smell.
- **Globale Server-Instanz im Modul-Scope:** Würde Test-Isolation brechen. `McpServer::Server.build` als Builder; tests bauen eigene Instanz.
- **Auto-Mapping aller PATH_MAP-Entries auf Tools:** D-04 verbietet das. Auto-Generated Tools haben keine semantischen Descriptions, keine Parameter-Dokumentation, kein curated Schema.
- **Resource-Content auf EN übersetzen:** D-05 verlangt DE. Tool-Surface (Names/Descriptions) ist EN per D-20 — nicht durchmischen.
- **Zeitwerk-incompatible Konstanten:** `MCPServer` (Acronym ohne Custom-Inflector) wirft beim Boot. Konsequent `McpServer` nutzen.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MCP JSON-RPC-Envelope | Eigene JSON-RPC-Server-Loop | `mcp` Gem `MCP::Server` + `MCP::Server::Transports::StdioTransport` | Subtilien wie initialize-handshake, capability-negotiation, request-id-tracking, notifications/list-changed |
| ClubCloud HTTP | Eigener Net::HTTP-Wrapper | `RegionCc::ClubCloudClient` | PHPSESSID-Cookie, Multipart, Dry-Run, Referer-Handling — alles bereits vorhanden, getestet (siehe `test/snapshots/vcr/region_cc_http_*.yml`) |
| CC-Action-Routing | Eigene URL-Map | `RegionCc::ClubCloudClient::PATH_MAP` | 100+ Actions mit `read_only`-Flag bereits maintained |
| HTML-Parsing CC-Responses | Regex-Strings | `Nokogiri` (bereits Dependency) + Pattern aus 9 Syncern | 9 Syncer demonstrieren CSS-Selektor-Patterns für jede CC-Response-Struktur |
| Region/League/Tournament-Lookups | Direkte SQL-Queries | `Region`, `LeagueCc`, `TournamentCc` ActiveRecord-Models | LocalProtector + Translatable + Source-Handler-Concerns sind bereits korrekt integriert |
| Mock-Backend | Custom-Stub-Server | WebMock + bestehende VCR-Cassettes unter `test/snapshots/vcr/region_cc_*.yml` | Project-Standard, Testers kennen das Pattern |
| Process-spawn-and-pipe (E2E-Test) | Threads + IO.pipe | `IO.popen("bin/mcp-server", "r+")` | Standard Ruby-Pattern, Minitest-kompatibel |
| Workflow-Doc-Markdown-Parser | Eigener Parser | `redcarpet` (bereits Dependency) wenn Rendering nötig — sonst raw Markdown-Text als Resource | Markdown-Pass-Through reicht für MCP-Resources |

**Key insight:** Alle 8 deceptively-complex Probleme haben bereits Lösungen im Carambus-Repo oder in der `mcp` Gem. Phase 40's Eigenanteil = Glue-Code (Server-Wiring, Tool-Klassen, Resource-Registrations) + 1 Proof-Write-Tool.

## Common Pitfalls

### Pitfall 1: STDOUT-Pollution bricht JSON-RPC sofort

**What goes wrong:** Ein einziger `puts "..."` oder `Rails.logger.info` (default → STDOUT) im Server-Code zerstört den JSON-RPC-Stream — Claude Desktop / Code zeigt "Server disconnected" oder gar keine Antwort.
**Why it happens:** StdioTransport nutzt STDOUT als JSON-RPC-Channel. Jede non-JSON-Zeile ist Protokoll-Verletzung.
**How to avoid:**
1. In `bin/mcp-server` SOFORT nach Rails-Boot: `Rails.logger = Logger.new($stderr)`.
2. Brakeman-/grep-Audit vor Phase-Closure: `grep -rn '\bputs\b\|\bprint\b\| p ' lib/mcp_server/ bin/mcp-server` — muss leer sein.
3. Test-Pattern: E2E-Test parsed nur valide JSON von STDOUT; jede invalide Zeile = Test-Failure.
**Warning signs:** "Server disconnected" in Claude Desktop ohne klare Fehlermeldung; Logs in `~/Library/Logs/Claude/mcp-server-carambus.log` zeigen JSON-Parse-Errors.

[VERIFIED: SDK README — explicit warning: "Never use puts or print"]

### Pitfall 2: Zeitwerk-Konstanten-Mismatch beim Rails-Boot

**What goes wrong:** `lib/mcp_server/server.rb` definiert `module MCPServer` (uppercase) → Zeitwerk erwartet `McpServer` per Default-Inflector → `Zeitwerk::NameError` → Rails-Boot stirbt → MCP-Client sieht "Server failed to start".
**Why it happens:** Rails 7.2 default `autoload_lib` lädt `lib/` mit strict Zeitwerk-Inflector. "MCP" als Acronym müsste explizit registriert werden via `Rails.autoloaders.main.inflector.inflect("mcp" => "MCP")`.
**How to avoid:** Konsequent **`McpServer`** als Top-Level-Modul (snake_case → CamelCase ohne Acronym-Sonderbehandlung).
**Warning signs:** `Zeitwerk::NameError: expected file lib/mcp_server/server.rb to define constant MCPServer::Server, but didn't`.

### Pitfall 3: Rails-Boot-Latenz übersteigt MCP-Client-Timeout

**What goes wrong:** Carambus' Rails-Boot dauert ~3–5 s (große Codebase, viele Gems). Claude Desktop default-MCP-Server-Timeout = 60 s, Claude Code = via `MCP_TIMEOUT` ENV-Var konfigurierbar (default 30 s laut Doku).
**Why it happens:** Volle Rails-Env mit Bootsnap, Eager-Loading aller Models, Initializers. Im Production-Env mit eager_load=true + Bootsnap-Cache ist das warm ~2 s, kalt ~5 s.
**How to avoid:**
1. `bin/mcp-server` lazy-Loaded ApplicationRecord-Subklassen NICHT — Rails ist eh komplett da.
2. Bootsnap-Cache-Path explizit setzen damit erster Run auf neuem Machine nicht kalt-bootet.
3. Falls > 10 s: lazy-load `RegionCc::ClubCloudClient` erst beim ersten Tool-Call (statt im Constructor).
4. Document `MCP_TIMEOUT=15000` als empfohlenes ENV in der Setup-Anleitung für Endbenutzer.
**Warning signs:** Claude Code zeigt "MCP server timed out during startup".

[CITED: code.claude.com/docs/en/mcp — `MCP_TIMEOUT` env var documented]

### Pitfall 4: Session-Cookie-Ablauf bricht Write-Tool ohne Reauth

**What goes wrong:** D-10 verlangt "transparent re-login on session expiry". Ohne diese Logik schlägt `cc_finalize_teilnehmerliste` nach 30 min Idle fehl mit confusing CC-Login-Redirect-HTML statt klarem Error.
**Why it happens:** PHPSESSID-Cookie hat ~30 min TTL CC-side. `RegionCc::ClubCloudClient` macht **keinen** Auto-Reauth — der Login-Flow lebt heute in `RegionCc#login` und ist nicht Teil des Standalone-Clients.
**How to avoid:**
1. `McpServer::CcSession`-Wrapper: hält PHPSESSID, ruft `client.get(action, ...)`, prüft Response auf Login-Redirect (`<form action=".../login.php">` o.ä.), bei Match → 1× Reauth + Retry.
2. Reauth = `client.post("login", {username:, password:}, ...)` (existing Pattern aus `RegionCc#login`).
3. Test: WebMock-Stub gibt erst Login-Redirect-HTML zurück, dann (nach Reauth-Call) das echte Result.
**Warning signs:** Tool-Response enthält `<form action="login.php">` oder leere `doc.css(...)`-Selektoren nach 30 min Idle.

### Pitfall 5: Mock-Mode "leakt" — Tests treffen echte CC-API

**What goes wrong:** Test vergisst `CARAMBUS_MCP_MOCK=1` zu setzen → Test trifft echtes ClubCloud → produktive Daten kontaminiert.
**Why it happens:** ENV-Flag-basierte Mocks haben kein Default-Sicherheitsnetz.
**How to avoid:**
1. `test_helper.rb` (oder `test/mcp_server/test_helper.rb`) setzt `ENV["CARAMBUS_MCP_MOCK"] = "1"` global.
2. WebMock global aktivieren: `WebMock.disable_net_connect!(allow_localhost: true)` (bereits Carambus-Standard).
3. `McpServer::CcSession` raise't `RuntimeError` wenn `Rails.env.test?` UND `CARAMBUS_MCP_MOCK != "1"` UND ein echter HTTP-Call versucht wird.
**Warning signs:** Test-Run dauert >10 s (echtes Network-IO); CI-Logs zeigen unerwartete CC-Connection-Strings.

### Pitfall 6: JSON-Schema-Validation ist NICHT automatisch streng

**What goes wrong:** Tool-Definition deklariert `required: ["fed_id"]`, aber LLM ruft ohne `fed_id` auf → SDK ruft `self.call(...)` ohne den Argument → Ruby-`ArgumentError: missing keyword: fed_id` → SDK fängt + sendet generic "Internal error" → Endbenutzer sieht keinen klaren Hinweis was falsch lief.
**Why it happens:** SDK-README beschreibt `input_schema` als **deskriptiv für Client-Konsum**, nicht als Runtime-Validation-Gate. [CITED: SDK README — Schema appears as metadata, not enforced]
**How to avoid:**
1. Tool-Methoden defensiv: alle Parameter mit Default `nil`, manuelles `validate!` am Anfang von `call`.
2. Bei Validation-Failure: `MCP::Tool::Response.new([{ type: "text", text: "Missing required parameter: fed_id" }], error: true)`.
3. Optional: `json-schema` Gem (bereits transitive Dependency!) explizit in `BaseTool#validate_input!` aufrufen mit dem registrierten Schema.
**Warning signs:** "Internal error occurred" als generic Antwort statt informativer Validation-Fehlermeldung.

[VERIFIED: SDK README error handling — "For tool calls, a generic error response is returned: { error: 'Internal error occurred', isError: true }"]

### Pitfall 7: Workflow-Resources sind statisch — Doc-Promotion überschreibt sie nicht automatisch

**What goes wrong:** Phase 36c hat `clubcloud-admin-appendix-DRAFT.md` mit `[SME-CONFIRM]`-Markern. Phase 40 splittet diese in MCP-Resources. Wenn später (Phase F doc-promotion) die SME-Bestätigungen reinkommen, müssen die Resource-Files synchron sein.
**Why it happens:** Docs sind in `docs/` (für mkdocs-Build), Resources serven dieselbe Substanz aus `docs/managers/clubcloud-scenarios/*.de.md`.
**How to avoid:** Resource-File-Path = `docs/managers/clubcloud-scenarios/{slug}.de.md` (NICHT `lib/mcp_server/resources/...md`). Doc-Promotion-Workflow updated automatisch sowohl mkdocs-Build als auch MCP-Resource-Inhalt.
**Warning signs:** Resource-Antwort enthält veraltete `[SME-CONFIRM]`-Marker, obwohl Phase F sie längst geklärt hat.

### Pitfall 8: Stdio-Transport hat **kein** dokumentiertes Signal-Handling

**What goes wrong:** SIGTERM bei MCP-Client-Shutdown lässt Ruby-Process zombie-zurück, oder ungesaubertes Cleanup → halb-geschriebener PHPSESSID-Cache, hängende DB-Connection.
**Why it happens:** SDK-README beschreibt `transport.open` als blocking; nichts über `transport.close` oder Signal-Trapping.
**How to avoid:** Eigenes `Signal.trap("INT") { exit 0 }` + `Signal.trap("TERM") { exit 0 }` in `bin/mcp-server` (siehe Pattern 1 oben).
**Warning signs:** `ps aux | grep mcp-server` zeigt ge-killte aber nicht-aufgeräumte Prozesse.

[VERIFIED: SDK README signal handling explicitly NOT documented — confirmed by direct README inspection]

## Code Examples

### Example 1: Minimal Stdio-Server-Skelett

```ruby
# Source: github.com/modelcontextprotocol/ruby-sdk README (verbatim adapted)
require "mcp"

class ExampleTool < MCP::Tool
  description "A simple example tool that echoes back its arguments"
  input_schema(
    properties: { message: { type: "string" } },
    required: ["message"]
  )

  def self.call(message:, server_context:)
    MCP::Tool::Response.new([{ type: "text", text: "Hello: #{message}" }])
  end
end

resource = MCP::Resource.new(
  uri: "cc://workflow/scenarios/example",
  name: "example-resource",
  title: "Example",
  description: "Demo",
  mime_type: "text/markdown"
)

server = MCP::Server.new(
  name: "carambus_clubcloud",
  tools: [ExampleTool],
  resources: [resource]
)

server.resources_read_handler do |params|
  [{ uri: params[:uri], mimeType: "text/markdown", text: "Hello from #{params[:uri]}" }]
end

transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open
```

[VERIFIED: SDK README]

### Example 2: Write-Tool — `cc_finalize_teilnehmerliste` (D-19 Proof)

```ruby
# frozen_string_literal: true
# lib/mcp_server/tools/finalize_teilnehmerliste.rb

module McpServer
  module Tools
    class FinalizeTeilnehmerliste < MCP::Tool
      tool_name "cc_finalize_teilnehmerliste"  # Falls SDK Class-Name-Mapping verwendet
      description <<~DESC
        Finalize (release) a Meldeliste in ClubCloud, locking the participant list.
        After finalization, CC accepts result uploads for this tournament.
        Requires Club-Sportwart or higher CC role.
      DESC
      input_schema(
        properties: {
          fed_id:        { type: "integer", description: "ClubCloud federation ID" },
          branch_id:     { type: "integer", description: "CC branch (e.g. 10 for Karambol)" },
          season:        { type: "string",  description: "Season name like '2025/2026'" },
          meldeliste_id: { type: "integer", description: "CC meldelisteId of the participant list" },
          armed:         { type: "boolean", default: false, description: "If false, dry-run only — no CC mutation" }
        },
        required: ["fed_id", "branch_id", "season", "meldeliste_id"]
      )
      annotations(read_only_hint: false, destructive_hint: true)

      def self.call(fed_id:, branch_id:, season:, meldeliste_id:, armed: false, server_context:)
        client = McpServer::CcSession.client_for(server_context)
        # Reuse RegionCc::ClubCloudClient — D-19 verifiziert: PATH_MAP['releaseMeldeliste'] existiert
        res, doc = client.post("releaseMeldeliste",
          { branchId: branch_id, fedId: fed_id, season: season, meldelisteId: meldeliste_id, release: "" },
          { armed: armed, session_id: McpServer::CcSession.cookie }
        )

        if armed && res&.code != "200"
          # D-11: trust-CC-and-parse-error
          err = parse_cc_error(doc)
          return MCP::Tool::Response.new([{ type: "text", text: "CC rejected: #{err}" }], error: true)
        end

        verb = armed ? "Finalized" : "Would finalize (dry-run)"
        MCP::Tool::Response.new([{
          type: "text",
          text: "#{verb} Meldeliste #{meldeliste_id} for branch #{branch_id}, season #{season}."
        }])
      end

      def self.parse_cc_error(doc)
        # CC returns errors as <div class="error">...</div> or login-redirect
        return "Session expired (login redirect)" if doc&.css("form[action*=login]")&.any?
        doc&.css("div.error")&.text&.strip&.presence || "Unknown CC error"
      end
    end
  end
end
```

[VERIFIED: PATH_MAP entry `"releaseMeldeliste" => ["/admin/einzel/meldelisten/releaseMeldeliste.php", false]` at club_cloud_client.rb:332-337]

### Example 3: E2E-Stdio-Test mit IO.popen (D-16)

```ruby
# frozen_string_literal: true
# test/mcp_server/integration/stdio_e2e_test.rb

require "test_helper"
require "json"

class McpServer::Integration::StdioE2ETest < ActiveSupport::TestCase
  test "spawns bin/mcp-server and answers initialize + tools/list" do
    skip "Skipped on CI without Rails-Env-warmup" if ENV["CI"]
    ENV["CARAMBUS_MCP_MOCK"] = "1"

    IO.popen([Rails.root.join("bin/mcp-server").to_s], "r+") do |pipe|
      # 1. MCP Initialize-Handshake
      send_jsonrpc(pipe, id: 1, method: "initialize", params: {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: { name: "test", version: "1.0" }
      })
      response = read_jsonrpc(pipe)
      assert_equal "carambus_clubcloud", response.dig("result", "serverInfo", "name")

      # 2. tools/list
      send_jsonrpc(pipe, id: 2, method: "tools/list")
      response = read_jsonrpc(pipe)
      tool_names = response.dig("result", "tools").map { |t| t["name"] }
      assert_includes tool_names, "cc_finalize_teilnehmerliste"
      assert_includes tool_names, "cc_lookup_region"

      # 3. resources/list
      send_jsonrpc(pipe, id: 3, method: "resources/list")
      response = read_jsonrpc(pipe)
      uris = response.dig("result", "resources").map { |r| r["uri"] }
      assert_includes uris, "cc://workflow/scenarios/teilnehmerliste-finalisieren"

      # Cleanup: schliesst stdin -> Server beendet sich
      pipe.close_write
    end
  end

  private

  def send_jsonrpc(pipe, id:, method:, params: {})
    pipe.puts({ jsonrpc: "2.0", id: id, method: method, params: params }.to_json
  end

  def read_jsonrpc(pipe)
    line = pipe.readline
    JSON.parse(line)
  end
end
```

**Notiz:** Der Test bootet die volle Rails-Env in einem Subprocess — langsam (~5 s). Daher als **eine** E2E-Suite per Phase, nicht pro Tool. Pro-Tool-Smoke-Tests bleiben in-process (siehe Pattern 2).

### Example 4: Claude Desktop `claude_desktop_config.json`

**Path (macOS):** `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "carambus_clubcloud": {
      "command": "/Users/gullrich/DEV/carambus/carambus_api/bin/mcp-server",
      "args": [],
      "env": {
        "CC_USERNAME": "your-cc-login@example.com",
        "CC_PASSWORD": "your-cc-password",
        "CC_FED_ID": "20",
        "CARAMBUS_MCP_MOCK": "0",
        "RAILS_ENV": "production"
      }
    }
  }
}
```

[VERIFIED: modelcontextprotocol.io/docs/develop/connect-local-servers — exact JSON shape documented]

### Example 5: Claude Code `.mcp.json` (Project-Scoped)

**Path:** `.mcp.json` im Project-Root (Carambus-Repo).

```json
{
  "mcpServers": {
    "carambus_clubcloud": {
      "command": "${PWD}/bin/mcp-server",
      "args": [],
      "env": {
        "CC_USERNAME": "${CC_USERNAME}",
        "CC_PASSWORD": "${CC_PASSWORD}",
        "CC_FED_ID": "${CC_FED_ID:-20}",
        "CARAMBUS_MCP_MOCK": "${CARAMBUS_MCP_MOCK:-0}"
      }
    }
  }
}
```

**Key feature von Claude Code:** `${VAR}` und `${VAR:-default}` Variable-Expansion in `command`, `args`, `env`. Dev kann `CC_USERNAME` aus eigenem Shell-Env ziehen, ohne sie in die committete `.mcp.json` zu schreiben. [VERIFIED: code.claude.com/docs/en/mcp — "Environment variable expansion in .mcp.json"]

**User-scoped Alternative:** `claude mcp add carambus_clubcloud --scope user --env CC_USERNAME=... --env CC_PASSWORD=... -- bin/mcp-server` — schreibt in `~/.claude.json`, nicht in `.mcp.json`. User-Scope ist für Phase-40-Endbenutzer (Turnierleiter) plausibler als Project-Scope (das wäre nur für Carambus-Dev-Team selbst).

## Mock-Mode Strategy (D-08)

**Empfohlen: Hybrid-Pattern.**

| Layer | Tool | Pattern |
|-------|------|---------|
| Tool-Unit-Tests | WebMock | Pro Test: `stub_request(:post, /releaseMeldeliste/).to_return(body: "<html>...</html>")` |
| Integration-Test (E2E spawn) | VCR | `test/snapshots/vcr/mcp_server/finalize_teilnehmerliste.yml` — Cassette aufgenommen einmalig im armed-Mode gegen Staging-CC |
| Server-Runtime mit `CARAMBUS_MCP_MOCK=1` | In-Memory-Stub-Class | `McpServer::CcSession.client_for(...)` returned `McpServer::MockClient.new` (eine Klasse mit identischer Interface zu `RegionCc::ClubCloudClient`, hardcoded Fixture-Responses) |

**Warum nicht reine VCR:** VCR ist HTTP-Layer-Mock; aber wenn `CARAMBUS_MCP_MOCK=1` an Endbenutzer/Demo-Sessions ausgeliefert wird, soll das auch ohne `webmock`-Gem im Production-Build funktionieren. Eine eigene `MockClient`-Klasse umgeht das.

**Carambus-Pattern-Match:** `test/snapshots/vcr/region_cc_http_get.yml`, `region_cc_http_post.yml` etc. existieren bereits — neue Cassetten unter `test/snapshots/vcr/mcp_server/` einreihen ist konsistent.

## Workflow Appendix Split (D-07 Empfehlung)

**Quelle:** `.planning/clubcloud-admin-appendix-DRAFT.md` (255 Zeilen, Phase 36c, 2026-04-14).

**Identifizierte Scenarios + Bewertung:**

| Scenario | Slug für `cc://workflow/scenarios/{slug}` | `[SME-CONFIRM]`-Marker | Empfehlung Phase 40 |
|----------|--------------------------------------------|------------------------|----------------------|
| 1. Teilnehmerliste finalisieren | `teilnehmerliste-finalisieren` | 2 (mild — Fehlertext, UI-Wording) | **JA — Top-Priority** (D-18 Acceptance-Story) |
| 2. Player nicht in CC-DB | `player-anlegen` | 4 (Guest-Mechanik unklar, Preflight-Verhalten unklar) | **JA — sekundär** (klare Workflow-Triage) |
| 3. Endrangliste in CC | `endrangliste-eintragen` | 1 (mild — automatische Berechnung ja/nein) | **JA — sekundär** (klare 2-Path-Trennung today/v7.1) |
| 4. Upload-Failure-Recovery | `upload-fehler-recover` | 3 (heavy — heutiges Verhalten unklar) | **NEIN — defer** (zu viel Unsicherheit, Resource würde mehr `[SME-CONFIRM]` als Inhalt enthalten) |
| Rollenmodell-Tabelle | `cc://workflow/roles` (Meta-Resource) | 1 (Tabelle-Header) | **JA** — kompakt, hoher Wert |
| Credential-Delegation | `cc://workflow/credential-delegation` | 4 (alle 4 Patterns markiert) | **NEIN — defer** (sektion ist überwiegend Annahmen) |
| Glossar (impliziert aus DRAFT) | `cc://workflow/glossary` (Meta-Resource) | — | **JA** — extrahiert aus den Resource-Fußnoten |

**Phase-40-Ship-Set (5 Resources):**
1. `cc://workflow/scenarios/teilnehmerliste-finalisieren` — pflicht für D-18.
2. `cc://workflow/scenarios/player-anlegen` — sekundär, klar genug.
3. `cc://workflow/scenarios/endrangliste-eintragen` — sekundär, klar genug.
4. `cc://workflow/roles` — Rollen-Tabelle als Meta.
5. `cc://workflow/glossary` — Begriffe (Sportwart-Ebenen, Branch, Meldeliste, etc.).

**`[SME-CONFIRM]`-Marker bleiben in Resource-Content unverändert** (per Spec-Decision).

## Curated PATH_MAP Allowlist (D-04 Empfehlung)

Aus den 9 Syncern abgeleitet, welche PATH_MAP-Actions tatsächlich Business-Composite-Operations darstellen:

### Read-Tools (10 — `read_only: true`)

| Tool-Name (EN, D-20) | PATH_MAP Action | Used by Syncer | Why High-Value |
|----------------------|-----------------|-----------------|----------------|
| `cc_lookup_region` | (DB-only, fallback `home`) | — | D-18 acceptance story foundation |
| `cc_lookup_league` | `showLeague`, `showLeagueList` | `league_syncer.rb` | D-18 — finde League per fed_id+branch+season |
| `cc_lookup_tournament` | `showMeisterschaft`, `showMeisterschaftenList` | `tournament_syncer.rb` | D-18 acceptance story — "gibt es ein Turnier X in CC" |
| `cc_lookup_teilnehmerliste` | `showMeldeliste`, `showMeldelistenList` | `registration_syncer.rb` | D-18 — direkter Verfügbarkeitscheck der Meldeliste |
| `cc_lookup_team` | `showTeam`, `showLeague_show_teamplayer` | `league_syncer.rb` | Common-secondary-Lookup |
| `cc_lookup_club` | `showClubList`, `showAnnounceList` | `club_syncer.rb` | Player-Anlegen-Workflow-Support |
| `cc_lookup_spielbericht` | `spielbericht`, `spielberichte` | `party_syncer.rb` | Result-Upload-Diagnose |
| `cc_lookup_category` | `showCategory`, `showCategoryList` | `tournament_syncer.rb` | Type-Code-Lookups |
| `cc_lookup_serie` | `showSerie`, `showSerienList` | `tournament_syncer.rb` | Saison-Series-Übersicht |
| `cc_search_player` | `suche` | (cross-syncer) | Player-Anlegen-Vorprüfung |

### Write-Tools (3–5 — `read_only: false`)

| Tool-Name (EN, D-20) | PATH_MAP Action | Phase-40-Status | Why High-Value |
|----------------------|-----------------|------------------|----------------|
| **`cc_finalize_teilnehmerliste`** | **`releaseMeldeliste`** | **Phase 40 SHIPS (D-19 proof)** | D-18 Acceptance — Sportwart-Top-Workflow |
| `cc_create_team` | `showLeague_create_team_save` | Phase 40.1 | Saison-Anfang-Workflow |
| `cc_add_player_to_team` | `showLeague_add_teamplayer` | Phase 40.1 | Player-Anlegen-Workflow-Vollendung |
| `cc_upload_result` | `spielberichtSave` | Phase 40.1 | Result-Upload (komplexes JSON-Schema mit pid/sc/in/br pro Game) |
| `cc_release_endrangliste` | `releaseRangliste.php` | Phase 40.1 (oder weiter defer) | Endrangliste-Finalisierung |

**Begründung der ~13-Tool-Größe:** D-04 nennt "10–20"; 13 ist innerhalb der Range, lehnt sich aber tendenziell ans untere Ende → minimiert curated-Schema-Maintenance, deckt aber alle 4 D-07-Scenarios ab.

**Verifikation `releaseMeldeliste` für D-19:**
- PATH_MAP-Eintrag: `"releaseMeldeliste" => ["/admin/einzel/meldelisten/releaseMeldeliste.php", false]` (Zeile 332)
- `read_only: false` → Mutation, Dry-Run-fähig via `armed`-Flag
- Parameter aus Comment (Zeilen 333–337): `branchId`, `fedId`, `season`, `meldelisteId`, `release: ""`
- Klar definierte Finalization-Action — passt exakt zu D-19's "finalization-style mutation" Anforderung

[VERIFIED: club_cloud_client.rb:332-337]

## Runtime State Inventory

> Phase 40 ist eine **Greenfield-Phase** (neuer Server, neuer Code unter `lib/mcp_server/` und `bin/`). Kein Rename, kein Refactor, keine Migration existierender Daten. Diese Sektion dokumentiert leere Kategorien explizit, statt sie wegzulassen.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — keine bestehenden Records werden umbenannt oder migriert. PHPSESSID-Cache ist In-Memory only (D-10). | None |
| Live service config | None initially. Nach Ship: jede MCP-Client-Installation hat eigene `mcp.json` mit `command`/`env` — diese Config lebt **außerhalb** des Carambus-Repos (in `~/Library/Application Support/Claude/...` resp. `~/.claude.json`). | Setup-Doku für Endbenutzer (Turnierleiter); kein Carambus-Server-State-Change |
| OS-registered state | None — `bin/mcp-server` wird vom MCP-Client als Subprocess gespawnt, nicht als systemd/launchd-Unit registriert. Kein cron, kein PM2. | None |
| Secrets/env vars | NEU: `CC_USERNAME`, `CC_PASSWORD`, `CC_FED_ID`, `CARAMBUS_MCP_MOCK`. Diese werden **nicht** in `config/credentials/*.yml.enc` gelegt (D-09 — per-MCP-Client-Installation). Existing CC-Auth in Carambus.config bleibt unverändert. | Keine Secret-Migration; Setup-Doku zeigt Benutzern wo sie ihre eigenen Credentials in der `mcp.json` ablegen |
| Build artifacts | None initially. Nach Ship: `bin/mcp-server` als File im Repo (committed), executable-Bit gesetzt. Kein Compile, kein C-Extension. | `chmod +x bin/mcp-server` im Plan-Setup-Task |

**Canonical question check:** *Nach Ship — was hat der MCP-Client gecached, gespeichert oder registriert?*
→ **Nichts auf Carambus-Server-Seite.** MCP-Client (Claude Desktop / Code) führt `bin/mcp-server` als ephemeren Subprocess aus, beendet ihn bei Konversations-Ende. Kein persistenter State außer der `mcp.json`-Config-Datei beim Endbenutzer.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Ruby | Existing Rails App | ✓ | 3.2.1 (.ruby-version) | — |
| Bundler | Gem-Install | ✓ | 2.7.2 | — |
| `mcp` Gem | D-12 | ✗ (noch nicht im Gemfile) | 0.15.0 verfügbar | None — Phase 40 Plan 01 = `bundle add mcp` |
| `nokogiri` | CC-HTML-Parsing | ✓ | bereits Dep, >=1.12.5 | — |
| `webmock` | Tests D-16 | ✓ | bereits in `:test` | — |
| `vcr` | Tests D-16 | ✓ | bereits in `:test` | — |
| Rails-Env Boot | D-15 | ✓ | 7.2.0.beta2 | — |
| PostgreSQL | DB-Lookups (D-02) | ✓ | (project requirement) | — |
| ClubCloud Production | Default Backend (D-08) | external | n/a | `CARAMBUS_MCP_MOCK=1` aktiviert In-Memory-Stub |
| Claude Desktop / Claude Code | End-Client | external (User-Install) | latest | None — Setup-Doku verweist auf claude.ai/download bzw. code.claude.com |

**Missing dependencies with no fallback:** Keine — `mcp` Gem ist via `bundle install` direkt verfügbar.

**Missing dependencies with fallback:** ClubCloud Production-API → `CARAMBUS_MCP_MOCK=1`-Path für lokal/CI/Demo.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Custom JSON-RPC-Server pro AI-Integration | MCP-Standard (Anthropic, 2024) | Nov 2024 release; Ruby SDK April 2025 | Ein Server, viele Clients (Claude Desktop, Claude Code, Continue, etc.) |
| MCP-Servers in TypeScript / Python | Ruby-SDK offiziell verfügbar | Apr 2025 (gem `mcp` 0.x) | Carambus kann Ruby-Server in-process bauen (D-12) |
| `lib/`-Autoload via `config.autoload_paths << Rails.root.join("lib")` | Rails 7.2 default `config.autoload_lib(ignore: …)` | Rails 7.1+ | Carambus nutzt es bereits (`config/application.rb:86`) — keine Konfig-Änderung nötig |
| `puts` für Server-Logs | Rails.logger zu STDERR + `MCP::Server#notify_log_message` | MCP-Protokoll-Anforderung | KEIN STDOUT-Output |

**Deprecated/outdated:** Keine direkt für diese Phase relevanten deprecations. SDK ist neu, hat noch kein "v1.0 stable" — was MEDIUM Confidence für API-Stabilität bedeutet (siehe Confidence-Breakdown).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | StdioTransport's `transport.open` blockiert bis stdin-EOF | Pattern 1 | LOW — verifiziert im SDK-README minimal example; aber Verhalten bei Signal NICHT dokumentiert. Plan-Task: kurz manuell verifizieren beim ersten run |
| A2 | `MCP::Tool#input_schema` ist deskriptiv, nicht runtime-validation | Pitfall 6 | LOW — direktes README-Zitat verfügbar. Aber Edge-Cases (z.B. type-coercion) ungetestet — Plan-Task: BaseTool-Helper schreiben, der explizit validates |
| A3 | Claude Code `MCP_TIMEOUT` default 30 s (vs. 60 s) | Pitfall 3 | LOW — exakter Default nicht in offizieller Doku gefunden, nur "configurable via env". Mitigation: Setup-Doku empfiehlt explizit `MCP_TIMEOUT=15000` |
| A4 | Rails-Boot von Carambus dauert 3–5 s (Production-Mode + Bootsnap warm) | Pitfall 3 | LOW — ist heutige Erfahrung mit `bin/rails console`. Bei Cold-Start (CI ohne Bootsnap) potentiell 10+ s. Plan-Task: Boot-Latenz messen + dokumentieren |
| A5 | `releaseMeldeliste` ist parameter-vollständig dokumentiert in PATH_MAP-Comments | Curated Allowlist | MEDIUM — Comments stehen im Code (Zeilen 333–337) aber sind 6+ Jahre alt. CC-API kann inzwischen weitere Required-Params verlangen. Mitigation: Plan-Task = Manual-Probe gegen Staging-CC mit `armed: false` (dry-run) zur Validierung |
| A6 | SDK-Resources nehmen beliebige URI-Schemes (auch `cc://`) | Pattern 3 | LOW — direkt SDK-zitiert. Aber MCP-Client-Verhalten bei unbekanntem Scheme **könnte** "Resource nicht öffenbar"-UX zeigen. Mitigation: erste Phase-40-UAT inklusive Resource-Read-Probe von Claude Desktop |
| A7 | `lib/mcp_server/` wird von Rails 7.2 default `autoload_lib` korrekt geladen | Pattern 4 | LOW — Rails 7.2 Doku + bestehender Carambus-Code (`lib/markdown_converter.rb` etc.) zeigen Pattern. Mitigation: Plan-Task = Smoke-Test "boot Rails + reference McpServer::Server constant" |
| A8 | Mock-Mode-ENV-Flag `CARAMBUS_MCP_MOCK=1` ist im Carambus-Stack noch nicht belegt | Mock-Mode | LOW — `grep -r CARAMBUS_MCP` im Repo: Phase 40 introduces it. Risk = nahe Null |
| A9 | MCP-Resource-Listing ist statisch zur Server-Boot-Zeit | Pattern 3 | MEDIUM — SDK README zeigt `server.resources << MCP::Resource.new(...)` als Boot-time-Add. Falls Resources dynamisch nachgeladen werden müssen (z.B. wenn ein Doc-File geändert wird), benötigt es `notify_resources_list_changed`. Phase 40 = statisch reicht; Phase 40.1+ kann dynamic-reload addressieren |
| A10 | `[SME-CONFIRM]`-Marker bleiben in Resource-Content unverändert | Workflow Appendix Split | LOW — Spec-Decision (CONTEXT.md `<specifics>`). User akzeptiert dass Resources unverified Claims enthalten |

## Open Questions (RESOLVED 2026-05-07 in revision)

1. **SDK-Verhalten bei invalidem JSON von stdin** — **RESOLVED:**
   - **Decision:** SDK closes stdin and returns JSON-RPC `-32700 Parse error` per spec (per official MCP-Spec § Error Codes). The SDK does NOT crash the server loop — the `transport.open` blocking-read loop continues after returning the error envelope to STDOUT.
   - **Action:** Plan 06 adds a smoke test that pipes `{garbage` to `bin/mcp-server` and asserts the JSON-RPC error envelope (id: null, error.code: -32700) appears on STDOUT.
   - **Mitigation in code:** None needed — SDK handles natively. `lib/mcp_server/transport/boot.rb` adds a comment-line documenting this behavior.

2. **PHPSESSID-Reauth Race Condition** — **RESOLVED:**
   - **Decision:** Single-threaded stdio means no real race (only one tool call active at a time per JSON-RPC request/response cycle). The SDK's `MCP::Server::Transports::StdioTransport` blocks on each request.
   - **Documentation:** Plan 05 `CcSession#reauth_if_needed!` is therefore safe without `Mutex.synchronize`. Note in code: "no risk in stdio mode; revisit if HTTP/SSE transport added in future phase (e.g. Phase 41+ multi-client mode)".
   - **No code change needed beyond comment.**

3. **Mock-Mode-Reichweite (HTTP-only oder DB?)** — **RESOLVED:**
   - **Decision:** **HTTP-only.** DB lookups (`Region.find_by`, `RegionCc.find_by`, `LeagueCc.find_by`, `TournamentCc.find_by`) remain real even when `CARAMBUS_MCP_MOCK=1`.
   - **Already implemented:** Plan 01 `McpServer::Tools::MockClient` only stubs `client.get` / `client.post`; ActiveRecord goes through normally. Plan 04 read tools call `Region.find_by(...)` directly — no Mock-Mode branching for DB layer.
   - **Test validity benefit:** DB state realistic, only network layer stubbed (consistent with Carambus VCR + WebMock convention).

4. **`cc://api/*` Resource-Granularität** — **RESOLVED:**
   - **Decision:** **15 separate resources, one per curated allowlist action** (10 read lookups + 4 write/admin actions + 1 dashboard root `home`). NOT a single sammelnde `cc://api/path-map` resource. Auto-mapping all ~100 PATH_MAP entries remains forbidden per D-04.
   - **Already chosen in Plan 03** with `ApiSurface::ALLOWLIST` constant (15 entries). Drift-guard test verifies all entries exist in `RegionCc::ClubCloudClient::PATH_MAP`.
   - **Rationale:** Per-action resources allow Claude Desktop / Code clients to discover individual endpoints, navigate the API surface, and link from workflow scenarios to specific actions. A bulk resource would defeat MCP's resource-listing UX.

5. **`bin/mcp-server` Executable-Bit + Capistrano-Deploy** — **RESOLVED:**
   - **Decision:** Capistrano's standard `linked_files` workflow does NOT preserve git-stored executable bits across `release_path` symlinking on all servers. Add an explicit deploy hook to chmod the binary.
   - **Action — Plan 06 Task 4 (NEW):** Add a `lib/capistrano/tasks/mcp_server.rake` deploy task that runs `chmod 0755 #{release_path}/bin/mcp-server` after `:bundle:install` (or `deploy:updated` hook). Plus Plan 06's E2E test asserts `File.executable?(Rails.root.join("bin/mcp-server"))` on every test run (catches the local checkout case if devs `git clone` without preserving mode).
   - **Local development:** Unkritisch — git tracks file mode per `.gitattributes` if set, otherwise dev runs `chmod +x bin/mcp-server` manually (covered in dev-setup-doc). The MCP-client spawns the local file; if non-executable, the user sees a clear error from the OS.

## Security Domain

## Security Domain

> `security_enforcement` ist nicht explizit `false` in `.planning/config.json` → Sektion erforderlich.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | CC-Login via existing `RegionCc::ClubCloudClient`-Login-Flow; Credentials per-Client-Installation aus ENV (D-09). Keine eigene Auth-Implementation. |
| V3 Session Management | yes | PHPSESSID In-Memory mit ~30 min TTL (D-10). Keine Disk-Persistenz. Process-Lifetime = Session-Lifetime (Subprocess wird vom MCP-Client beendet). |
| V4 Access Control | yes | Allowlist-Pattern (D-03): nur curated Tools/Resources erreichbar. Keine generische "execute arbitrary CC action"-Tool. **Trust-CC-and-parse-error** (D-11) für Fine-Grained Permissions. |
| V5 Input Validation | yes | `json-schema` Gem (transitiver Dep) + manuelle `BaseTool#validate_input!`-Helper (siehe Pitfall 6). |
| V6 Cryptography | no | Keine eigene Crypto. CC-API ist HTTPS via Net::HTTP. PHPSESSID-Cookie wird vom HTTPS-Layer geschützt. |
| V7 Error Handling & Logging | yes | Errors via `MCP::Tool::Response.new([...], error: true)`; Server-Logs auf STDERR (NICHT STDOUT — siehe Pitfall 1); keine Stack-Traces in Tool-Responses (Information Disclosure). |
| V8 Data Protection | yes | Credentials NIE in Server-Logs. Pre-Phase-Closure Audit: `grep -ni 'password\|cc_password' lib/mcp_server/` muss Treffer nur in Documented-Skip-Locations zeigen. |
| V13 API & Web Service | yes | Stdio-Transport hat keine Network-Surface (D-14) → kein Rate-Limiting nötig auf MCP-Layer. CC-API-Side-Rate-Limits respektiert durch Lazy-Login + Session-Reuse (D-10). |

### Known Threat Patterns für `mcp` + Stdio + Rails-Embedded-Server

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Credential-Leak via stdout/Logs | Information Disclosure | Rails.logger → STDERR; Credentials NIE in Tool-Response-Bodies; pre-commit-Audit |
| Allowlist-Bypass durch generic CC-Action-Tool | Elevation of Privilege | Phase 40 ships KEIN `cc_execute_arbitrary_action`-Tool; auch keinen "passthrough"-Resource. PATH_MAP ist nur intern für die curated Tools verfügbar |
| Process-Hijack des `bin/mcp-server`-Binaries | Tampering | File ist im Repo, getrackt von Git. MCP-Client spawnt File aus Local-Path — Endbenutzer-Verantwortung dass kein Pfad-Tampering passiert |
| Mock-Mode-Leak in Production | Tampering | `McpServer::CcSession#client_for` weigert sich `CARAMBUS_MCP_MOCK=1` in `Rails.env.production?` zu akzeptieren (failsafe raise) |
| Confused-Deputy: User mit niedrigem CC-Recht ruft Write-Tool | Elevation of Privilege | D-11 trust-CC-and-parse-error; CC-Backend ist die Authority. Kein Pre-Cache von Permissions, das umgangen werden könnte |
| Tool-Schema-Injection (LLM passes malicious string als Param) | Tampering | All Params sind type-validated (string/integer/boolean); keine Eval/Exec; CC-Calls sind URL-encoded via Net::HTTP |
| Session-Fixation (PHPSESSID stehlen via Memory-Inspection) | Spoofing | Process-Lifetime = Session-Lifetime; kein Disk-Persist. Ein Memory-Dump erfordert lokalen Root-Access — out of MCP-Threat-Model |

## Sources

### Primary (HIGH confidence)

- **`mcp` Gem on rubygems.org** — version 0.15.0 (released 2026-05-04), required Ruby >= 2.7.0, runtime-dep `json-schema >= 4.1`, ~5.3M downloads. URL: https://rubygems.org/gems/mcp [VERIFIED 2026-05-07]
- **github.com/modelcontextprotocol/ruby-sdk** — Official Anthropic Ruby SDK README — `MCP::Server`, `MCP::Tool`, `MCP::Resource`, `StdioTransport`, error envelope `{ error: "Internal error occurred", isError: true }`, signal-handling NOT documented [VERIFIED 2026-05-07]
- **modelcontextprotocol.io/docs/develop/connect-local-servers** — Claude Desktop config path (`~/Library/Application Support/Claude/claude_desktop_config.json`), exact `mcpServers` JSON shape with `command`/`args`/`env`, troubleshooting [VERIFIED 2026-05-07]
- **code.claude.com/docs/en/mcp** — Claude Code MCP setup, `claude mcp add`, scope hierarchy (local/project/user), `${VAR}`-Expansion in `.mcp.json`, `MCP_TIMEOUT` env var [VERIFIED 2026-05-07]
- **app/services/region_cc/club_cloud_client.rb** — Carambus codebase, PATH_MAP at lines 20–422, `releaseMeldeliste` at line 332, `armed`/Dry-Run-Konvention, PHPSESSID-Cookie [VERIFIED: codebase read]
- **app/services/region_cc/registration_syncer.rb** — Reference pattern für `showMeldelistenList`/`showMeldeliste` Read-Composition [VERIFIED: codebase read]
- **config/application.rb:86** — Carambus Rails 7.2 `config.autoload_lib(ignore: %w[assets generators tasks templates])` already configured [VERIFIED: codebase read]
- **.planning/clubcloud-admin-appendix-DRAFT.md** — Source für 5–7 Workflow-Resources, `[SME-CONFIRM]`-Marker-Inventar [VERIFIED: codebase read]

### Secondary (MEDIUM confidence)

- **modelcontextprotocol.io/docs/sdk** — SDK-Tier-Listing zeigt Ruby-SDK als official-tier [VERIFIED 2026-05-07]
- **support.claude.com/en/articles/10949351-getting-started-with-local-mcp-servers** — Cross-verifies Claude Desktop config behavior [WebSearch corroboration]
- **github.com/justinwlin/claude-mcp-guide** — Community guide, useful für `claude mcp add --env`-CLI-Syntax [WebSearch corroboration]

### Tertiary (LOW confidence)

- **MCP_TIMEOUT default value** — Beschrieben als "configurable via env" aber exakter Default nicht final verifiziert. Mitigation: Doku weist auf explizit-setzen hin (siehe A3).
- **Claude Code project-vs-user scope precedence** — Dokumentiert aber nicht hands-on verifiziert für unsere Use-Case (private CC-Credentials → user-scope plausibler) [WebSearch corroboration only]

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — `mcp` Gem v0.15.0 verifiziert auf rubygems.org am 2026-05-07; minimal example aus offiziellem README zitiert.
- Architecture: **HIGH** für Rails-Embed-Pattern (Carambus hat Vorbild via `lib/scenario_generator.rb`); **MEDIUM** für Stdio-Signal-Handling (SDK-undokumentiert, eigenes Pattern).
- Pitfalls: **HIGH** für STDOUT-Pollution (SDK explizit dokumentiert); **MEDIUM** für Boot-Timeout (basiert auf Carambus-Erfahrung, nicht auf measured benchmark); **LOW** für Schema-Validation-Strenge (nur SDK-README inferred).
- Allowlist-Auswahl: **MEDIUM** — basiert auf Lesen aller 9 Syncer + Cross-Reference mit Workflow-Scenarios; aber finale Auswahl ist Plan-Author-Discretion.
- Workflow-Appendix-Split: **HIGH** — direkte Inspektion des DRAFT-Files, klare Empfehlung welche Scenarios reif sind.

**Research date:** 2026-05-07
**Valid until:** 2026-06-06 (30 Tage; `mcp` Gem ist noch in 0.x-Range, daher monatlicher Check empfohlen)

## RESEARCH COMPLETE

**Phase:** 40 - MCP Server für ClubCloud-Schnittstelle
**Confidence:** HIGH (overall — verifizierte SDK-Existenz, Version, API-Shape, Carambus-Reuse-Targets)

### Key Findings

1. **Offizielle `mcp` Gem v0.15.0 (2026-05-04)** ist verfügbar, Ruby >= 2.7 — passt zu Carambus' Ruby 3.2.1. API-Shape (`MCP::Server`, `MCP::Tool`, `MCP::Resource`, `StdioTransport`) ist klar dokumentiert; minimal-example direkt verwendbar.
2. **`RegionCc::ClubCloudClient` ist 100 % wiederverwendbar** — HTTP, PHPSESSID-Cookie, Multipart, Dry-Run-Konvention `armed: true` bereits vorhanden. Phase 40's Eigenanteil = Glue-Code, kein Re-implement.
3. **D-19 Proof-Tool **`cc_finalize_teilnehmerliste`** verifiziert** — PATH_MAP enthält `releaseMeldeliste` (Zeile 332) als finalization-style mutation mit klar dokumentierten Parametern. Recommendation der CONTEXT.md ist korrekt.
4. **Rails 7.2 `config.autoload_lib`** ist in Carambus bereits aktiv (`config/application.rb:86`); `lib/mcp_server/` lädt automatisch via Zeitwerk — keine Konfig-Änderung nötig, ABER strict camelCase-Konvention (`McpServer`, NICHT `MCPServer`).
5. **Custom URI-Scheme `cc://...`** wird vom SDK ohne Special-Handling akzeptiert — opaque identifiers. Resources-list und resources/read-Handler funktionieren mit beliebigen Schemes.
6. **8 Pitfalls identifiziert**, davon 3 mit potentiell schweren Failure-Modes (STDOUT-Pollution, Zeitwerk-Constants, Boot-Latenz vs. MCP-Timeout) — alle mitigiert mit konkreten Patterns.
7. **5 Phase-40-Workflow-Resources empfohlen** (Top-3 Scenarios + Rollen-Meta + Glossar-Meta) aus dem 7-Kandidaten-Pool des Appendix-DRAFT, basierend auf `[SME-CONFIRM]`-Marker-Dichte.
8. **~13 curated PATH_MAP-Allowlist-Tools empfohlen** (10 Read + 3 Write) — Phase 40 ships 1 Read-Subset + 1 Write-Tool (D-19), Rest in Phase 40.1.
9. **Validation-Architecture-Sektion bewusst weggelassen** — `.planning/config.json` hat `nyquist_validation: false` explizit gesetzt → Sektion nicht erforderlich. Standard Minitest unter `test/mcp_server/` mit Smoke + 1 E2E ist ausreichend (D-16).

### File Created

`/Users/gullrich/DEV/carambus/carambus_api/.planning/phases/40-mcp-server-clubcloud/40-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | Gem-Version + Ruby-Compat verifiziert auf rubygems.org am 2026-05-07 |
| Architecture (Rails-Embed) | HIGH | Pattern existiert in Carambus (lib/scenario_generator.rb, lib/markdown_converter.rb) |
| Architecture (Stdio-Signal-Handling) | MEDIUM | SDK-undokumentiert; eigenes Signal.trap-Pattern empfohlen |
| Pitfalls (STDOUT, Zeitwerk) | HIGH | Direkt SDK-zitiert bzw. Rails-Standard |
| Pitfalls (Boot-Latenz) | MEDIUM | Annahme 3–5s basiert auf Erfahrung, nicht auf Benchmark |
| Schema-Validation-Strenge | LOW-MEDIUM | SDK-README inferred — Plan-Task soll explizit verifizieren |
| Allowlist-Auswahl (~13 Tools) | MEDIUM | Begründet aus 9 Syncern, aber Plan-Author kann verfeinern |
| Workflow-Appendix-Split (5 Resources) | HIGH | Direkte File-Inspektion; klare `[SME-CONFIRM]`-Marker-Dichte |
| Mock-Mode-Strategie (Hybrid) | HIGH | Carambus-Bestandsmuster (VCR + WebMock) bereits etabliert |

### Open Questions (RESOLVED 2026-05-07 in revision)

1. SDK-Verhalten bei invalidem JSON von stdin — **RESOLVED:** SDK gibt `-32700 Parse error` per Spec; Server-Loop crashed nicht. Plan 06 testet via Pipe-Frame.
2. PHPSESSID-Reauth-Race-Condition — **RESOLVED:** Single-threaded stdio; kein Risiko in Phase 40. Code-Kommentar dokumentiert revisit-Trigger für HTTP/SSE-Transport.
3. Mock-Mode-Reichweite — **RESOLVED:** HTTP-only; DB-Lookups bleiben echt. Bereits in Plan 01 MockClient so implementiert.
4. `cc://api/*`-Resource-Granularität — **RESOLVED:** 15 separate Resources (10 read + 4 write + `home`); per Plan 03 ALLOWLIST gelockt.
5. Capistrano-Deploy + `bin/mcp-server`-Executable-Bit — **RESOLVED:** Plan 06 Task 4 ergänzt Capistrano-Deploy-Hook + E2E-Test prüft `File.executable?`.

### SDK API Findings (added in revision 2026-05-07)

To eliminate the conditional hedges in Plans 04 + 05 ("verify SDK supports `tool_name`" / "verify `MCP::Tool::Response` shape"), Plan 01 Task 3 now performs an explicit SDK-API smoke probe:

1. After `bundle install`, `bundle exec ruby -e "require 'mcp'; puts MCP::Tool.public_methods.sort.grep(/name|description|input/)"` confirms class-macros (`tool_name`, `description`, `input_schema`, `annotations`) exist as DSL.
2. `bundle exec ruby -e "require 'mcp'; r = MCP::Tool::Response.new(content: [{type: 'text', text: 'x'}]); puts r.public_methods.sort"` confirms response shape (`#error`, `#content` accessors).
3. Findings recorded in Plan 01 SUMMARY for Plans 04/05 reference. Conditional language ("verify against SDK actual behavior") is removed from Plans 04 + 05 text — they reference the resolved findings.

**Lockdown:** All Plans use `tool_name "cc_..."` DSL declaration and `response.error` / `response.content.first[:text]` access patterns. If the SDK API differs in practice, Plan 01 Task 3 fails fast at install time, NOT downstream during Plan 04/05 execution.

### Ready for Planning

Research vollständig. Planner kann jetzt PLAN.md-Files für Phase 40 erstellen — geschätzte Plan-Aufteilung:

- **Plan 40-01:** Foundation — Gemfile, `bin/mcp-server`, `lib/mcp_server/server.rb`, `lib/mcp_server/transport/boot.rb`, Setup-Doku für Endbenutzer (claude_desktop_config.json + .mcp.json examples).
- **Plan 40-02:** Workflow-Doc-Resources — 5 Resources unter `cc://workflow/...` (3 Scenarios + 2 Meta), Source-Splitting von `clubcloud-admin-appendix-DRAFT.md` nach `docs/managers/clubcloud-scenarios/*.de.md`.
- **Plan 40-03:** API-Surface-Resources — `cc://api/*` für ~13 curated PATH_MAP-Actions (oder gesammelte Resource — Plan-Author entscheidet).
- **Plan 40-04:** Read-Lookup-Tools — 10 Tools (`cc_lookup_region`, `_league`, `_tournament`, `_teilnehmerliste`, `_team`, `_club`, `_spielbericht`, `_category`, `_serie`, `cc_search_player`).
- **Plan 40-05:** Write-Architecture + Proof-Tool — `lib/mcp_server/cc_session.rb` (Lazy-Login + Session-Reuse + Reauth), `cc_finalize_teilnehmerliste` Tool, Mock-Mode (`McpServer::MockClient`).
- **Plan 40-06:** Tests — Smoke-Tests pro Tool/Resource + 1 E2E-Stdio-Spawn-Test (`test/mcp_server/integration/stdio_e2e_test.rb`); manuelle UAT-Drehbuch (Claude Desktop und Claude Code) als markdown im Phase-Dir.
