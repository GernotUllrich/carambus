---
phase: 26-umbscraper-service-extraction-v2-absorption
plan: "04"
subsystem: umb-scraping
tags: [refactoring, delegation, cleanup, deletion]
dependency_graph:
  requires: [26-03]
  provides: [thin-umb-facade, v2-deleted]
  affects: [ScrapeUmbJob, ScrapeUmbArchiveJob, Admin::IncompleteRecordsController, umb.rake, umb_update.rake]
tech_stack:
  added: []
  patterns: [thin-delegation-wrapper, private-send-compatibility]
key_files:
  created: []
  modified:
    - app/services/umb_scraper.rb
  deleted:
    - app/services/umb_scraper_v2.rb
    - lib/tasks/umb_v2.rake
    - test/characterization/umb_scraper_v2_char_test.rb
decisions:
  - detect_discipline_from_name returns Integer IDs to preserve Phase-25 char test contract
  - find_discipline_from_name returns Discipline objects for admin controller update() call
  - fetch_tournament_basic_data and save_tournament_from_details kept as private methods for rake .send() compatibility
  - find_or_create_umb_organizer kept as private method for rake .send() compatibility
  - scrape_rankings now delegates to Umb::HttpClient + Umb::PdfParser::RankingParser (no longer a stub)
metrics:
  duration_minutes: 35
  completed_date: "2026-04-12"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 1
  files_deleted: 3
  line_reduction: "2133 → 175 lines (91.8%)"
---

# Phase 26 Plan 04: UmbScraper Thin Wrapper + V2 Deletion Summary

UmbScraper reduced from 2133 lines to a 175-line thin delegation wrapper; UmbScraperV2 and all V2 artifacts fully deleted.

## What Was Done

### Task 1: Reduce UmbScraper to thin delegation wrapper

Rewrote `app/services/umb_scraper.rb` from 2133 lines to 175 lines. All business logic now lives in `Umb::` namespace services (Plans 01-03). The wrapper:

- `scrape_future_tournaments` → `Umb::FutureScraper.new.call`
- `scrape_tournament_archive` → `Umb::ArchiveScraper.new.call`
- `scrape_tournament_details` → `Umb::DetailsScraper.new.call`
- `scrape_rankings` → `Umb::HttpClient` + `Umb::PdfParser::RankingParser` (no longer a stub)
- `detect_discipline_from_name` → returns Integer IDs (Phase-25 char test compatibility)
- `find_discipline_from_name` → `Umb::DisciplineDetector.detect` (public, for admin controller `.send()`)
- Private methods `fetch_tournament_basic_data`, `save_tournament_from_details`, `find_or_create_umb_organizer` preserved for rake task `.send()` compatibility

All 3 callers (ScrapeUmbJob, ScrapeUmbArchiveJob, Admin::IncompleteRecordsController) work unchanged.

### Task 2: Delete V2 + rake + V2 char test

Deleted:
- `app/services/umb_scraper_v2.rb` (585 lines) — fully absorbed into Umb:: services
- `lib/tasks/umb_v2.rake` (108 lines) — dev-only tooling, no production callers
- `test/characterization/umb_scraper_v2_char_test.rb` — per D-04

Zero remaining references to `UmbScraperV2` in the codebase (one comment in `http_client.rb` mentions it in documentation only).

Full test suite: 1077 runs, 2412 assertions, 0 failures, 0 errors, 13 skips.

## Acceptance Criteria Results

| Criterion | Result |
|-----------|--------|
| `wc -l app/services/umb_scraper.rb` < 200 | 175 lines |
| `Umb::FutureScraper` referenced | 1 occurrence |
| `Umb::ArchiveScraper` referenced | 1 occurrence |
| `Umb::DetailsScraper` referenced | 3 occurrences |
| `Umb::DisciplineDetector` referenced | 1 occurrence |
| `def find_discipline_from_name` is public | Present |
| `fetch_tournament_basic_data`/`save_tournament_from_details` NOT public | Private only |
| `test -f app/services/umb_scraper_v2.rb` | DELETED |
| `test -f lib/tasks/umb_v2.rake` | DELETED |
| `test -f test/characterization/umb_scraper_v2_char_test.rb` | DELETED |
| `grep -rn "UmbScraperV2" ...` | 0 matches |
| `bin/rails test` | 1077 runs, 0 failures, 0 errors |
| `find app/services/umb/ -name "*.rb"` | 10 files |
| `bundle exec standardrb --no-fix app/services/umb_scraper.rb` | Exit 0 |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] detect_discipline_from_name return type mismatch with Phase-25 char tests**

- **Found during:** Task 1 — running characterization tests
- **Issue:** `Umb::DisciplineDetector.detect` returns a `Discipline` object, but Phase-25 char tests expect Integer discipline IDs. The old code returned `Discipline.find_by(name: "...")&.id || FALLBACK_INT`.
- **Fix:** `detect_discipline_from_name` keeps the original integer-returning logic directly in the wrapper (exact name lookups with hardcoded global ID fallbacks). `find_discipline_from_name` delegates to `DisciplineDetector` and returns Discipline objects (for admin controller `tournament.update(discipline: obj)` calls).
- **Files modified:** `app/services/umb_scraper.rb`
- **Commit:** 993d2814

**2. [Rule 3 - Blocking] Worktree missing config/database.yml and config/carambus.yml**

- **Found during:** Task 1 — test run failed with "Cannot load database configuration"
- **Issue:** These files are gitignored but required for tests. The git worktree doesn't inherit them from the main repo checkout.
- **Fix:** Copied both files from main repo (`/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/config/`) into the worktree config directory.
- **Files modified:** `config/database.yml`, `config/carambus.yml` (worktree-only, gitignored)

### Known Pre-existing Issues (Out of Scope)

- `brakeman` segfaults with prism parser (Ruby 3.2.1 + prism 1.6.0 incompatibility). Reproducible in both main repo and worktree. No new warnings introduced.
- `VALID_TOURNAMENT_IDS` constant warning during test runs — pre-existing issue in `lib/tasks/umb.rake` loaded twice by test environment.

## Commits

| Hash | Message |
|------|---------|
| 993d2814 | feat(26-04): reduce UmbScraper to thin delegation wrapper |
| d239e9b1 | feat(26-04): delete UmbScraperV2, umb_v2.rake, V2 char test (D-04) |

## Known Stubs

None — `scrape_rankings` is no longer a stub. It delegates to `Umb::HttpClient#fetch_pdf_text` and `Umb::PdfParser::RankingParser#parse`. In test environments where the PDF URL is unreachable (WebMock blocks external HTTP), it returns `0` gracefully via the rescue clause.

## Threat Flags

None. The wrapper introduces no new network endpoints, auth paths, or file access patterns. The only change is reducing code surface area.

## Self-Check

- [x] `app/services/umb_scraper.rb` exists (175 lines)
- [x] `app/services/umb_scraper_v2.rb` deleted
- [x] `lib/tasks/umb_v2.rake` deleted
- [x] `test/characterization/umb_scraper_v2_char_test.rb` deleted
- [x] Commits 993d2814 and d239e9b1 exist
- [x] Full test suite: 1077 runs, 0 failures, 0 errors

## Self-Check: PASSED
