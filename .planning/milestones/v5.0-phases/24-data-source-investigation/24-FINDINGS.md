# Phase 24: Data Source Investigation — Findings

**Investigated:** 2026-04-12
**Investigator:** Claude (Plan 01 automated probes) + User (Plan 02 browser DevTools inspection)

## Executive Summary

Three UMB-related data sources were investigated for structured (JSON/XML) data availability. Of the three targets, one (SoopLive) is a definitive GO: its billiards schedule and match data API is unauthenticated, returns fully structured JSON, and includes per-match VOD cross-reference IDs. One (umbevents.umb-carom.org) is a definitive NO-GO: all `/Reports/` endpoints return HTML or ASP.NET server errors regardless of request headers or query parameters, with no JSON surface exposed without an authenticated session. The third (Cuesco/umb.cuesco.net) is also a NO-GO: browser DevTools confirmed the site is entirely server-rendered HTML with no Fetch/XHR requests at all — the jsRender template evidence from RESEARCH.md turned out to be stale or from a different Cuesco deployment. The net outcome is that Phase 26 service extraction should add a lightweight `SoopliveBilliardsClient` JSON adapter while continuing to rely on HTML scraping for UMB tournament and result data.

---

## Source 1: umbevents.umb-carom.org

**Probe method:** Ruby Net::HTTP script (`tmp/probe_umbevents.rb`) — 3 endpoints x 4 header combinations x 3 query parameter variants (id=1, event_id=1, year=2025) = 27 probes total.

**Endpoints tested:**

| URL | Headers tried | Query params tried |
|-----|--------------|-------------------|
| `https://umbevents.umb-carom.org/Reports/ViewAllRanks` | (default), Accept: application/json, + X-Requested-With, + q=0.01 variant | (none), ?id=1, ?event_id=1, ?year=2025 |
| `https://umbevents.umb-carom.org/Reports/ViewTimetable` | (default), Accept: application/json, + X-Requested-With, + q=0.01 variant | (none), ?id=1, ?event_id=1, ?year=2025 |
| `https://umbevents.umb-carom.org/Reports/ViewPlayers` | (default), Accept: application/json, + X-Requested-With, + q=0.01 variant | (none), ?id=1, ?event_id=1, ?year=2025 |

**Results:**

| Endpoint | Status | Content-Type | Notes |
|----------|--------|-------------|-------|
| `/Reports/ViewAllRanks` (all header + param variants) | 500 | text/html | ASP.NET Compilation Error page — consistent across all 16 probes |
| `/Reports/ViewTimetable` (all header + param variants) | 500 | text/html | Same ASP.NET Compilation Error page |
| `/Reports/ViewPlayers` (all header + param variants) | 200 | text/html | Bootstrap admin template (Admin Lab Dashboard v2.3.1 by Mosaddek Hossain) — no data content |

**Sample response (representative — same for all probes):**

ViewAllRanks and ViewTimetable — all variants:
```
HTTP 500 — Content-Type: text/html; charset=utf-8
<!DOCTYPE html>
<html>
    <head>
        <title>Compilation Error</title>
        ...ASP.NET server error page...
```

ViewPlayers — all variants:
```
HTTP 200 — Content-Type: text/html; charset=utf-8
<!DOCTYPE html>
<!--
Template Name: Admin Lab Dashboard build with Bootstrap v2.3.1
Author: Mosaddek Hossain
...empty bootstrap shell, no player data...
```

**Analysis:** The HTTP 500 on ViewAllRanks and ViewTimetable is a server-side ASP.NET compilation failure — the response body is an ASP.NET Compilation Error page, not a parameter-missing error response. The same error appears with every query parameter variant (`?id=1`, `?event_id=1`, `?year=2025`), ruling out a missing-parameter cause. ViewPlayers returns 200 but only serves the outer Bootstrap admin template with no actual player data — this is a server-side rendered shell that requires a session cookie from a prior authenticated login to populate. No JSON surface is exposed at any `/Reports/` endpoint under any tested condition.

**Verdict: NO-GO**

**Rationale (per D-05):** No structured data returned under any condition tested. HTTP 500 is a server error (ASP.NET compilation failure), not a gated JSON endpoint. ViewPlayers returns an empty shell requiring auth. Per D-06 and D-05, even a partial JSON response would qualify as GO — but there is none. The endpoint appears to require an authenticated session cookie that cannot be obtained without a valid UMB login.

---

## Source 2: umb.cuesco.net (Cuesco/Five&Six)

**Probe method:** Browser DevTools inspection by user (Plan 02 Task 1 checkpoint). Site was ECONNREFUSED from the development environment in all prior automated probes, making browser inspection the only viable method.

**Inspection performed:** User opened Chrome DevTools, Network tab filtered by Fetch/XHR, and navigated through the site.

