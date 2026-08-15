# Phase 26: UmbScraper Service Extraction + V2 Absorption - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract UmbScraper (2133 lines) into `Umb::` namespaced service classes. Absorb UmbScraperV2's PDF parsing (player lists, group results, final rankings) as first-class `Umb::` services. Implement final ranking PDF parsing (previously a stub). Delete `umb_scraper_v2.rb` entirely. Reduce `umb_scraper.rb` to thin delegation wrapper.

</domain>

<decisions>
## Implementation Decisions

### Service Boundaries
- **D-01:** Claude's discretion on whether to use a single `Umb::PdfParser` or split by PDF type (`Umb::PlayerListParser`, `Umb::GroupResultParser`, `Umb::RankingParser`). Pick based on code complexity and coupling during extraction.
- **D-02:** Planned services: PlayerResolver, PdfParser (or split), DetailsScraper, FutureScraper, ArchiveScraper. `Umb::HttpClient` already exists from Phase 25.
- **D-03:** PORO for stateless/pure-algorithm services, ApplicationService for side-effect-heavy services (established project pattern from v1.0-v4.0).

### V2 Deprecation
- **D-04:** Delete `umb_scraper_v2.rb` entirely after absorbing its PDF parsing into `Umb::` services. Also delete its characterization test (`test/characterization/umb_scraper_v2_char_test.rb`). Clean break — V2 has zero production callers.
- **D-05:** Write new tests for the extracted `Umb::` services that cover the same behavior V2's char tests pinned.

### PDF Parsing Scope
- **D-06:** Absorb ALL three PDF types into Phase 26: player lists (working in V2), group results (working in V2), AND final rankings (stub in V2 — implement fully).
- **D-07:** This pulls RANK-01 (ranking PDF extraction) from Future Requirements into Phase 26 scope. UMB ranking PDFs from `files.umb-carom.org/Public/Ranking/` are now in scope.
- **D-08:** PDF parsing is the primary match-level data source for video correlation in Phase 27. The extracted PDF services must produce structured data (player names, rounds, scores) that `Video::TournamentMatcher` can consume.

### Extraction Order
- **D-09:** Claude's discretion on optimal extraction order based on dependency analysis. The planned bottom-up order (HttpClient→PlayerResolver→PdfParser→DetailsScraper→FutureScraper→ArchiveScraper) is a starting point, not a constraint.

### Claude's Discretion
- Service boundary decisions (single vs split PdfParser)
- Extraction order
- How to handle V2's game creation logic (currently in V2's group result parsing)
- Test organization for new Umb:: services

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Extraction source files
- `app/services/umb_scraper.rb` — 2133-line primary scraper; all public methods need thin delegation wrappers
- `app/services/umb_scraper_v2.rb` — 585-line scraper to absorb then delete; PDF parsing logic (lines ~230-510) is the key content
- `app/services/umb/http_client.rb` — Already extracted in Phase 25; reuse for all HTTP operations

### Existing tests (must keep passing)
- `test/characterization/umb_scraper_char_test.rb` — Phase 25 characterization tests for UmbScraper (must pass after extraction)
- `test/characterization/umb_scraper_v2_char_test.rb` — Phase 25 char tests for V2 (delete along with V2)
- `test/services/umb/http_client_test.rb` — Phase 25 HttpClient tests

### Prior extraction patterns
- `app/services/region_cc/club_cloud_client.rb` — Pattern for extracted HTTP client (followed by Phase 25)
- `app/services/league/standings_calculator.rb` — PORO extraction pattern from v4.0
- `app/services/tournament/ranking_calculator.rb` — PORO extraction pattern from v2.1
- `app/services/table_monitor/score_engine.rb` — PORO with lazy accessor pattern from v1.0

### Callers (must remain unchanged)
- `app/jobs/scrape_umb_job.rb` — calls `UmbScraper#scrape_future_tournaments`, `#scrape_tournament_details`
- `app/jobs/scrape_umb_archive_job.rb` — calls `UmbScraper#scrape_tournament_archive`
- `app/controllers/admin/incomplete_records_controller.rb` — calls UmbScraper for admin views

### Phase 24 findings
- `.planning/phases/24-data-source-investigation/24-FINDINGS.md` — SoopLive GO, umbevents/Cuesco NO-GO; UMB refactoring is HTML-scraping-only extraction

### Data models for PDF parsing
- `app/models/international_tournament.rb` — `< Tournament` (STI); target for V2-style saves
- `app/models/international_game.rb` — `< Game` (STI); game records from group result PDFs
- `app/models/video.rb` — polymorphic `videoable`; Phase 27 will use PDF-derived match data for correlation

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Umb::HttpClient` — Already extracted in Phase 25 with `fetch_url` and `ssl_verify_mode`
- `UmbScraperV2#scrape_pdfs_for_tournament` (line ~230) — Entry point for PDF parsing pipeline
- `UmbScraperV2#parse_players_list_pdf` (line ~237) — Player list extraction from PDF
- `UmbScraperV2#parse_group_results_pdf` (line ~291) — Group results + game creation
- `UmbScraper::GAME_TYPE_MAPPINGS` — Round name mappings used across both scrapers
- `pdf-reader` gem — Already in Gemfile, used by V2 for PDF text extraction

### Established Patterns
- Thin delegation wrappers are permanent API (v4.0 Key Decision)
- Each service independently testable with its own test file
- VCR cassettes for HTTP-dependent tests; WebMock stubs for unit tests
- `frozen_string_literal: true` in all Ruby files
- German comments for business logic, English for technical

### Integration Points
- `ScrapeUmbJob`, `ScrapeUmbArchiveJob`, `Admin::IncompleteRecordsController` — all call UmbScraper; wrappers must preserve these interfaces
- `DailyInternationalScrapeJob` — orchestrates daily scraping; future Phase 27 wires video matching here
- `InternationalTournament`, `InternationalGame` models — STI hierarchy that V2 targets

</code_context>

<specifics>
## Specific Ideas

- PDF parsing is the bridge between UMB tournament data and video cross-referencing — `Umb::PdfParser` (or split) must produce structured data consumable by Phase 27's VideoMatcher
- Final ranking PDF parsing is new work (V2 had only a stub) — UMB weekly ranking PDFs from `files.umb-carom.org/Public/Ranking/`
- V2's game creation logic (in group result parsing) creates `InternationalGame` records — this must be preserved in the extracted service
- `Umb::HttpClient.fetch_url` should replace all `fetch_url` / `download_pdf` methods in the extracted services

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 26-umbscraper-service-extraction-v2-absorption*
*Context gathered: 2026-04-12*
