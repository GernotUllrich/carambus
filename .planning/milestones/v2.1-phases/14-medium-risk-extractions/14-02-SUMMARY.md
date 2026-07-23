---
phase: 14-medium-risk-extractions
plan: "02"
subsystem: tournament-scraping
tags: [extraction, service, scraping, clubcloud, refactoring]
dependency_graph:
  requires: []
  provides: [Tournament::PublicCcScraper]
  affects: [app/models/tournament.rb, test/models/tournament_scraping_test.rb]
tech_stack:
  added: [Tournament::PublicCcScraper < ApplicationService]
  patterns: [ApplicationService extraction, delegation wrapper, self→@tournament conversion]
key_files:
  created:
    - app/services/tournament/public_cc_scraper.rb
    - test/services/tournament/public_cc_scraper_test.rb
  modified:
    - app/models/tournament.rb
    - test/models/tournament_scraping_test.rb
decisions:
  - "Faithful move of all ~1000 lines from Tournament with self→@tournament substitution; no redesign"
  - "parse_table_td (dead code) moved with scraper for completeness per RESEARCH.md"
  - "Variant4 method name preserved with capital V as required by Pitfall 2"
  - "rescue block calls @tournament.reset_tournament — not bare reset_tournament (Pitfall 3)"
  - "No extra save! added in delegation wrapper — PaperTrail double-version risk avoided (Pitfall 6)"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-10T23:39:55Z"
  tasks_completed: 2
  files_changed: 4
---

# Phase 14 Plan 02: PublicCcScraper Extraction Summary

Extracted `Tournament::PublicCcScraper` ApplicationService — the largest single extraction in the v2.1 milestone. All ~1019 lines of ClubCloud scraping pipeline moved from Tournament into a dedicated service with faithful `self`→`@tournament` conversion.

## What Was Built

### Tournament::PublicCcScraper (app/services/tournament/public_cc_scraper.rb)

ApplicationService containing 20 methods extracted from Tournament:
- `call` — full body of `scrape_single_tournament_public` (HTTP fetches, Nokogiri parsing, seeding/game/ranking processing)
- `parse_table_tr` — variant dispatch router (routes to variant0-8 and result_with_*)
- `handle_game` — creates/updates Game and GameParticipation records
- `parse_table_td` — dead code, moved for completeness
- `variant0`, `variant2`, `variant3`, `variant5`, `variant6`, `variant7`, `variant8` — result row parsers
- `Variant4` — capital V preserved (Ruby treats it as a method call, not constant)
- `result_with_party`, `result_with_parties`, `result_with_frames`, `result_with_party_variant`, `result_with_party_variant2` — frame result parsers
- `fix_location_from_location_text` — dead code, moved with scraper

### Tournament Delegation (app/models/tournament.rb)

Replaced ~1019 lines with 3-line wrapper:
```ruby
def scrape_single_tournament_public(opts = {})
  Tournament::PublicCcScraper.call(tournament: self, opts: opts)
end
```

Tournament reduced from 1594 → 575 lines (1019 lines removed).

### Updated Tests

`test/models/tournament_scraping_test.rb` — `call_parse_table_tr` helper updated to use service instance:
```ruby
scraper = Tournament::PublicCcScraper.new(tournament: @tournament)
out = scraper.send(:parse_table_tr, ...)
```

`test/services/tournament/public_cc_scraper_test.rb` — 3 new WebMock-backed tests verifying guard conditions and successful execution with stubs.

## Test Results

```
42 runs, 56 assertions, 0 failures, 0 errors, 0 skips
```

Tests covered: `tournament_scraping_test.rb` (32 tests), `tournament_aasm_test.rb` (7 tests), `public_cc_scraper_test.rb` (3 tests).

## Deviations from Plan

None — plan executed exactly as written.

The actual line reduction (1019 lines) was larger than the plan estimated (~800 lines) because `parse_table_td` is ~188 lines of dead code that was included per the RESEARCH.md directive ("DEAD CODE but move with scraper for completeness").

## Commits

- `029b0baf` — feat(14-02): create Tournament::PublicCcScraper ApplicationService
- `d40f6842` — feat(14-02): wire delegation in Tournament, update tests, add service test

## Self-Check: PASSED

- [x] `app/services/tournament/public_cc_scraper.rb` exists — FOUND
- [x] `test/services/tournament/public_cc_scraper_test.rb` exists — FOUND
- [x] `app/models/tournament.rb` reduced to 575 lines — CONFIRMED
- [x] `grep -c "parse_table_tr|handle_game|variant0|Variant4" app/models/tournament.rb` returns 0 — CONFIRMED
- [x] All 42 tests pass — CONFIRMED
- [x] Commits `029b0baf` and `d40f6842` exist — CONFIRMED
