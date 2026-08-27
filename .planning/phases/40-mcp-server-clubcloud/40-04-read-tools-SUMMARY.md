---
phase: 40-mcp-server-clubcloud
plan: "04"
subsystem: mcp
tags: [mcp, read-tools, db-first, live-only, clubcloud, d-18, d-20]

requires:
  - 40-01 (BaseTool, CcSession, MockClient, Server.build Auto-Registry)

provides:
  - 10 MCP Read-Tools (cc_lookup_* / cc_search_*) auto-registriert via Plan 01 collect_tools
  - D-18 Acceptance-Story Read-Pathway: cc_lookup_teilnehmerliste (DB-first + live-fallback)
  - Kanonisches Tool-Template in lookup_region.rb (für künftige Tool-Entwicklung)
  - 3 repräsentative Test-Dateien (DB-first, Acceptance-Story, live-only)

affects:
  - 40-05-write-tool (nutzt dieselbe CcSession / BaseTool Infrastruktur)
  - 40-06-smoke-tests (Plan 06 liefert exhaustive Smoke-Tests für die 7 noch ungetesteten Tools)

tech-stack:
  added: []
  patterns:
    - "DB-first pattern: Region/RegionCc, LeagueCc, TournamentCc ActiveRecord-Queries vor live CC-Call"
    - "Live-only pattern: cc_session.client_for + cc_session.cookie direkt, kein DB-Lookup"
    - "validate_required_anyof!: Mindestens ein von N optionalen Pflichtparametern vorhanden"
    - "Whitelist-JSON in format_* Methoden: nur whitelisted Felder (T-40-04-01)"
    - "response.error? (Predicate) per Plan 01 SDK-API-Abweichung — NICHT response.error"

key-files:
  created:
    - lib/mcp_server/tools/lookup_region.rb
    - lib/mcp_server/tools/lookup_league.rb
    - lib/mcp_server/tools/lookup_tournament.rb
    - lib/mcp_server/tools/lookup_teilnehmerliste.rb
    - lib/mcp_server/tools/lookup_team.rb
    - lib/mcp_server/tools/lookup_club.rb
    - lib/mcp_server/tools/lookup_spielbericht.rb
    - lib/mcp_server/tools/lookup_category.rb
    - lib/mcp_server/tools/lookup_serie.rb
    - lib/mcp_server/tools/search_player.rb
    - test/mcp_server/tools/lookup_region_test.rb
    - test/mcp_server/tools/lookup_teilnehmerliste_test.rb
    - test/mcp_server/tools/search_player_test.rb
  modified: []

decisions:
  - "4 DB-first Tools (lookup_region, lookup_league, lookup_tournament, lookup_teilnehmerliste) — exakte Carambus-Mirror-Modelle vorhanden"
  - "6 live-only Tools (lookup_team, lookup_club, lookup_spielbericht, lookup_category, lookup_serie, search_player) — kein Carambus-Mirror existiert"
  - "response.error? (Predicate) in Tests verwendet — SDK 0.15 hat KEINEN #error-Accessor (Plan 01 SDK-Abweichung)"
  - "RegistrationListCc via defined?-Guard in lookup_teilnehmerliste defensiv abgesichert"
  - "search_player gibt query-Parameter im Response-Text zurück (kein Datenleck — nur CC-Response-Metadaten)"

requirements-completed: [D-01, D-02, D-04, D-17, D-18, D-20]

duration: "~3 Minuten"
completed: "2026-05-07"
---

# Phase 40 Plan 04: Read-Tools Summary

**10 MCP Read-Tools (cc_lookup_* / cc_search_*) implementiert — DB-first/live-only Split 4/6 per D-02/Warning-6-Fix; D-18 Acceptance-Story via cc_lookup_teilnehmerliste abgedeckt; alle 10 Tests grün**

## Performance

- **Duration:** ~3 Minuten
- **Started:** 2026-05-07T04:40:17Z
- **Completed:** 2026-05-07T04:44:02Z
- **Tasks:** 3 (1a, 1b, 2)
- **Files erstellt:** 13

## Accomplishments