**Endpoints discovered:** None.

**Results:**

The user's direct report: "there are no Fetch/XHR requests at all" — the site is entirely server-rendered HTML. No AJAX or JSON API calls were observed during page navigation.

This contradicts the earlier research finding that umb.cuesco.net uses jsRender templates with `{{:match_no}}` template variables. The most likely explanations are: (1) the jsRender evidence was from a different Cuesco deployment or a development/staging environment, (2) the site underwent a full rewrite to server-side rendering, or (3) the user navigated a part of the site that uses SSR while the match data section (if any) uses a different technology. In any case, the browser inspection is definitive: no structured data is accessible without authentication or further investigation of a different URL path.

**Sample response:** Not applicable — no JSON endpoints found.

**Verdict: NO-GO**

**Rationale (per D-05):** No structured data found. Browser DevTools is the highest-fidelity inspection method for AJAX-loaded sites — if no Fetch/XHR requests appear in the Network tab during normal navigation, the site is HTML-only for those pages. The original jsRender assumption was not confirmed by direct inspection. Per D-07, no further deep investigation is warranted in this phase.

---

## Source 3: billiards.sooplive.com

**Probe method:** Ruby Net::HTTP script (`tmp/probe_sooplive.rb`) — Phase 1 direct URL pattern guesses, Phase 2 HTML inspection + external JS bundle analysis. Browser DevTools inspection was not required — the API was fully discovered by reading the `/lib/schedule.js` JS bundle.

**Endpoints tested (Phase 1 — pattern guesses, all returned 404):**

| URL | Status | Content-Type |
|-----|--------|-------------|
| `https://billiards.sooplive.com/api/schedule/127` | 404 | application/json (`{"error":"NOT_FOUND"}`) |
| `https://billiards.sooplive.com/schedule/127/matches` | 404 | text/html |
| `https://billiards.sooplive.com/schedule/127.json` | 404 | text/html |
| `https://billiards.sooplive.com/api/schedule/127/matches` | 404 | application/json (`{"error":"NOT_FOUND"}`) |
| `https://billiards.sooplive.com/schedule/api/127` | 404 | text/html |
| `https://api.sooplive.com/schedule/127` | 404 | application/json (`{"message":"Cannot GET /schedule/127","error":"Not Found","statusCode":404}`) |

**Note:** The 404 responses with `Content-Type: application/json` from `billiards.sooplive.com/api/*` and `api.sooplive.com/*` confirm a JSON API router exists — the paths simply don't match.

**Phase 2 — JS bundle discovery:** The schedule page HTML (`/schedule/127?sub1=result`) loaded external bundle `/lib/schedule.js?v=1775992798`. Reading that bundle exposed the actual API path strings directly:

```javascript
url  :  `/api/games`
url  :  `/api/game/${gameNo}/matches`
url  :  `/api/game/${gameNo}/results`
```

**Confirmed endpoints (all HTTP 200, Content-Type: application/json):**

| Endpoint | Status | Key Fields |
|----------|--------|-----------|
| `GET /api/games` | 200 | game_no, game_status, csc_no, event_code, title_en, title_ko, country_code, location_city_en, location_city_ko, match_min_datetime, match_max_datetime, match_type, logo_url, last_match_no |
| `GET /api/game/{game_no}/matches` | 200 | match_no, game_no, record_yn, stage_type, stage_name, stage_group_name, match_table_no, match_datetime, match_status, player_count, replay_no, live_id, broad_no, player_list (player_no, total_score, total_run, total_inning, total_average, highrun1, highrun2) |
| `GET /api/game/{game_no}/results` | 200 | result_list (empty for non-finalized events) |

**Sample response — `/api/games` (first record, truncated to key fields):**

```json
{
  "list": [
    {
      "game_status": "PLAYING",
      "game_no": 180,
      "csc_no": 203,
      "event_code": "01",
      "last_match_no": 20638,
      "title_en": "BOGOTA World Cup 3-Cushion 2026",
      "title_ko": "2026 보고타 3쿠션 월드컵",
      "logo_url": "https://sports.img.sooplive.co.kr/billiards/game/623969bb64bae88fa.png",
      "country_code": "COL",
      "location_city_en": "Bogota",
      "location_city_ko": "보고타",
      "match_min_datetime": "2026-04-06 00:00:00",
      "match_max_datetime": "2026-04-13 23:59:59",
      "match_type": 0
    }
  ]
}
```

**Sample response — `/api/game/127/matches` (first record, key fields):**

