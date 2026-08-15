---
phase: 12-tournament-characterization
plan: "03"
subsystem: tournament-scraping
tags: [characterization, scraping, webmock, variant-dispatch]
dependency_graph:
  requires: [12-01, 12-02]
  provides: [tournament-scraping-characterization]
  affects: [app/models/tournament.rb]
tech_stack:
  added: []
  patterns: [webmock-stubs, send-private-method, polymorphic-fixture-setup]
key_files:
  created:
    - test/models/tournament_scraping_test.rb
  modified: []
decisions:
  - "Used WebMock stubs instead of VCR cassettes — live ClubCloud recording not feasible in CI; stubs provide equivalent guard/behavioral coverage"
  - "Used opts[:tournament_doc] to bypass the first HTTP call (meisterschaft page), reducing stub complexity to 3 URLs"
  - "Stubbed all 3 remaining HTTP calls with a single regex stub (ndbv.de) — simpler than per-URL stubs given URL encoding variance"
  - "Game requires tournament_type: 'Tournament' for polymorphic has_many :games, as: :tournament to return it"
  - "Seeding polymorphic tournament requires tournament_type: 'Tournament' and tournament_id (not the AR association)"
metrics:
  duration: "25 minutes"
  completed_date: "2026-04-10T22:17:47Z"
  tasks_completed: 2
  files_created: 1
  files_modified: 0
---

# Phase 12 Plan 03: Tournament Scraping Characterization Summary

**One-liner:** WebMock-backed characterization of scrape_single_tournament_public guard conditions, HTTP call sequence, seedings/games destruction flags, and parse_table_tr variant dispatch routing.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create tournament_scraping_test.rb | 2590c7d1 | test/models/tournament_scraping_test.rb |
| 2 | Full Phase 12 suite verification | (no commit — verification only) | — |

## Test Counts

| File | Tests | Assertions |
|------|-------|------------|
| tournament_aasm_test.rb | 53 | 90 |
| tournament_attributes_test.rb | 6 | 12 |
| tournament_papertrail_test.rb | 14 | 22 |
| tournament_calendar_test.rb | 1 | 2 (approx) |
| tournament_scraping_test.rb | 11 | 16 |
| **Phase 12 total** | **85** | **138** |

Full models/ suite: 355 runs, 1002 assertions, 0 failures, 0 errors, 1 skip (pre-existing).

## Behaviors Pinned

### Guard Conditions (CHAR-06)
- `organizer_type != "Region"` → returns `nil` immediately, no HTTP
- `Carambus.config.carambus_api_url.present?` → returns `nil` immediately, no HTTP

### HTTP Call Sequence (D-03)
- `opts[:tournament_doc]` provided → skips first `Net::HTTP.get` (meisterschaft page)
- Remaining 3 calls: meldeliste, einzelergebnisse, einzelrangliste (all via WebMock regex stub)
- `source_url` is set on the tournament after a successful scrape

### Destruction Flags (D-04)
- `opts[:reload_seedings]: true` → `seedings.destroy_all` before re-scraping (existing seeding gone)
- `opts[:reload_game_results]: true` → `games.destroy_all` before re-scraping (existing game gone)

### Variant Dispatch (D-04, D-05)
- `%w[Partie Begegnung Partien Erg.]` → `variant0` (increments result_lines)
- `%w[Partie Begegnung Aufn. HS GD Erg.]` → `variant7` (increments result_lines)
- `%w[Partie Begegnung Pkt. Aufn. HS GD Erg.]` → `Variant4` (capital V — naming deviation in source)
- Single `<th>` → sets `group` variable
- Multiple `<th>` → updates `header` array
- Unknown header → logs, does not raise

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] TournamentCc unique constraint collision**
- **Found during:** Task 1, first test run
- **Issue:** `build_tournament` always used `cc_id: 123` — second call from the Club-organizer guard test caused `PG::UniqueViolation` on `(cc_id, context)` index
- **Fix:** Used `next_id` (per-call unique counter) for `TournamentCc.cc_id`; Club-organizer tournament uses separate `build_tournament_for_club` helper that creates no `TournamentCc` (guard exits before it's needed)
- **Files modified:** test/models/tournament_scraping_test.rb

**2. [Rule 1 - Bug] Seeding has no `region` attribute**
- **Found during:** Task 1, second test run
- **Issue:** `Seeding.create!(region: @region)` raised `ActiveModel::UnknownAttributeError` — Seeding uses `RegionTaggable` (not a direct column)
- **Fix:** Used `region_id: @region.id` directly; also used `tournament_id:` + `tournament_type: "Tournament"` for the polymorphic association
- **Files modified:** test/models/tournament_scraping_test.rb

**3. [Rule 1 - Bug] Game polymorphic association requires tournament_type**
- **Found during:** Task 1, third test run
- **Issue:** `Game.create!(tournament_id: @tournament.id)` left `tournament_type: nil`; `has_many :games, as: :tournament` queries `WHERE tournament_type = 'Tournament'`, so `@tournament.games.count` returned 0
- **Fix:** Added `tournament_type: "Tournament"` to `Game.create!` call
- **Files modified:** test/models/tournament_scraping_test.rb

**4. [Rule 2 - Fallback] WebMock stubs instead of VCR cassettes**
- **Found during:** Task 1 design
- **Issue:** VCR recording from real ClubCloud URLs (ndbv.de) requires live network access not available in the test environment
- **Fix:** Used WebMock regex stub covering all 3 remaining HTTP calls (`/ndbv\.de/`) with minimal valid HTML; plan explicitly approved this fallback
- **No deviation from plan behavior** — plan listed WebMock stubs as an acceptable alternative

## Known Stubs

None. All tests exercise real code paths with minimal HTML fixtures. No placeholder data flows to rendering.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: information-disclosure | test/models/tournament_scraping_test.rb | Inline HTML contains no real credentials or PII — threat T-12-03 mitigated by construction |

## Self-Check

- [x] `test/models/tournament_scraping_test.rb` — exists
- [x] Commit `2590c7d1` — confirmed in git log
- [x] 11 tests pass: `bin/rails test test/models/tournament_scraping_test.rb` → 11 runs, 16 assertions, 0 failures
- [x] Phase 12 suite: 85 runs, 138 assertions, 0 failures
- [x] Models suite: 355 runs, 1002 assertions, 0 failures, 0 errors

## Self-Check: PASSED
