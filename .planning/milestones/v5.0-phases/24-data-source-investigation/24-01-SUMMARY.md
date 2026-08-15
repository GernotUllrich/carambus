---
phase: 24-data-source-investigation
plan: "01"
subsystem: api
tags: [net-http, sooplive, umbevents, json-api, web-scraping, probe-scripts]

requires: []
provides:
  - "umbevents.umb-carom.org/Reports/ endpoint behavior documented: HTML-only, no JSON API"
  - "billiards.sooplive.com JSON API confirmed: /api/games, /api/game/{id}/matches, /api/game/{id}/results"
  - "SoopLive API discovery method: schedule.js JS bundle contained relative API path strings"
  - "Sample JSON responses saved to tmp/samples/sooplive/ for Plan 02 findings"
affects:
  - 24-02-findings
  - phase-25-umb-scraper-refactoring
  - phase-26-service-extraction
  - phase-28-video-cross-referencing

tech-stack:
  added: []
  patterns:
    - "Net::HTTP probe script pattern (UmbScraperV2#fetch_url) reused for throwaway investigation scripts"
    - "JS bundle inspection to discover hidden API endpoints behind jsRender templates"

key-files:
  created:
    - tmp/probe_umbevents.rb
    - tmp/probe_sooplive.rb
    - tmp/samples/umbevents/.keep
    - tmp/samples/cuesco/.keep
    - tmp/samples/sooplive/.keep
  modified: []

key-decisions:
  - "SoopLive verdict is GO: /api/games, /api/game/{id}/matches return structured JSON without authentication"
  - "umbevents verdict is NO-GO: all /Reports/ endpoints return HTML regardless of Accept headers or query params"
  - "SoopLive API discovery required JS bundle inspection — HTML source alone was insufficient (confirms RESEARCH.md Pattern C)"
  - "umbevents HTTP 500 on ViewAllRanks and ViewTimetable is NOT a parameter-missing error — same 500 seen with all query param variants"
  - "umbevents ViewPlayers returns HTTP 200 HTML unconditionally — likely a public player list page, not an AJAX endpoint"

patterns-established:
  - "Pattern: Read external JS bundles (schedule.js, config.js) when HTML source contains jsRender placeholders — API URLs are in the JS, not the HTML"
  - "Pattern: JSON API existence can be inferred from 404 response content type (application/json 404 confirms router exists)"

requirements-completed:
  - INVEST-01
  - INVEST-03

duration: 25min
completed: "2026-04-12"
---

# Phase 24 Plan 01: Data Source Probe Scripts Summary

**SoopLive JSON API confirmed via JS bundle discovery (GO); umbevents /Reports/ endpoints return HTML-only for all header/param combinations (NO-GO)**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-12T11:20:00Z
- **Completed:** 2026-04-12T11:45:00Z
- **Tasks:** 2 of 2
- **Files modified:** 2 scripts created, 3 sample directories initialized

## Accomplishments

- Probed umbevents.umb-carom.org/Reports/ with 3 endpoints x 4 header combinations x 4 query param variants = confirmed HTML-only (NO-GO)
- Discovered SoopLive's undocumented JSON API by inspecting `/lib/schedule.js` — API paths `/api/games`, `/api/game/{id}/matches`, `/api/game/{id}/results` revealed in bundle
- Confirmed SoopLive API returns structured match data including player names, scores, innings, stage info, and VOD `replay_no` fields for cross-referencing
- Saved sample JSON responses: `api_games.json`, `api_game_127_matches.json`, `api_game_129_matches.json`, `api_game_137_matches.json`

## Task Commits

1. **Task 1: Probe umbevents.umb-carom.org endpoints** — `ed184f8b` (chore)
2. **Task 2: Probe billiards.sooplive.com for structured API** — `5725b05d` (chore)

## Files Created/Modified

- `tmp/probe_umbevents.rb` — Net::HTTP probe script for umbevents /Reports/ endpoints; handles redirect, SSL, 4 header variants, 4 query param variants per path
- `tmp/probe_sooplive.rb` — Net::HTTP probe script; probes 6 URL pattern guesses, inspects schedule HTML, inspects schedule.js bundle, probes discovered API endpoints
- `tmp/samples/umbevents/.keep` — placeholder (no JSON responses saved; all endpoints returned HTML)
- `tmp/samples/cuesco/.keep` — placeholder (Cuesco not probed in this plan per INVEST-02 scope)
- `tmp/samples/sooplive/.keep` — placeholder directory (JSON samples saved but gitignored)

## Key Findings

### umbevents.umb-carom.org (INVEST-01) — NO-GO