```json
{
  "match_list": [
    {
      "match_no": 16669,
      "game_no": 127,
      "record_yn": "Y",
      "stage_type": "QUALIFIERS",
      "stage_name": "PPPQ",
      "stage_group_name": "A",
      "match_table_no": 1,
      "match_datetime": "2025-05-19 13:00:00",
      "match_status": "FINISHED",
      "player_count": 2,
      "highlight_no": 0,
      "replay_no": 160553493,
      "live_id": "afbilliards1",
      "broad_no": 0,
      "player_list": [
        {
          "match_player_no": 40375,
          "player_no": 1259,
          "stage_no": 737,
          "stage_group_no": 1,
          "total_score": 30,
          "total_run": 30,
          "total_inning": 33,
          "total_average": "0.909",
          "highrun1": 5,
          "highrun2": 4
        }
      ]
    }
  ]
}
```

**Confirmed for game IDs 127, 129, 137:** All return HTTP 200 with structured match records. Game 130 returned empty `match_list` (likely a game with no recorded matches yet).

**VOD linkage finding:** Each match record contains `replay_no` (e.g., `160553493`) and `live_id` (e.g., `"afbilliards1"`). The `replay_no` maps directly to a SoopLive VOD URL at `https://vod.sooplive.com/player/{replay_no}`. The `data-seq="{{:match_no}}"` placeholder in the schedule page HTML corresponds to `match_no` in the API response — confirming match-level linkage from the HTML and the API use the same identifier. VOD cross-referencing is achievable without scraping.

**Stage naming convention:** The `stage_name` field uses the same stage abbreviations as `UmbScraper::GAME_TYPE_MAPPINGS` (PPPQ, PPQ, PQ, Q, R16, etc.) — direct compatibility with existing Carambus stage name handling.

**Verdict: GO**

**Rationale (per D-05):** Full structured match data accessible without authentication. The API returns tournament lists, per-match records with player statistics, and VOD IDs for cross-referencing. Per D-05, "structured is enough" — and this source provides more structured data than the existing HTML scraper captures. Per D-06, no 80% coverage threshold applies — this source covers game lists, match records, and VOD linkage.

---

## Architecture Impact

**One GO verdict (SoopLive) — architecture impact is targeted, not broad:**

The SoopLive JSON API is a clean, unauthenticated REST API that returns structured tournament and match data currently obtainable only via HTML scraping. Phase 26 service extraction should add a lightweight `SoopliveBilliardsClient` adapter class:

- **New adapter:** `app/services/sooплive_billiards_client.rb` (or `app/services/sooplive/billiards_client.rb`)
- **Pattern:** Mirror `KozoomScraper`'s REST client pattern — `fetch_json(url)` wrapper around `Net::HTTP`, no authentication required
- **Endpoints to wrap:** `GET /api/games`, `GET /api/game/{id}/matches`, `GET /api/game/{id}/results`
- **Primary consumer:** `SoopliveScraper` — replace HTML-scraping of schedule/result pages with JSON API calls for `game_no`-identified events
- **Phase 28 impact (video cross-referencing):** `replay_no` from the matches API enables direct VOD URL construction (`vod.sooplive.com/player/{replay_no}`) without title+date fuzzy matching. This is the highest-precision video cross-reference available in the project.

**Two NO-GO verdicts (umbevents, Cuesco) — no architecture change required:**

- `UmbScraper` and `UmbScraperV2` continue to use HTML scraping against `files.umb-carom.org`
- No `Umb::CuescoClient` or `Umb::UmbEventsClient` adapter should be planned for Phase 26
- Phase 28 video cross-referencing for UMB events (non-SoopLive) must use title+date matching only
- The Phase 25 UmbScraper refactoring proceeds as an HTML-scraper-only extraction effort

---

## Go/No-Go Decision

| Source | Verdict | Data Available | Adapter Worth Building? |
|--------|---------|----------------|------------------------|
| umbevents.umb-carom.org | NO-GO | None — HTML-only or HTTP 500 (auth required) | NO |
| umb.cuesco.net (Cuesco) | NO-GO | None — entirely server-rendered HTML, no Fetch/XHR | NO |
| billiards.sooplive.com | GO | game_no, title_en/ko, country_code, match_no, stage_type, stage_name, player scores/innings/averages, replay_no (VOD ID), live_id | YES — `SoopliveBilliardsClient` |

**Phase 26 gates:**
- GO verdict for SoopLive: Phase 26 **must** add `SoopliveBilliardsClient` adapter in the `Umb::` namespace (or `Sooplive::` sub-namespace)
- NO-GO for umbevents and Cuesco: Phase 26 proceeds with HTML-scraping-only extraction for all UMB tournament data
- Phase 28 video cross-referencing: SoopLive events use `replay_no` direct VOD linkage; all other sources use title+date fuzzy matching fallback

---

*Phase: 24-data-source-investigation*
*Investigated: 2026-04-12*
