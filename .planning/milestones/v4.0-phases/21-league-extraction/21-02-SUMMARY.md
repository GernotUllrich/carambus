---
phase: 21-league-extraction
plan: "02"
subsystem: league
tags: [extraction, service-object, scraping, club-cloud, bbv]
dependency_graph:
  requires: [21-01]
  provides: [League::ClubCloudScraper, League::BbvScraper]
  affects: [app/models/league.rb]
tech_stack:
  added: []
  patterns: [ApplicationService, delegation-wrapper, instance-variable-state]
key_files:
  created:
    - app/services/league/club_cloud_scraper.rb
    - app/services/league/bbv_scraper.rb
    - test/services/league/club_cloud_scraper_test.rb
    - test/services/league/bbv_scraper_test.rb
  modified:
    - app/models/league.rb
decisions:
  - "Moved get_league_doc helper into BbvScraper.fetch_league_doc (only callers were BBV methods)"
  - "Initialized records_to_tag = [] in scrape_all (original code had undefined variable bug)"
  - "Guarded nav_link CSS selector with nil check in scrape_single_bbv_league (original crashed on missing element)"
  - "Used .dup before force_encoding to handle frozen WebMock response strings"
  - "Moved original scrape_single_league_from_cc body wholesale then removed dead code via Python splice"
metrics:
  duration: ~20 minutes
  completed_date: "2026-04-11"
  tasks: 2
  files: 5
---

# Phase 21 Plan 02: ClubCloudScraper and BbvScraper Extraction Summary

League model reduced 70% (2221 to 663 lines) by extracting ClubCloud and BBV scraping into dedicated ApplicationService classes with thin delegation wrappers.

## What Was Built

### Task 1: League::ClubCloudScraper ApplicationService

Extracted the 821-line `scrape_single_league_from_cc` method into `League::ClubCloudScraper < ApplicationService`. The monolithic method was decomposed into well-named private methods:

- `scrape_league` — entry guard, cleanup, BBV redirect, orchestration
- `scrape_from_club_cloud` — URL construction, HTTP fetch, sequential dispatch
- `parse_teams(league_doc, url)` — team table scraping, club/player resolution, seeding
- `parse_parties(league_doc, url)` — party game scraping, game report parsing
- `build_game_plan(disciplines)` — game plan data cleanup
- `save_game_plan` — GamePlan record create/update

Cross-method state (clubs_cache, league_teams_cache, league_team_players, region_id, etc.) converted to instance variables (`@clubs_cache`, etc.) as prescribed by Pitfall 3.

The broad `rescue StandardError => e` from the original is preserved at the `call` level, swallowing all errors and logging them — same behavior as original.

Delegation wrapper in league.rb:
```ruby
def scrape_single_league_from_cc(opts = {})
  League::ClubCloudScraper.call(league: self, **opts)
end
```

### Task 2: League::BbvScraper ApplicationService

Extracted `scrape_bbv_leagues` (class method), `scrape_single_bbv_league` (instance method), and `scrape_bbv_league_teams` (private instance method) into `League::BbvScraper < ApplicationService`.

Also moved `get_league_doc` (private class method) into `BbvScraper.fetch_league_doc` since its only callers were the BBV scraping methods.

`scrape_all` class method returns `records_to_tag` array (Pitfall 4 preserved).

Delegation wrappers in league.rb:
```ruby
def self.scrape_bbv_leagues(region, season, opts = {})
  League::BbvScraper.scrape_all(region: region, season: season, opts: opts)
end

def scrape_single_bbv_league(region, opts = {})
  League::BbvScraper.call(league: self, region: region, **opts)
end
```

## Line Counts

| File | Lines |
|------|-------|
| app/models/league.rb (after) | 663 |
| app/models/league.rb (before phase 21) | 2221 |
| app/services/league/club_cloud_scraper.rb | 878 |
| app/services/league/bbv_scraper.rb | 161 |
| app/services/league/game_plan_reconstructor.rb | 461 |
| app/services/league/standings_calculator.rb | 237 |

**Net reduction: 1558 lines (70.2%) from 2221 to 663.**

## Test Results

- `bin/rails test test/services/league/club_cloud_scraper_test.rb`: 3 runs, 0 failures
- `bin/rails test test/services/league/bbv_scraper_test.rb`: 2 runs, 0 failures
- `bin/rails test test/models/league_scraping_test.rb`: 8 runs, 0 failures (characterization tests unchanged)
- `bin/rails test` (full suite): **856 runs, 2031 assertions, 0 failures, 0 errors, 14 skips**

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed undefined `records_to_tag` variable in scrape_bbv_leagues**
- **Found during:** Task 2 implementation review
- **Issue:** Original `League.scrape_bbv_leagues` referenced `records_to_tag` without initialization (would crash with NameError on first call)
- **Fix:** Added `records_to_tag = []` initialization at start of `BbvScraper.scrape_all`
- **Files modified:** app/services/league/bbv_scraper.rb

**2. [Rule 1 - Bug] Fixed nil crash in scrape_single_bbv_league nav selector**
- **Found during:** Task 2 test execution (error: `NoMethodError: undefined method 'attributes' for nil`)
- **Issue:** Original `select { }[0]` pattern (now `find`) crashes when no matching anchor found in HTML
- **Fix:** Added nil guard: `nav_link ? url + nav_link.attributes["href"].value : nil`
- **Files modified:** app/services/league/bbv_scraper.rb

**3. [Rule 1 - Bug] Fixed FrozenError on force_encoding with WebMock response**
- **Found during:** Task 2 test execution
- **Issue:** WebMock returns frozen strings; `force_encoding` modifies string in place, raising FrozenError
- **Fix:** Added `.dup` before `force_encoding`
- **Files modified:** app/services/league/bbv_scraper.rb

**4. [Rule 3 - Blocking] Used Python splice to remove 822-line dead code block from league.rb**
- **Found during:** Task 1 — Edit tool cannot replace 822 contiguous lines in one operation without ambiguity
- **Issue:** Needed to remove the entire original method body after adding delegation wrapper
- **Fix:** Used Python one-liner to splice lines from the file directly
- **Files modified:** app/models/league.rb

## Known Stubs

None — all extracted methods contain real implementation code moved from the original model. No placeholder data flows to UI rendering.

## Threat Flags

None — pure internal refactoring. No new network endpoints, auth paths, or schema changes introduced.

## Self-Check: PASSED

All files and commits verified:
- FOUND: app/services/league/club_cloud_scraper.rb
- FOUND: app/services/league/bbv_scraper.rb
- FOUND: test/services/league/club_cloud_scraper_test.rb
- FOUND: test/services/league/bbv_scraper_test.rb
- FOUND: commit f1fea29e (ClubCloudScraper extraction)
- FOUND: commit df51f698 (BbvScraper extraction + full suite)
