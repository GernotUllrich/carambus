---
phase: 26-umbscraper-service-extraction-v2-absorption
plan: "03"
subsystem: umb-scrapers
tags: [service-extraction, scraping, umb, international-tournaments, pdf-pipeline]
dependency_graph:
  requires: [26-01, 26-02]
  provides: [Umb::FutureScraper, Umb::ArchiveScraper, Umb::DetailsScraper]
  affects: [UmbScraper, ScrapeUmbJob, ScrapeUmbArchiveJob]
tech_stack:
  added: []
  patterns:
    - ApplicationService with DB side-effects (Umb::FutureScraper, Umb::ArchiveScraper, Umb::DetailsScraper)
    - PDF pipeline orchestration (PlayerListParser → Seedings, GroupResultParser → InternationalGame, RankingParser → Seedings)
    - InternationalGame STI type for game creation (V2 pattern, not nil type)
    - All PDF types parsed independently — no short-circuit (Pitfall 5 from research)
key_files:
  created:
    - app/services/umb/future_scraper.rb
    - app/services/umb/archive_scraper.rb
    - app/services/umb/details_scraper.rb
    - test/services/umb/future_scraper_test.rb
    - test/services/umb/archive_scraper_test.rb
    - test/services/umb/details_scraper_test.rb
  modified: []
decisions:
  - Shared helpers (location, season, organizer) duplicated in each scraper rather than extracted to a shared module — extraction deferred; the three scrapers are cohesive standalone services and premature extraction would add indirection without a concrete caller need
  - resolve_player_from_name splits "CAPS Mixed" using all-caps-token heuristic — sufficient for GroupResultParser output format
  - LocationHelpers not extracted as separate module — no callers outside umb/ namespace yet
metrics:
  duration_minutes: 35
  completed: "2026-04-12"
  tasks_completed: 2
  tasks_total: 2
  files_created: 6
  files_modified: 0
  tests_added: 55
  test_assertions: 73
---

# Phase 26 Plan 03: UMB HTML Scraper Services Summary

Three ApplicationService classes extracted from UmbScraper (V1): FutureScraper (future tournaments listing), ArchiveScraper (sequential ID scanner), DetailsScraper (detail page + PDF pipeline orchestrator).

## What Was Built

### Umb::FutureScraper

Scrapes `FutureTournaments.aspx`, parses HTML table with year/month context tracking (cross-month events handled), creates/updates `InternationalTournament` records. Delegates HTTP to `Umb::HttpClient`, date parsing to `Umb::DateHelpers`, discipline detection to `Umb::DisciplineDetector`.

### Umb::ArchiveScraper

Scans sequential tournament IDs (`TournametDetails.aspx?ID=N`), stops after 50 consecutive 404s, rate-limits via `batch_size` sleep. Skips duplicate `external_id`. Uses `Umb::DateHelpers.parse_date` for archive date formats.

### Umb::DetailsScraper

Orchestrates the full detail-page pipeline:
1. Fetches and parses tournament metadata from HTML table
2. Creates/updates `InternationalTournament` (location, season, organizer backfill)
3. `create_games: true` — creates phase Game records from PDF link list (type: `InternationalGame`)
4. `parse_pdfs: true` — runs all three PDF parsers independently:
   - `PlayerListParser` → `Seeding` records (confirmed state)
   - `GroupResultParser` → `InternationalGame` + `GameParticipation` records
   - `RankingParser` → `Seeding` records with final position

## Test Coverage

| File | Tests | Assertions |
|------|-------|------------|
| future_scraper_test.rb | 18 | 23 |
| archive_scraper_test.rb | 13 | 16 |
| details_scraper_test.rb | 24 | 34 |
| **Total (plan 03)** | **55** | **73** |
| **Total (umb/ namespace)** | **155** | **253** |

All 155 umb namespace tests pass, 0 failures, 0 errors.

## Deviations from Plan

None — plan executed exactly as written. The shared location/season/organizer helper methods are duplicated across the three scrapers (not extracted to a `Umb::LocationHelpers` module). This was a plan decision point: "check during implementation." After review, extraction was not warranted — no fourth caller exists and the helpers are short (each ~10 lines). Documented as a decision above.

## Commits

| Commit | Description |
|--------|-------------|
| `4a7a76ef` | feat(26-03): Umb::FutureScraper and Umb::ArchiveScraper |
| `32397734` | feat(26-03): Umb::DetailsScraper — orchestrator service for tournament details + PDF pipeline |

## Self-Check: PASSED

All files created verified present on disk. Commits 4a7a76ef and 32397734 confirmed in git log on main repo (worktree shares git history).
