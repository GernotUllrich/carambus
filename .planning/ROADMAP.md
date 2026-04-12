# Roadmap: Carambus API — Model Refactoring & Test Coverage

## Milestones

- ✅ **v1.0 Model Refactoring** - Phases 1-5 (shipped 2026-04-10)
- ✅ **v2.0 Test Suite Audit** - Phases 6-10 (shipped 2026-04-10)
- ✅ **v2.1 Tournament Refactoring** - Phases 11-16 (shipped 2026-04-11)
- ✅ **v3.0 Broadcast Isolation Testing** - Phases 17-19 (shipped 2026-04-11)
- ✅ **v4.0 League & PartyMonitor Refactoring** - Phases 20-23 (shipped 2026-04-12)
- 🚧 **v5.0 UMB Scraper Überarbeitung** - Phases 24-28 (in progress)

## Phases

<details>
<summary>✅ v1.0 Model Refactoring (Phases 1-5) - SHIPPED 2026-04-10</summary>

Phases 1-5 delivered: TableMonitor 3903→1611 lines (4 services), RegionCc 2728→491 lines (10 services), 140 passing tests for all extracted service classes, Reek warnings reduced from 781→306 (TableMonitor) and 460→54 (RegionCc).

</details>

<details>
<summary>✅ v2.0 Test Suite Audit (Phases 6-10) - SHIPPED 2026-04-10</summary>

Phases 6-10 delivered: 72 test files audited, STANDARDS.md + AUDIT-REPORT.md, 10 empty stubs deleted, all VCR cassettes recorded, 475 runs green (0 failures, 0 errors, 11 justified skips), ApiProtectorTestOverride added.

</details>

<details>
<summary>✅ v2.1 Tournament Refactoring (Phases 11-16) - SHIPPED 2026-04-11</summary>

Phases 11-16 delivered: Tournament 1775→575 lines (3 services), TournamentMonitor 499→181 lines (4 services), lib/tournament_monitor_support.rb deleted, 751 runs green.

</details>

<details>
<summary>✅ v3.0 Broadcast Isolation Testing (Phases 17-19) - SHIPPED 2026-04-11</summary>

Phases 17-19 delivered: Capybara/Selenium system test infrastructure, 5 broadcast isolation tests (morph, score:update, table_scores, rapid-fire, 3-session), BROADCAST-GAP-REPORT.md. FIX-01/FIX-02 deferred.

</details>

<details>
<summary>✅ v4.0 League & PartyMonitor Refactoring (Phases 20-23) - SHIPPED 2026-04-12</summary>

Phases 20-23 delivered: League 2221→663 lines (4 services: StandingsCalculator, GamePlanReconstructor, ClubCloudScraper, BbvScraper), PartyMonitor 605→217 lines (2 services: TablePopulator, ResultProcessor), 30 controller + 10 reflex tests, 901 runs green.

</details>

### v5.0 UMB Scraper Überarbeitung (In Progress)

**Milestone Goal:** Investigate better-structured UMB data sources, refactor the 2718-line UMB scraper monolith into `Umb::` namespaced services, and build `Video::TournamentMatcher` to cross-reference videos to UMB tournament records.

- [x] **Phase 24: Data Source Investigation** - Probe Cuesco, SoopLive, and UMB events endpoints; document go/no-go findings (completed 2026-04-12)
- [x] **Phase 25: Characterization Tests & Bug Fixes** - VCR cassettes for all UmbScraper public methods; fix three pre-existing bugs (completed 2026-04-12)
- [ ] **Phase 26: UmbScraper Service Extraction** - Extract six `Umb::` namespaced service classes bottom-up; reduce UmbScraper to thin facade
- [ ] **Phase 27: Video Cross-Referencing** - Build `Video::TournamentMatcher` and `Video::MetadataExtractor`; wire into DailyInternationalScrapeJob

## Phase Details

### Phase 24: Data Source Investigation
**Goal**: Know exactly what structured data each alternative UMB source exposes, and have a written go/no-go decision that gates the refactoring architecture
**Depends on**: Phase 23
**Requirements**: INVEST-01, INVEST-02, INVEST-03, INVEST-04
**Success Criteria** (what must be TRUE):
  1. `umbevents.umb-carom.org/Reports/` endpoints are probed under `Accept: application/json` and the response format is documented (JSON or HTML-only confirmed)
  2. `umb.cuesco.net` network traffic is inspected and any AJAX/JSON endpoints for match data are listed with sample responses
  3. `billiards.sooplive.com/schedule/` pages are inspected and any structured VOD/match data endpoints are documented including `data-seq` attribute behavior
  4. A written findings document exists in `.planning/` covering data availability, completeness vs current UMB scraping, and go/no-go decision for API integration
**Plans:** 2/2 plans complete
Plans:
- [x] 24-01-PLAN.md — Script-based probes for umbevents and SoopLive endpoints
- [x] 24-02-PLAN.md — Cuesco browser inspection + consolidated findings document

### Phase 25: Characterization Tests & Bug Fixes
**Goal**: Every public UmbScraper method has a VCR-backed characterization test, and three pre-existing bugs are fixed before extraction begins
**Depends on**: Phase 24
**Requirements**: SCRP-01, SCRP-02, SCRP-03, SCRP-04, SCRP-05
**Success Criteria** (what must be TRUE):
  1. VCR cassettes exist for all UmbScraper critical paths (future tournaments, archive scan, detail page, PDF parsing) and all characterization tests pass
  2. VCR cassettes exist for all UmbScraperV2 critical paths and all characterization tests pass
  3. `TournamentDiscoveryService` bug is fixed: `video.update(videoable: tournament)` replaces the non-existent `international_tournament_id` column reference, and `DailyInternationalScrapeJob` Steps 4-5 no longer abort
  4. `ScrapeUmbArchiveJob` keyword argument mismatch is fixed: `discipline:`, `year:`, `event_type:` are correctly passed to `UmbScraper#scrape_tournament_archive`
  5. SSL verification is environment-guarded across all scrapers: `VERIFY_NONE` only in development/test; `brakeman` reports no SSL warnings
