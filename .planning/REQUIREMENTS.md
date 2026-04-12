# Requirements: Carambus API v5.0

**Defined:** 2026-04-12
**Core Value:** A maintainable, well-tested codebase where every test is trustworthy and every model is appropriately sized.

## v5.0 Requirements

Requirements for UMB Scraper Überarbeitung. Each maps to roadmap phases.

### Data Source Investigation

- [ ] **INVEST-01**: Probe `umbevents.umb-carom.org/Reports/` endpoints for JSON responses under different Accept headers
- [ ] **INVEST-02**: Inspect `umb.cuesco.net` network traffic to discover AJAX/JSON endpoints for match data
- [ ] **INVEST-03**: Inspect `billiards.sooplive.com/schedule/` pages to discover structured VOD/match data endpoints
- [ ] **INVEST-04**: Document findings: what data is available from each source, completeness vs current UMB scraping, go/no-go on API integration

### Scraper Refactoring

- [ ] **SCRP-01**: Characterization tests for UmbScraper critical paths (future tournaments, archive scan, detail page, PDF parsing) with VCR cassettes
- [ ] **SCRP-02**: Characterization tests for UmbScraperV2 critical paths with VCR cassettes
- [ ] **SCRP-03**: Fix pre-existing bug: `TournamentDiscoveryService` references non-existent `video.international_tournament_id` column
- [ ] **SCRP-04**: Fix pre-existing bug: `ScrapeUmbArchiveJob` passes wrong keyword arguments to `scrape_tournament_archive`
- [ ] **SCRP-05**: Fix SSL verification inconsistency across scrapers
- [ ] **SCRP-06**: Extract UmbScraper into `Umb::` namespaced services (HttpClient, PlayerResolver, PdfParser, DetailsScraper, FutureScraper, ArchiveScraper)
- [ ] **SCRP-07**: Merge UmbScraperV2 overlapping logic into unified `Umb::` services, reduce V2 to thin facade or deprecate

### Video Cross-Referencing

- [ ] **VIDEO-01**: `Video::TournamentMatcher` service assigns unassigned videos to `InternationalTournament` by date range + player name intersection + title similarity
- [ ] **VIDEO-02**: SoopLive VOD linking via `replay_no` from SoopLive JSON API to specific game records
- [ ] **VIDEO-03**: Kozoom event cross-referencing via existing `eventId` mapping to `InternationalTournament`

## Future Requirements

Deferred to future release. Tracked but not in current roadmap.

### Rankings

- **RANK-01**: Ranking PDF extraction from `files.umb-carom.org/Public/Ranking/`

### AI Enhancement

- **AI-01**: AI-assisted title parsing for non-English unmatched videos

### Archive

- **ARCH-01**: UMB archive backfill via comprehensive sequential ID scan

## Out of Scope

| Feature | Reason |
|---------|--------|
| Selenium/browser automation for scraping | Nokogiri sufficient; AJAX endpoint investigation preferred over browser deps |
| Real-time video matching during scrape | Fragile coupling; batch matching after both records exist is more reliable |
| Bulk video title translation | OpenAI API cost at scale; on-demand translation already exists via `Video#translated_title` |
| Auto-hiding irrelevant videos | Behavioral change, not data quality — separate feature |
| Commercial sports data API | No provider covers UMB carom billiards |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INVEST-01 | Phase 24 | Pending |
| INVEST-02 | Phase 24 | Pending |
| INVEST-03 | Phase 24 | Pending |
| INVEST-04 | Phase 24 | Pending |
| SCRP-01 | Phase 25 | Pending |
| SCRP-02 | Phase 25 | Pending |
| SCRP-03 | Phase 25 | Pending |
| SCRP-04 | Phase 25 | Pending |
| SCRP-05 | Phase 25 | Pending |
| SCRP-06 | Phase 26 | Pending |
| SCRP-07 | Phase 26 | Pending |
| VIDEO-01 | Phase 27 | Pending |
| VIDEO-02 | Phase 27 | Pending |
| VIDEO-03 | Phase 27 | Pending |

**Coverage:**
- v5.0 requirements: 14 total
- Mapped to phases: 14
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-12*
*Last updated: 2026-04-12 after roadmap creation*
