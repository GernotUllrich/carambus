---
phase: 25-characterization-tests-bug-fixes
plan: "02"
subsystem: umb-scrapers
tags: [characterization-tests, vcr, umb-scraper, test-coverage]
dependency_graph:
  requires: [25-01]
  provides: [UmbScraper characterization tests, VCR cassette infrastructure for UMB, SCRP-01]
  affects: [test/characterization/umb_scraper_char_test.rb, test/snapshots/vcr/umb/]
tech_stack:
  added: []
  patterns: [VCR hybrid approach (cassette + WebMock fixture), save(validate:false) for characterization fixtures]
key_files:
  created:
    - test/characterization/umb_scraper_char_test.rb
    - test/fixtures/html/umb_tournament_detail.html
    - test/snapshots/vcr/umb/.keep
  modified: []
decisions:
  - "Used save(validate:false) for InternationalTournament test records to bypass season/organizer validations not relevant to characterization"
  - "Hybrid D-02 approach: VCR cassettes for HTTP-dependent tests, WebMock+fixture HTML for scrape_tournament_details (no live endpoint needed)"
  - "13 tests cover all 5 required critical paths plus initialize and discipline detection edge cases"
metrics:
  duration_minutes: 8
  completed_date: "2026-04-12"
  tasks_completed: 1
  tasks_total: 1
  files_created: 3
  files_modified: 0
  test_runs: 13
  test_failures: 0
---

# Phase 25 Plan 02: UmbScraper Characterization Tests Summary

**One-liner:** VCR-backed characterization test suite for all UmbScraper critical paths using hybrid approach — cassettes for HTTP-dependent tests, WebMock+fixture HTML for `scrape_tournament_details`.

## What Was Built

### Task 1: UmbScraper Characterization Test File with VCR Infrastructure

Created `test/characterization/umb_scraper_char_test.rb` with 13 tests covering all UmbScraper public method critical paths.

**Test structure follows the `region_cc_char_test.rb` pattern exactly:**
- `VCR_RECORD_MODE` constant with `ENV["RECORD_VCR"]` toggle
- `cassette_exists?` helper for graceful skip detection
- `with_vcr_cassette` helper that skips with recording instructions instead of failing

**Tests by section:**

| Section | Tests | VCR | Pass/Skip |
|---------|-------|-----|-----------|
| A. Initialize | 1 | No | Pass |
| B. detect_discipline_from_name | 5 | No | Pass |
| C. scrape_rankings stub | 1 | No | Pass |
| D. scrape_future_tournaments | 1 | Yes | Skip (no cassette) |
| E. scrape_tournament_archive | 1 | Yes | Skip (no cassette) |
| F. fetch_tournament_basic_data | 1 | Yes | Skip (no cassette) |
| G. scrape_tournament_details | 3 | Mixed | 2 Pass, 1 Skip |

**Hybrid approach (D-02):** The `scrape_tournament_details` fixture test uses `WebMock` with `test/fixtures/html/umb_tournament_detail.html` (minimal UMB detail page HTML). This test runs without any VCR cassette and validates the Nokogiri parsing of `location_text` and the `false` return for missing URLs.

**VCR cassette directory:** `test/snapshots/vcr/umb/` created with `.keep` file. Cassettes recorded via `RECORD_VCR=true bin/rails test test/characterization/umb_scraper_char_test.rb`.

## Verification Results

- `bin/rails test test/characterization/umb_scraper_char_test.rb` — 13 runs, 19 assertions, 0 failures, 0 errors, 4 skips
- 4 VCR tests skip cleanly with recording instructions
- `grep -c "def test_\|test \"" test/characterization/umb_scraper_char_test.rb` — 13 (above required minimum of 7)
- `ls test/snapshots/vcr/umb/` — directory exists with `.keep`
- `frozen_string_literal: true` present in test file

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | 6da908c6 | feat(25-02): add UmbScraper characterization tests with VCR infrastructure |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Used save(validate:false) for test InternationalTournament records**
- **Found during:** Task 1 (scrape_tournament_details tests)
- **Issue:** `InternationalTournament` inherits `belongs_to :season` and `belongs_to :organizer, polymorphic: true` (both required, not optional) from `Tournament`. Creating test records with `create!` raised `ActiveRecord::RecordInvalid` for missing season/organizer.
- **Fix:** Used `tournament.save(validate: false)` for characterization test fixture records. These fields are irrelevant to the `scrape_tournament_details` behavior being characterized. The same pattern is used throughout the project's characterization tests.
- **Files modified:** test/characterization/umb_scraper_char_test.rb
- **Commit:** 6da908c6

## Known Stubs

None — all test implementations are complete and functional. The `scrape_rankings` stub is documented as an intentional stub in UmbScraper itself (returns 0 by design).

## Threat Surface

No new network endpoints, auth paths, or schema changes introduced. Test files only. The VCR cassette directory (`test/snapshots/vcr/umb/`) will contain public HTML from UMB tournament pages when recorded — within the plan's declared threat model (T-25-03: public HTML, no credentials or PII).

## Self-Check: PASSED

- `test/characterization/umb_scraper_char_test.rb` — EXISTS
- `test/fixtures/html/umb_tournament_detail.html` — EXISTS
- `test/snapshots/vcr/umb/.keep` — EXISTS
- Commit 6da908c6 — FOUND in git log --all
- Test count: 13 (>= required 7)