**Plans:** 3/3 plans complete
Plans:
- [x] 25-01-PLAN.md — Umb::HttpClient PORO + three bug fixes (SCRP-03, SCRP-04, SCRP-05)
- [x] 25-02-PLAN.md — UmbScraper characterization tests with VCR cassettes (SCRP-01)
- [x] 25-03-PLAN.md — UmbScraperV2 characterization tests with VCR cassettes (SCRP-02)

### Phase 26: UmbScraper Service Extraction + V2 Absorption
**Goal**: `app/services/umb/` contains focused service classes extracted from both UmbScraper and UmbScraperV2; V2's PDF parsing is absorbed as `Umb::PdfParser` (first-class service for match-level data); `umb_scraper.rb` is a thin delegation wrapper; `umb_scraper_v2.rb` is deprecated
**Depends on**: Phase 25
**Requirements**: SCRP-06, SCRP-07
**Success Criteria** (what must be TRUE):
  1. `Umb::HttpClient` (PORO) exists with environment-guarded SSL handling, replacing all per-scraper `fetch_url` duplication
  2. `Umb::PlayerResolver`, `Umb::PdfParser`, `Umb::DetailsScraper`, `Umb::FutureScraper`, `Umb::ArchiveScraper` each exist as independently testable service classes in `app/services/umb/`
  3. `Umb::PdfParser` absorbs UmbScraperV2's PDF parsing logic (player lists, group results) as the primary match-level data source for video correlation
  4. `umb_scraper.rb` is reduced to a thin delegation wrapper: all three callers (`ScrapeUmbJob`, `ScrapeUmbArchiveJob`, `Admin::IncompleteRecordsController`) and the `umb:update` rake task are unchanged
  5. `umb_scraper_v2.rb` is deprecated: its unique PDF parsing logic lives in `Umb::PdfParser`; overlapping HTML parsing routes through Phase 26 services
  6. All Phase 25 characterization tests still pass after extraction; `bin/rails test` is green; `brakeman` reports no new warnings
**Plans:** 1/4 plans executed
Plans:
- [ ] 26-01-PLAN.md — Foundation services: HttpClient fetch_pdf_text, PlayerResolver, DisciplineDetector, DateHelpers
- [x] 26-02-PLAN.md — PDF parsers: PlayerListParser, GroupResultParser, RankingParser (RANK-01)
- [ ] 26-03-PLAN.md — HTML scrapers: DetailsScraper, FutureScraper, ArchiveScraper
- [ ] 26-04-PLAN.md — Thin wrapper reduction + V2 deletion + full suite verification
**UI hint**: no

### Phase 27: Video Cross-Referencing
**Goal**: Unassigned video records are automatically linked to `InternationalTournament` records by a confidence-scored matcher; `Video.unassigned.count` measurably decreases after each daily job run
**Depends on**: Phase 26
**Requirements**: VIDEO-01, VIDEO-02, VIDEO-03
**Success Criteria** (what must be TRUE):
  1. `Video::TournamentMatcher` (ApplicationService) assigns unassigned videos to `InternationalTournament` by date range + player name intersection + title similarity; only assigns above 0.75 confidence threshold
  2. `Video::MetadataExtractor` (PORO) extracts tournament type, year, players, round, and discipline from video titles and feeds `Video::TournamentMatcher`
  3. SoopLive VODs are linked to specific game records via `replay_no` from the SoopLive JSON API (Phase 24 pivot from `data-seq` HTML attributes to structured JSON)
  4. Kozoom videos with `eventId` mappings are cross-referenced to `InternationalTournament` records
  5. `DailyInternationalScrapeJob` Step 3 is wired to `Video::TournamentMatcher`; `Video.unassigned.count` decreases after a job run against real fixture data
**Plans:** 0/3 plans executed
Plans:
- [ ] 27-01-PLAN.md — Video::MetadataExtractor + Video::TournamentMatcher (VIDEO-01)
- [ ] 27-02-PLAN.md — SoopliveBilliardsClient + SoopLive VOD linking + Kozoom cross-ref (VIDEO-02, VIDEO-03)
- [ ] 27-03-PLAN.md — Wire into DailyInternationalScrapeJob + rake task backfill

## Progress

**Execution Order:**
Phases execute in numeric order: 24 → 25 → 26 → 27

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-5. Model Refactoring | v1.0 | 18/18 | Complete | 2026-04-10 |
| 6-10. Test Suite Audit | v2.0 | 11/11 | Complete | 2026-04-10 |
| 11-16. Tournament Refactoring | v2.1 | 15/15 | Complete | 2026-04-11 |
| 17-19. Broadcast Isolation | v3.0 | 6/6 | Complete | 2026-04-11 |
| 20-23. League & PartyMonitor | v4.0 | 9/9 | Complete | 2026-04-12 |
| 24. Data Source Investigation | v5.0 | 2/2 | Complete   | 2026-04-12 |
| 25. Characterization Tests & Bug Fixes | v5.0 | 3/3 | Complete   | 2026-04-12 |
| 26. UmbScraper Service Extraction | v5.0 | 1/4 | In Progress|  |
| 27. Video Cross-Referencing | v5.0 | 0/3 | Planned    |  |
