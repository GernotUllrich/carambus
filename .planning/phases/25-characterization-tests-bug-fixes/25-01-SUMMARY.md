---
phase: 25-characterization-tests-bug-fixes
plan: "01"
subsystem: umb-scrapers
tags: [bug-fix, http-client, ssl, refactoring, tests]
dependency_graph:
  requires: []
  provides: [Umb::HttpClient PORO, SCRP-03 fix, SCRP-04 fix, SCRP-05 fix]
  affects: [app/services/umb_scraper.rb, app/services/umb_scraper_v2.rb, app/services/tournament_discovery_service.rb, app/jobs/scrape_umb_archive_job.rb]
tech_stack:
  added: [Umb::HttpClient PORO]
  patterns: [environment-guarded SSL, polymorphic association assignment, Minitest::Mock kwargs stubbing]
key_files:
  created:
    - app/services/umb/http_client.rb
    - test/services/umb/http_client_test.rb
    - test/services/tournament_discovery_service_test.rb
    - test/jobs/scrape_umb_archive_job_test.rb
  modified:
    - app/services/tournament_discovery_service.rb
    - app/jobs/scrape_umb_archive_job.rb
    - app/services/umb_scraper.rb
    - app/services/umb_scraper_v2.rb
decisions:
  - "ssl_verify_mode exposed as public class method on Umb::HttpClient so scrapers can delegate without instantiation"
  - "UmbScraper fetch_url and download_pdf keep their existing Net::HTTP logic intact — only the SSL line is delegated (full delegation deferred to Phase 26)"
  - "Used Minitest::Mock with keyword args for ScrapeUmbArchiveJob tests instead of any_instance (Mocha not available)"
metrics:
  duration_minutes: 12
  completed_date: "2026-04-12"
  tasks_completed: 3
  tasks_total: 3
  files_created: 4
  files_modified: 4
  test_runs: 920
  test_failures: 0
---

# Phase 25 Plan 01: Umb::HttpClient PORO and Bug Fixes Summary

**One-liner:** Extracted `Umb::HttpClient` PORO with environment-guarded SSL, wired both UMB scrapers to use it, and fixed `TournamentDiscoveryService` polymorphic videoable bug and `ScrapeUmbArchiveJob` kwargs mismatch.

## What Was Built

### Task 1: Umb::HttpClient PORO (SCRP-05 part 1)

Created `app/services/umb/http_client.rb` — a stateless HTTP transport PORO following the `RegionCc::ClubCloudClient` pattern.

Key design:
- `Umb::HttpClient.ssl_verify_mode` is a **public class method** returning `VERIFY_PEER` in production, `VERIFY_NONE` in dev/test
- Instance method `fetch_url` handles redirects, logging, and error rescue
- Does NOT inherit from `ApplicationService` — pure PORO
- 11 unit tests covering SSL modes, HTTP 200/500/404, redirect following, max redirect limit, network errors

### Task 2: Bug Fixes SCRP-03 and SCRP-04

**SCRP-03 — TournamentDiscoveryService:**
Replaced `video.update(international_tournament_id: tournament.id)` (non-existent column) with `video.update(videoable: tournament)` using the existing polymorphic `videoable` association on `Video`. 4 tests cover assignment, counter increment, skip-if-already-assigned, and reassignment.

**SCRP-04 — ScrapeUmbArchiveJob:**
Replaced `perform(discipline:, year:, event_type:)` with `perform(start_id: 1, end_id: 500, batch_size: 50)` matching `UmbScraper#scrape_tournament_archive` signature. 4 tests verify kwargs forwarding, parameter signature, and return value.

### Task 3: Wire SSL delegation to Umb::HttpClient (SCRP-05 completion)

Three targeted replacements:
1. `UmbScraper#fetch_url` line 489: `VERIFY_NONE if Rails.env.development?` → `Umb::HttpClient.ssl_verify_mode`
2. `UmbScraper#download_pdf` line 1567: same replacement
3. `UmbScraperV2#fetch_url` line 65: same replacement

All other Net::HTTP logic (Timeout wrapper, custom headers, redirect handling) left intact — full method delegation is Phase 26 scope.

## Verification Results

- `bin/rails test test/services/umb/http_client_test.rb` — 11/11 green
- `bin/rails test test/services/tournament_discovery_service_test.rb test/jobs/scrape_umb_archive_job_test.rb` — 8/8 green
- `bin/rails test` full suite — 920 runs, 2151 assertions, 0 failures, 0 errors
- `grep "VERIFY_NONE if Rails.env.development?" app/services/umb_scraper.rb app/services/umb_scraper_v2.rb` — 0 matches
- `grep "Umb::HttpClient.ssl_verify_mode" app/services/umb_scraper.rb app/services/umb_scraper_v2.rb` — 3 matches (2 + 1)
- brakeman SSL warnings: 14 total, all pre-existing in non-UMB files (region_cc, etc.), 0 from UMB files

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | cfb99290 | feat(25-01): create Umb::HttpClient PORO with environment-guarded SSL (SCRP-05) |
| 2 | 7be4f6ae | fix(25-01): fix TournamentDiscoveryService videoable bug and ScrapeUmbArchiveJob kwargs (SCRP-03, SCRP-04) |
| 3 | 23b6feb8 | feat(25-01): wire UmbScraper and UmbScraperV2 SSL to Umb::HttpClient.ssl_verify_mode (SCRP-05) |

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

### Deviation: Minitest::Mock instead of any_instance

**Found during:** Task 2 (ScrapeUmbArchiveJob tests)
**Issue:** Plan suggested `UmbScraper.any_instance.stubs(...)` (Mocha syntax) but Mocha is not available in this project — only Minitest with WebMock.
**Fix:** Used `Minitest::Mock` with `UmbScraper.stub(:new, fake_scraper)` pattern. Added `assert_mock` to satisfy Minitest's assertion count requirement.
**Category:** Rule 1 (auto-fix) — test approach adjusted to match available tooling.

## Known Stubs

None — all implementations are complete and functional.

## Threat Surface

The `Umb::HttpClient` PORO is a new network-facing component making outbound HTTPS requests to `files.umb-carom.org`. This is within the plan's declared threat model (T-25-01: environment-guarded SSL with `VERIFY_PEER` in production). No new threat surface beyond what was planned.

## Self-Check: PASSED

- `app/services/umb/http_client.rb` — EXISTS
- `test/services/umb/http_client_test.rb` — EXISTS
- `test/services/tournament_discovery_service_test.rb` — EXISTS
- `test/jobs/scrape_umb_archive_job_test.rb` — EXISTS
- Commits cfb99290, 7be4f6ae, 23b6feb8 — ALL FOUND in git log --all