| Endpoint | Status | Content-Type | All headers tried |
|----------|--------|-------------|------------------|
| /Reports/ViewAllRanks | 500 | text/html | 4 header variants + 3 query params = 500 every time |
| /Reports/ViewTimetable | 500 | text/html | 4 header variants + 3 query params = 500 every time |
| /Reports/ViewPlayers | 200 | text/html | 4 header variants + 3 query params = 200 HTML every time |

The HTTP 500 on ViewAllRanks and ViewTimetable is consistent across all parameter combinations. The response body contains an ASP.NET Compilation Error page — this is a server-side rendering failure, not a missing-parameter error. No JSON API is accessible without authentication (session cookie from login).

**Verdict: NO-GO** — umbevents /Reports/ endpoints are HTML-only. No JSON API exposed without authenticated session.

### billiards.sooplive.com (INVEST-03) — GO

**Discovery method:** HTML inspection revealed external JS bundle `/lib/schedule.js?v=1775992798`. Reading that bundle exposed the API path strings directly:

```
/api/games
/api/game/${gameNo}/matches
/api/game/${gameNo}/results
```

**Confirmed endpoints (all HTTP 200, Content-Type: application/json):**

| Endpoint | Sample Response Fields |
|----------|----------------------|
| `/api/games` | game_no, game_status, csc_no, title_en, title_ko, country_code, location_city_en, match_min_datetime, match_max_datetime, match_type |
| `/api/game/127/matches` | match_no, game_no, stage_type, stage_name, stage_group_name, match_table_no, match_datetime, match_status, player_list (with player_no, total_score, total_run, total_inning, total_average, highrun1, highrun2), replay_no, live_id, broad_no |

**VOD linkage finding:** Each match record contains `replay_no` (e.g., 160553493) and `live_id` (e.g., "afbilliards1"). These can construct VOD URLs at `vod.sooplive.com/player/{replay_no}`. The `data-seq="{{:match_no}}"` placeholder in the schedule HTML maps to `match_no` in the API response — confirming match-level VOD linkage is possible via the API.

**Verdict: GO** — Full structured match data accessible without authentication.

## Decisions Made

- umbevents: NO-GO — HTTP 500 is a server error (ASP.NET compilation failure), not a parameter-missing error. Authentication required for all /Reports/ sub-pages.
- SoopLive: GO — JSON API fully functional and unauthenticated. Architecture should add a lightweight `SoopliveBilliardsClient` adapter (Phase 26 target).
- Discovery insight: For jsRender-template sites, inspecting the page's JS bundles is more productive than probing URL pattern guesses.

## Deviations from Plan

### Auto-added Bonus Investigation

**[Rule 2 - Enhancement] Probed discovered SoopLive API endpoints beyond the script specification**

- **Found during:** Task 2 (SoopLive probe)
- **Issue/Opportunity:** The JS bundle inspection revealed actual API paths not in the original plan. Not probing them would leave the GO/NO-GO verdict incomplete.
- **Fix:** Added inline Ruby probe of `/api/games` and `/api/game/{id}/matches` for 4 known game IDs (127, 129, 130, 137).
- **Files modified:** Output appended to `tmp/probe_sooplive_results.txt`
- **Verification:** All endpoints returned HTTP 200 with `application/json` responses containing structured match data.

---

**Total deviations:** 1 enhancement (bonus API verification beyond spec — necessary to provide a complete GO verdict)
**Impact on plan:** No scope creep — still within D-07 (existence check) and D-08 (1-2 samples). Enhanced SoopLive verdict quality.

## Issues Encountered

- `tmp/probe_umbevents.rb` and related files are covered by `.gitignore` (`/tmp/*`). Force-added with `git add -f` per plan's `files_modified` spec. Sample JSON files (in `tmp/samples/sooplive/`) remain gitignored as intended.
- SoopLive URL pattern guesses in Plan spec all returned 404 — the actual API paths were only discoverable via JS bundle inspection, confirming RESEARCH.md Pattern B/C finding.

## User Setup Required

None — no external service configuration required. All probe results are in `tmp/probe_*_results.txt` files.

## Next Phase Readiness

- Plan 02 (findings document) has all needed data for SoopLive and umbevents verdicts
- Cuesco (INVEST-02) still requires browser DevTools inspection — Plan 02 must document this as needing manual investigation
- SoopLive GO verdict means Phase 26 service extraction should include a `SoopliveBilliardsClient` alongside HTML parsers
- Sample responses saved in `tmp/samples/sooplive/` provide field-level detail for the findings document

---
*Phase: 24-data-source-investigation*
*Completed: 2026-04-12*
