---
phase: 20-characterization
plan: "02"
subsystem: league-characterization
tags: [characterization, league, standings, scraping, game-plan, tests]
dependency_graph:
  requires: []
  provides:
    - test/models/league_standings_test.rb
    - test/models/league_test.rb (expanded)
    - test/models/league_scraping_test.rb
  affects:
    - app/models/league.rb (bug fix: party_games.result column)
tech_stack:
  added: []
  patterns:
    - programmatic-local-id fixtures (TEST_ID_BASE + offset pattern)
    - WebMock stub_request regex matching for ClubCloud URLs
    - broad-rescue characterization (document swallow vs re-raise)
key_files:
  created:
    - test/models/league_standings_test.rb
    - test/models/league_scraping_test.rb
  modified:
    - test/models/league_test.rb
    - app/models/league.rb
decisions:
  - Use programmatic test data with local IDs (>= 50_000_000) to avoid fixture coupling
  - Test 404 as assert_nothing_raised (HTML parsed gracefully, table missing = no error)
  - Pin timeout behavior as assert_nothing_raised for instance methods (broad rescue at scrape_single_league_from_cc line 1391 swallows Net::OpenTimeout)
  - Pin timeout as assert_raises for class method scrape_leagues_from_cc (re-raises StandardError)
metrics:
  duration: ~35min
  completed: "2026-04-11T17:44:08Z"
  tasks_completed: 2
  files_changed: 4
---

# Phase 20 Plan 02: League Characterization — Standings, Game Plan, Scraping Summary

Pin League's three behavior clusters (standings tables, game plan reconstruction, scraping pipeline) with characterization tests. Purpose: ensure Phase 21 extraction preserves correctness across all three clusters.

## What Was Built

### Task 1: League standings + game plan characterization (commit 76b1dc40)

**Created `test/models/league_standings_test.rb`** — 9 tests across all three standings methods:

- `standings_table_karambol`: winner ranked first, empty league (0 punkte), draw result (1 punkt each), multi-party tie-breaking, key hash structure (:team, :platz, :punkte, :diff, :partien, etc.)
- `standings_table_snooker`: ranking for snooker-style discipline, :frames key presence
- `standings_table_pool`: ranking for pool discipline (pool_8ball fixture), :partien key, broad-rescue handles malformed result

**Expanded `test/models/league_test.rb`** from 3 to 7 tests:

- `analyze_game_plan_structure`: always appends Gesamtsumme row to game_plan[:rows]
- `reconstruct_game_plans_for_season`: returns Hash with :success/:failed/:errors keys; empty season returns 0/0/[]
- `reconstruct_game_plans_for_season` with filter opts: no error raised
- `reconstruct_game_plan_from_existing_data` with local parties: returns GamePlan or nil

### Task 2: League scraping pipeline characterization (commit 83e41173)

**Created `test/models/league_scraping_test.rb`** — 8 tests:

- `scrape_leagues_from_cc`: returns without error on 200 empty-table HTML; 404 body also handled gracefully (parsed as HTML with no table)
- `scrape_leagues_optimized`: returns without error on 200 empty-table HTML
- `scrape_league_optimized` (instance): no error when stub returns HTML with no team table; no error on timeout (broad rescue swallows)
- `scrape_league_teams_optimized`: no error on HTML with no team table
- `scrape_party_games_optimized`: no error on HTML with no team table
- `scrape_leagues_from_cc` timeout: raises StandardError (class method re-raises)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed invalid column reference in scrape_league_optimized and scrape_league_teams_optimized**

- **Found during:** Task 2
- **Issue:** Both methods used `where.not(party_games: { result: nil })` to check if party_games have results. Column `party_games.result` does not exist — results are stored in the `data` JSON column. This caused `ActiveRecord::StatementInvalid: PG::UndefinedColumn: ERROR: column party_games.result does not exist`.
- **Fix:** Changed both occurrences to `where("party_games.data IS NOT NULL AND party_games.data NOT IN ('null', '{}', '')")` to check for presence of data. This preserves the intent (has data been recorded?) while using valid SQL.
- **Files modified:** `app/models/league.rb` (lines 541, 556)
- **Commit:** 83e41173

**2. [Test correction] 404 test expectation corrected**

- **Found during:** Task 2 test run
- **Issue:** Initial test expected `scrape_leagues_from_cc` to raise on 404. The method parses the 404 response body as HTML and finds no matching table (nil), returning without error.
- **Fix:** Changed to `assert_nothing_raised`.

**3. [Test correction] Instance method timeout expectation corrected**

- **Found during:** Task 2 test run
- **Issue:** `scrape_single_league_from_cc` has a top-level `rescue StandardError => e` at the end (line ~1391) that logs and returns nil without re-raising. `Net::OpenTimeout` is caught and swallowed.
- **Fix:** Changed to `assert_nothing_raised` to document the actual broad-rescue behavior.

## Known Stubs

None — all test data is wired to real League/LeagueTeam/Party model instances with local IDs.

## Test Results

```
25 runs, 79 assertions, 0 failures, 0 errors, 1 skip
```

The skip is the pre-existing test that skips when `@league.discipline.present? && @league.parties.any?` (fixture league has no parties).

## Self-Check: PASSED

- FOUND: test/models/league_standings_test.rb
- FOUND: test/models/league_scraping_test.rb
- FOUND: test/models/league_test.rb (expanded)
- FOUND: commit 76b1dc40 (Task 1)
- FOUND: commit 83e41173 (Task 2)
