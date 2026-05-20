---
phase: 40-mcp-server-clubcloud
plan: "03"
subsystem: infra
tags: [mcp, ruby-sdk, resources, allowlist, clubcloud, path-map, d-04]

requires:
  - phase: 40-01-foundation
    provides: McpServer::Server.build mit zentralem resources_read_handler-Dispatcher; MCP::Resource-Klasse verfügbar

provides:
  - McpServer::Resources::ApiSurface.all → 15 MCP::Resource-Instanzen für cc://api/{action} (D-04 Allowlist)
  - McpServer::Resources::ApiSurface.read(action:) → Markdown mit Pfad, HTTP-Methode, read_only, Syncer-, Tool-Querverweise
  - 7 Minitest-Tests grün (Drift-Guard, gesperrte Anzahl 15, Server-Integration)
  - D-04 Allowlist-Enforcement: kein Auto-Mapping aller ~100 PATH_MAP-Keys

affects:
  - 40-01-foundation (server.rb collect_resources nutzt ApiSurface via defined?-Guard — bereits implementiert)
  - 40-04-read-tools (WRAPPED_BY_TOOL-Mapping gibt Entwicklern Überblick über Tool-Abdeckung)
  - 40-05-write-tool (cc_finalize_teilnehmerliste explizit referenziert als WRAPPED_BY_TOOL["releaseMeldeliste"])

tech-stack:
  added: []
  patterns:
    - "ALLOWLIST-Array als gesperrte Whitelist (T-40-03-02/03 Mitigation — verhindert PATH_MAP-Bypass und Auto-Mapping)"
    - "Plan 01 zentraler resources_read_handler-Dispatcher bleibt unangetastet — Plan 03 exponiert nur .all + .read"
    - "USED_BY_SYNCER + WRAPPED_BY_TOOL-Hashes für Markdown-Cross-Referenzen (D-04 Mapping D-20 Tool-Namen)"

key-files:
  created:
    - lib/mcp_server/resources/api_surface.rb
    - test/mcp_server/resources/api_surface_test.rb
  modified: []

key-decisions:
  - "Plan 03 registriert KEINEN eigenen resources_read_handler — Plan 01's zentraler Dispatcher in server.rb übernimmt gesamtes Routing (Wave-2-Konfliktfreiheit gesichert)"
  - "Gesperrte Anzahl: exakt 15 Entries (10 Read-Lookups + 4 Write/Admin + 1 home) — Warning-5-Fix (war inkonsistent 13 vs 15 in früheren Plan-Entwürfen)"
  - "Drift-Guard-Test prüft explizit alle ALLOWLIST-Keys gegen PATH_MAP — fängt zukünftige PATH_MAP-Umbenennungen ab"
  - "server.rb nicht modifiziert — git diff --stat lib/mcp_server/server.rb zeigt 0 Änderungen"

patterns-established:
  - "Pattern: Resource-Klasse exponiert .all (Array<MCP::Resource>) + .read (String) — identisch mit Plan-02-Sibling-Pattern"
  - "Pattern: ALLOWLIST-Whitelist als erste Verteidigung gegen D-04-Verletzung — unbekannte Actions → nicht-in-Allowlist-String (keine Exception)"

requirements-completed: [D-01, D-04, D-06, D-17]

duration: 2min
completed: "2026-05-07"
---

# Phase 40 Plan 03: API-Surface-Resources Summary

**McpServer::Resources::ApiSurface mit exakt 15 kuratierten PATH_MAP-Entries als MCP-Resources exponiert — D-04 Allowlist gesperrt, 7 grüne Tests, Plan 01 zentraler Dispatcher unangetastet**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-05-07T04:35:34Z
- **Completed:** 2026-05-07T04:37:34Z
- **Tasks:** 2
- **Files erstellt:** 2

## Accomplishments

- `McpServer::Resources::ApiSurface.all` gibt exakt 15 `MCP::Resource`-Instanzen bei `cc://api/{action}` zurück (D-04 Allowlist: 10 Read-Lookups + 4 Write/Admin + 1 Dashboard-Root `home`)
- `.read(action:)` gibt Markdown-Content mit Pfad, HTTP-Methode (GET/POST), read_only-Flag, Syncer-Querverweise und MCP-Tool-Querverweise zurück — nie eine Exception
- Drift-Guard-Test (`Test 3`) prüft alle 15 ALLOWLIST-Keys gegen `RegionCc::ClubCloudClient::PATH_MAP` — fängt zukünftige PATH_MAP-Umbenennungen sofort ab
- `McpServer::Server.build.resources` enthält total 20 Resources (5 Workflow + 15 API) — Plan 01's Dispatcher routet `cc://api/*` korrekt zu `ApiSurface.read(action:)`

## Task Commits

Jeder Task wurde atomar committed:

1. **Task 1: ApiSurface-Registry mit 15-Entry-Allowlist** — `3fe31c3c` (feat)
2. **Task 2: 7 ApiSurface-Tests mit Drift-Guard und Server-Integration** — `6a238568` (test)

## Files Created/Modified

- `lib/mcp_server/resources/api_surface.rb` — ApiSurface-Klasse mit ALLOWLIST (15 Entries), USED_BY_SYNCER, WRAPPED_BY_TOOL, .all, .read(action:), not_in_allowlist, missing
- `test/mcp_server/resources/api_surface_test.rb` — 7 Tests: gesperrte Anzahl, URI-Shape, Drift-Guard, Content-Mapping, Not-Found, Server-Integration

## Audit: Plan 03 ruft resources_read_handler NICHT auf (Blockers 2+3)

```
grep -c "install_read_handler\|resources_read_handler" \
  lib/mcp_server/resources/api_surface.rb
→ 0  (verifiziert)

git diff --stat lib/mcp_server/server.rb
→ (keine Ausgabe — 0 Änderungen, verifiziert)
```

Plan 03 hat `server.rb` **nicht modifiziert** — Wave-2-Konfliktfreiheit gesichert.

## PATH_MAP-Drift-Befund

Alle 15 ALLOWLIST-Entries wurden vor der Implementierung gegen `RegionCc::ClubCloudClient::PATH_MAP` verifiziert:

```ruby
%w[home showLeagueList showLeague showMeisterschaftenList showMeisterschaft
   showMeldelistenList showMeldeliste showTeam showClubList showAnnounceList
   spielbericht showCategory showSerie suche releaseMeldeliste]
# Alle 15 in PATH_MAP gefunden — kein Drift seit RESEARCH-Phase
```

Kein Anpassungsbedarf — die ALLOWLIST aus RESEARCH §"Curated PATH_MAP Allowlist" ist vollständig korrekt.

## Decisions Made

- **Wave-2-Konfliktfreiheit:** Plan 03 registriert keinen eigenen `resources_read_handler`. Plan 01's `install_central_read_handler` in `server.rb` routet `cc://api/*`-URIs an `ApiSurface.read(action:)`. Die `defined?(McpServer::Resources::ApiSurface)`-Guard in `collect_resources` war bereits in Plan 01 vorbereitet.
- **Gesperrte Anzahl 15 (Warning-5-Fix):** Frühere Plan-Entwürfe waren inkonsistent (must_haves sagten 13, Code hatte 15, Test behauptete 15). Alle Referenzen — Code-Kommentare, ALLOWLIST-Größe, Tests — sagen jetzt konsistent "15 Entries".
- **Kein HTTP-Methoden-Lookup:** `read_only == true` → GET, `read_only == false` → POST (aus PATH_MAP-Konvention abgeleitet, keine separate Mapping-Tabelle nötig).

## Deviations from Plan

Keine. Plan wurde exakt wie geschrieben ausgeführt.

## Issues Encountered

Keine. Alle Akzeptanzkriterien auf Anhieb erfüllt.

## User Setup Required

Keine. Plan 03 enthält keine externe Service-Konfiguration.

## Next Phase Readiness

- **Plan 04 (read-tools):** WRAPPED_BY_TOOL-Mapping dokumentiert alle Read-Tool-Namen; `ApiSurface.read` gibt Entwicklern sofort einen Überblick über die CC-API-Surface.
- **Plan 05 (write-tool):** `cc_finalize_teilnehmerliste` ist explizit als WRAPPED_BY_TOOL["releaseMeldeliste"] referenziert — Naming-Konsistenz bestätigt.
- **Kein Blocker** für weitere Phase-40-Ausführung.

## Known Stubs

Keine. Alle `.read`-Methoden geben echten Markdown-Content zurück. Not-Found-Bodies sind definiertes Fehlerverhalten (T-40-03-02 Mitigation), keine Platzhalter.

## Threat Flags

Keine neuen Bedrohungsflächen eingeführt. PATH_MAP enthält nur URL-Pfade, keine Credentials (T-40-03-01 Accept). ALLOWLIST-Whitelist mitigiert T-40-03-02 und T-40-03-03 wie geplant.

## Self-Check: PASSED

- FOUND: `lib/mcp_server/resources/api_surface.rb`
- FOUND: `test/mcp_server/resources/api_surface_test.rb`
- Commit `3fe31c3c` (Task 1) — verifiziert
- Commit `6a238568` (Task 2) — verifiziert
- 7 Tests grün (43 Assertions, 0 Failures, 0 Errors, 0 Skips)
- server.rb unverändert (0 git-diff-Zeilen)
- Total server.resources: 20 (5 Workflow + 15 API)

---
*Phase: 40-mcp-server-clubcloud*
*Completed: 2026-05-07*