- 10 MCP-Tools implementiert, alle `< McpServer::Tools::BaseTool`, alle EN-benannt per D-20
- DB-first/live-only Split korrekt: **4 DB-first** (region, league, tournament, teilnehmerliste) + **6 live-only** (team, club, spielbericht, category, serie, search_player) — Warning-6-Fix vollständig
- `cc_lookup_region` als kanonisches Template in Task 1a: `validate_required_anyof!`, `format_region`, `live_lookup` — exakte Shape für 9 weitere Tools
- `cc_lookup_teilnehmerliste` deckt D-18 Acceptance-Story ab: Tournament-DB-Lookup → TournamentCc-Mirror → structured JSON (inkl. "no_cc_mirror"-Fallback wenn TournamentCc fehlt)
- `cc_search_player` nutzt `suche` PATH_MAP-Action; min.-2-Zeichen-Validierung; kein DB-Zugriff
- Alle `format_*`-Methoden geben Whitelist-JSON zurück (T-40-04-01: keine ungefilterten AR-Dumps)
- 3 Test-Dateien mit 10 Tests, 25 Assertions, 0 Failures, 0 Errors, 0 Skips

## Task Commits

| Task | Name | Commit | Dateien |
|------|------|--------|---------|
| 1a | Kanonisches cc_lookup_region Tool | `1fcb8e55` | lookup_region.rb |
| 1b | 9 Read-Tools (mechanische Replikation) | `3579334e` | 9 tool files |
| 2 | 3 repräsentative Tests | `9ed2ea27` | 3 test files |

## Tool-Tabelle

| Tool-Name | DB-first? | Mirror-Modell | CC-Action |
|-----------|-----------|---------------|-----------|
| cc_lookup_region | Ja | Region + RegionCc | home (force_refresh) |
| cc_lookup_league | Ja | LeagueCc | showLeague (force_refresh) |
| cc_lookup_tournament | Ja | TournamentCc | showMeisterschaft (force_refresh) |
| cc_lookup_teilnehmerliste | Ja | TournamentCc + RegistrationListCc | showMeldelistenList (force_refresh) |
| cc_lookup_team | Nein (live-only) | — | showTeam |
| cc_lookup_club | Nein (live-only) | — | showClubList |
| cc_lookup_spielbericht | Nein (live-only) | — | spielbericht |
| cc_lookup_category | Nein (live-only) | — | showCategory / showCategoryList |
| cc_lookup_serie | Nein (live-only) | — | showSerie / showSerienList |
| cc_search_player | Nein (live-only) | — | suche |

## SDK-API Contracts (Plan 01 verifiziert, halten durch)

| API | Status in Plan 04 |
|-----|-------------------|
| `tool_name` DSL | Korrekt in allen 10 Tools |
| `description` DSL | Korrekt, EN per D-20 |
| `input_schema` DSL | Korrekt, properties ohne strict `required:` (Pitfall 6) |
| `annotations` DSL | `read_only_hint: true, destructive_hint: false` in allen 10 |
| `response.error?` (Predicate) | Tests nutzen `response.error?` — NICHT `response.error` |
| `BaseTool.error / .text` | Korrekte Response-Konstruktoren in allen Tools |

## Deviations from Plan

Keine — Plan exakt wie beschrieben ausgeführt.

Einzige Anpassung (kein Deviation, da Plan 01 SUMMARY dies vorschreibt): Tests nutzen `response.error?` (Predicate) statt `response.error` — SDK 0.15 Abweichung, bereits in Plan 01 Task 3 dokumentiert und als fixe Referenz gesperrt.

## Known Stubs

Keine produktionsrelevanten Stubs. Die live-only Tools geben momentan nur HTTP-Status-Metadaten zurück (kein HTML-Parsing). Das ist intentional — Plan 06 (Smoke-Tests + ggf. Plan 40.1) kann HTML-Parsing ergänzen. Die Test-Fixtures springen über die Teilnehmerliste-Assertion wenn keine TournamentCc vorhanden ist (korrekt per skip-Semantik).

## Für Plan 06 (Exhaustive Smoke-Tests)

Die folgenden 7 Tools haben noch keine dedizierten Smoke-Tests (nur durch Plan 01 Server-Smoke abgedeckt):
1. `cc_lookup_league`
2. `cc_lookup_tournament`
3. `cc_lookup_team`
4. `cc_lookup_club`
5. `cc_lookup_spielbericht`
6. `cc_lookup_category`
7. `cc_lookup_serie`

## Self-Check: PASSED
