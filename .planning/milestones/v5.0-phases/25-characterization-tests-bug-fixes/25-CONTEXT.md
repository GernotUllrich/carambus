# Phase 25: Characterization Tests & Bug Fixes - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Write VCR-backed characterization tests for all UmbScraper and UmbScraperV2 public methods. Fix three pre-existing bugs: TournamentDiscoveryService column reference, ScrapeUmbArchiveJob keyword arguments, SSL verification inconsistency. Extract `Umb::HttpClient` early as shared SSL helper.

</domain>

<decisions>
## Implementation Decisions

### Test Organization
- **D-01:** Claude's discretion on file organization — may use one file per scraper or split by concern depending on method count and complexity. Follow the pattern that best fits the UMB scraper's public API surface.

### VCR Cassette Strategy
- **D-02:** Hybrid approach — record VCR cassettes against live UMB site where endpoints work (tournament details pages, future tournaments list), use crafted fixture HTML files for endpoints that returned HTTP 500 during Phase 24 probing (e.g., `/Reports/` paths).
- **D-03:** Cassette directory: `test/snapshots/vcr/umb/` following the established `test/snapshots/vcr/region_cc_*.yml` pattern.

### Bug Fix Ordering
- **D-04:** Interleave bugs and tests — write characterization tests for UmbScraper, fix bugs that block test setup as they arise, then write remaining tests. Don't force all bugs first or all tests first.
- **D-05:** The three bugs to fix are:
  1. `TournamentDiscoveryService` references non-existent `video.international_tournament_id` column — should use `video.update(videoable: tournament)` via polymorphic association
  2. `ScrapeUmbArchiveJob` passes `discipline:, year:, event_type:` but `scrape_tournament_archive` expects `start_id:, end_id:, batch_size:` — kwargs mismatch
  3. SSL verification inconsistency across scrapers — resolved via Umb::HttpClient (D-06)

### SSL Fix Scope
- **D-06:** Extract `Umb::HttpClient` early (pulled forward from Phase 26 plan) as the single place for SSL configuration. Environment-guarded: `VERIFY_NONE` only in development/test, proper verification in production. Other scrapers (Kozoom, SoopLive) adopt the shared helper in their own refactoring phases — do NOT modify them in Phase 25.
- **D-07:** `Umb::HttpClient` is a PORO (not ApplicationService) — stateless HTTP helper with `fetch_url` method, matching the Phase 26 architecture plan.

### Claude's Discretion
- Test file naming and organization within the established conventions
- Which UmbScraper methods are "critical paths" worth characterizing vs low-value
- VCR cassette recording strategy per endpoint (live vs fixture)
- Order of interleaving between tests and bug fixes

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scraper source files (characterization targets)
- `app/services/umb_scraper.rb` — 2133-line scraper; all public methods need characterization tests
- `app/services/umb_scraper_v2.rb` — 585-line scraper; all public methods need characterization tests

### Bug fix targets
- `app/services/tournament_discovery_service.rb` — SCRP-03: non-existent `international_tournament_id` column reference
- `app/jobs/scrape_umb_archive_job.rb` — SCRP-04: kwargs mismatch with `scrape_tournament_archive`
- `app/services/kozoom_scraper.rb` — SCRP-05: reference for unconditional `VERIFY_NONE` pattern to avoid

### Existing test patterns
- `test/services/region_cc_char_test.rb` — Established characterization test pattern with VCR cassettes
- `test/snapshots/vcr/` — VCR cassette directory structure
- `test/support/scraping_helpers.rb` — Scraping test helpers
- `test/support/snapshot_helpers.rb` — VCR/snapshot test helpers

### Phase 24 findings (investigation results)
- `.planning/phases/24-data-source-investigation/24-FINDINGS.md` — Go/no-go decisions: SoopLive GO, umbevents and Cuesco NO-GO

### Data models
- `app/models/video.rb` — Polymorphic `videoable` association (correct pattern for SCRP-03 fix)
- `app/models/international_tournament.rb` — Target model for scraper output

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/support/scraping_helpers.rb` — Established helpers for scraping tests
- `test/support/snapshot_helpers.rb` — VCR cassette setup/teardown helpers
- `RegionCc::ClubCloudClient` — Pattern for extracted HTTP client (Phase 26 Umb::HttpClient follows this)
- `UmbScraperV2#fetch_url` (lines 57-91) — Existing HTTP fetch pattern to extract into Umb::HttpClient

### Established Patterns
- `frozen_string_literal: true` in all Ruby files
- Fixtures primary, not FactoryBot
- VCR cassettes in `test/snapshots/vcr/`
- Characterization tests pin existing behavior before extraction (v1.0-v4.0 established pattern)
- PORO for stateless helpers, ApplicationService for side effects

### Integration Points
- `ScrapeUmbJob` — calls `UmbScraper#scrape_future_tournaments` and `#scrape_tournament_details`
- `ScrapeUmbArchiveJob` — calls `UmbScraper#scrape_tournament_archive` (currently with wrong kwargs)
- `Admin::IncompleteRecordsController` — calls UmbScraper for admin views
- `DailyInternationalScrapeJob` — calls `TournamentDiscoveryService#assign_videos_to_tournament` (currently broken)

</code_context>

<specifics>
## Specific Ideas

- Umb::HttpClient pulled forward from Phase 26 — this is deliberate scope overlap to get the SSL fix right early. Phase 26 will reuse this class, not recreate it.
- The interleave approach means the plan should NOT have a rigid "all tests then all fixes" structure — bugs get fixed when they naturally block test writing.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 25-characterization-tests-bug-fixes*
*Context gathered: 2026-04-12*
