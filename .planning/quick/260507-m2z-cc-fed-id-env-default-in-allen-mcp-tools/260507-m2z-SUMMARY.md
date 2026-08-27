---
phase: quick-260507-m2z
plan: 01
subsystem: mcp-server
tags: [mcp, clubcloud, env-default, fed_id, dry]
key-files:
  created:
    - test/mcp_server/tools/cc_fed_id_env_default_test.rb
  modified:
    - lib/mcp_server/tools/base_tool.rb
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
    - lib/mcp_server/tools/finalize_teilnehmerliste.rb
    - test/mcp_server/tools/lookup_region_test.rb
    - docs/developers/clubcloud-mcp-server.de.md
    - public/docs/developers/clubcloud-mcp-server/index.html
    - public/docs/en/developers/clubcloud-mcp-server/index.html
    - public/docs/search/search_index.json
decisions:
  - "BaseTool.default_fed_id als einzige ENV-Lookup-Stelle (DRY); kein per-Tool-Override"
  - "fed_id ||= default_fed_id vor jeder Validierung — nicht nach (sonst feuert validate_required! zu früh)"
  - "description:-String-Update statt default:-Feld im input_schema (MCP-SDK validiert default: nicht zuverlässig)"
metrics:
  duration: ~8min
  completed: 2026-05-07
  tasks: 2
  files: 18
---

# Phase quick-260507-m2z Plan 01: CC_FED_ID ENV-Default in allen 11 MCP-Tools

**One-liner:** `BaseTool.default_fed_id` als DRY-ENV-Lookup schließt die Lücke zwischen `.mcp.json --env CC_FED_ID=20` und dem Tool-Runtime — 11 Tools wenden `fed_id ||= default_fed_id` an, 6 Regression-Tests grün.

## Commits

| Hash | Nachricht |
|------|-----------|
| `be23e0ee` | feat(mcp-server): read CC_FED_ID env default in all 11 fed_id-aware tools |
| `26fd8317` | docs(mcp-server): BaseTool.default_fed_id in Section 6 + CC_FED_ID-Closure in Section 11 |

## Tasks

| # | Name | Status | Commit |
|---|------|--------|--------|
| 1 | BaseTool.default_fed_id + 11 Tools + Tests | DONE | be23e0ee |
| 2 | Doku-Update + mkdocs build | DONE | 26fd8317 |

## Test-Pfade

| Test | Status |
|------|--------|
| `test/mcp_server/tools/cc_fed_id_env_default_test.rb` (6 Tests) | GREEN |
| `test/mcp_server/tools/lookup_region_test.rb` (4 Tests) | GREEN |
| `test/mcp_server/tools/finalize_teilnehmerliste_test.rb` (6 Tests) | GREEN |
| Gesamt `test/mcp_server/tools/` (33 Tests) | GREEN — 0 failures, 0 errors |

## Verifikation

```
# 11 Tools mit fed_id ||= default_fed_id (ohne Kommentar in base_tool):
grep -l "fed_id ||= default_fed_id" lib/mcp_server/tools/*.rb | grep -v base_tool | wc -l
# → 11

# Nur base_tool.rb definiert default_fed_id:
grep -l "def self.default_fed_id" lib/mcp_server/tools/*.rb
# → lib/mcp_server/tools/base_tool.rb

# 11 Schema-descriptions mit Defaults-to-ENV-Hinweis:
grep -c "Defaults to ENV\['CC_FED_ID'\]" lib/mcp_server/tools/*.rb | grep -v ":0$" | wc -l
# → 11

# Kein new default: ENV[] im input_schema:
grep -n "default:.*ENV\[" lib/mcp_server/tools/*.rb
# → (keine Treffer)

# Smoke-Test:
CC_FED_ID=42 bin/rails runner 'puts McpServer::Tools::BaseTool.default_fed_id.inspect'
# → 42
bin/rails runner 'puts McpServer::Tools::BaseTool.default_fed_id.inspect'
# → nil
```

## Vorher / Nachher (Stichprobe cc_lookup_region)

**Vorher:** `claude --mcp-tool cc_lookup_region --shortname BCW --force_refresh true` → Missing-fed_id-Fehler, auch wenn `CC_FED_ID=20` in `.mcp.json` konfiguriert war.

**Nachher:** Gleicher Aufruf ohne `fed_id`-Argument — Tool liest `default_fed_id` aus ENV, Live-Pfad wird erreicht, MockClient antwortet mit `CC live response for home (fed_id=20, status 200)`.

## Deviations from Plan

None — Plan executed exactly as written.

## Known Stubs

None — keine Stub-Patterns in den geänderten Dateien.

## Threat Flags

Keine neuen Netzwerk-Endpunkte oder Auth-Pfade eingeführt. `default_fed_id` liest nur ENV, keine User-Inputs.

## Verbleibende Issues / Follow-ups

WR-04 und WR-05 aus Doku Section 11 sind weiterhin offen (nicht im Scope dieses Quick-Tasks):

- **WR-04** — live-only `lookup_*`-Tools rufen `cc_session.reauth_if_needed!` nicht auf → Phase 40.1
- **WR-05** — Validierung vor `force_refresh`-Honorierung in `lookup_league` + `lookup_tournament` → Phase 40.1

## Self-Check: PASSED

- base_tool.rb: FOUND
- cc_fed_id_env_default_test.rb: FOUND
- docs/developers/clubcloud-mcp-server.de.md: FOUND
- Commit be23e0ee: FOUND
- Commit 26fd8317: FOUND
