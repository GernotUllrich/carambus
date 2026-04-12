# Carambus API — Model Refactoring & Test Coverage

## What This Is

A focused improvement effort on the Carambus API codebase. v1.0–v5.0 broke down all large models/services (37 extracted services), audited tests, verified broadcast isolation, refactored scrapers, and built video cross-referencing. v6.0 ensures the mkdocs-based documentation accurately reflects the post-refactoring codebase.

## Core Value

A maintainable, well-tested codebase where every test is trustworthy and every model is appropriately sized.

## Current Milestone: v6.0 Documentation Quality

**Goal:** Ensure mkdocs-based documentation accurately reflects the post-refactoring codebase — every implemented feature documented, no references to unimplemented or deleted features, documentation quality on par with code quality.

**Target features:**
- Audit existing docs against actual codebase state
- Remove/update references to deleted code (UmbScraperV2, old model structures)
- Document new services and features from v1.0–v5.0
- Verify multilingual consistency (de/en)


## Requirements

### Validated

- ✓ Existing TableMonitor functionality preserved — v1.0
- ✓ Existing RegionCc functionality preserved — v1.0
- ✓ Existing test suite passes — v1.0
- ✓ Characterization tests for TableMonitor critical paths — v1.0 (58 tests)
- ✓ Characterization tests for RegionCc critical paths — v1.0 (56 tests)
- ✓ Extract service classes from TableMonitor — v1.0 (ScoreEngine, GameSetup, OptionsPresenter, ResultRecorder)
- ✓ Extract service classes from RegionCc — v1.0 (ClubCloudClient + 9 syncers)
- ✓ Tests for all extracted service classes — v1.0 (140 tests total)
- ✓ RegionCc reduced to 491 lines — v1.0
- ✓ TableMonitor reduced to 1611 lines — v1.0
- ✓ Reek quality improvement measured — v1.0 (TableMonitor 781→306, RegionCc 460→54)
- ✓ Every test file reviewed for quality issues — v2.0 (72 files audited, STANDARDS.md + AUDIT-REPORT.md)
- ✓ All skipped/pending tests resolved — v2.0 (VCR cassettes recorded, skips justified or fixed)
- ✓ Consistent patterns established — v2.0 (frozen_string_literal, fixtures-first, test naming)
- ✓ Dead/redundant tests removed — v2.0 (10 empty stubs + 1 non-test script deleted)
- ✓ All tests green after improvements — v2.0 (475 runs, 0 failures, 0 errors, 11 justified skips)
- ✓ Tournament characterization tests (AASM, scraping, attributes, PaperTrail, calendar) — v2.1 (85 tests)
- ✓ TournamentMonitor characterization tests (T04, T06, KO) — v2.1 (47 tests)
- ✓ Tournament reduced to 575 lines — v2.1 (3 services: RankingCalculator, TableReservationService, PublicCcScraper)
- ✓ TournamentMonitor reduced to 181 lines — v2.1 (4 services: PlayerGroupDistributor, RankingResolver, ResultProcessor, TablePopulator)
- ✓ lib/tournament_monitor_support.rb deleted — v2.1 (all methods extracted to services)
- ✓ Controller/channel/job test coverage — v2.1 (74 tests: TournamentsController, TournamentMonitorsController, channels, jobs)
- ✓ All tests green — v2.1 (751 runs, 0 failures, 0 errors)
- ✓ PaperTrail version baselines unchanged — v2.1 (sync contract preserved)
- ✓ Capybara/Selenium system test infrastructure — v3.0 (async adapter, local_server? override, multi-session helpers, smoke test)
- ✓ Multi-scoreboard broadcast isolation tests — v3.0 (morph path, score:update dispatch, table_scores overview, console.warn filter proof)
- ✓ Concurrent/load broadcast isolation — v3.0 (rapid-fire 6-iteration loop, 3-session all-pairs, 0 failures)
- ✓ Broadcast gap report — v3.0 (all 11 requirements PASS, FIX-01/FIX-02 deferred)
- ✓ Characterization tests for League critical paths — v4.0 (25 tests: standings, game plan, scraping)
- ✓ Characterization tests for PartyMonitor critical paths — v4.0 (40 tests: AASM, placement, result pipeline)
- ✓ Extract service classes from League — v4.0 (4 services: StandingsCalculator, GamePlanReconstructor, ClubCloudScraper, BbvScraper; 2221→663 lines, 70.2% reduction)
- ✓ Extract service classes from PartyMonitor — v4.0 (2 services: TablePopulator, ResultProcessor; 605→217 lines, 64% reduction)
- ✓ Controller/channel/job test coverage for League/Party/PartyMonitor — v4.0 (30 controller + 10 reflex tests, COV-02 documented, 901 runs green)
- ✓ Alternative UMB data sources investigated — v5.0 (SoopLive JSON API GO, umbevents/Cuesco NO-GO)
- ✓ UmbScraper reduced to 175 lines — v5.0 (10 Umb:: services: HttpClient, DisciplineDetector, DateHelpers, PlayerResolver, PlayerListParser, GroupResultParser, RankingParser, FutureScraper, ArchiveScraper, DetailsScraper)
- ✓ UmbScraperV2 deleted — v5.0 (585 lines absorbed into Umb::PdfParser::* services)
- ✓ 3 pre-existing bugs fixed — v5.0 (TournamentDiscoveryService column, ScrapeUmbArchiveJob kwargs, SSL inconsistency)
- ✓ UMB ranking PDF parsing implemented — v5.0 (RANK-01: weekly + final rankings via Umb::PdfParser::RankingParser)
- ✓ Video cross-referencing system — v5.0 (Video::TournamentMatcher + Video::MetadataExtractor + SoopliveBilliardsClient)
- ✓ SoopLive VOD linking via replay_no — v5.0 (VIDEO-02)
- ✓ Kozoom event cross-referencing via eventId — v5.0 (VIDEO-03)
- ✓ DailyInternationalScrapeJob Steps 3a/3b/3c wired — v5.0 (incremental matching + backfill rake task)

### Active

- [ ] Audit docs against codebase — identify stale, missing, and incorrect documentation
- [ ] Update/remove references to deleted or refactored code
- [ ] Document new features and services from v1.0–v5.0
- [ ] Verify multilingual consistency (de/en)

### Out of Scope

- New test coverage for remaining untested models, controllers, services — separate milestone
- Architecture or stack changes — not in scope for current project
- Scraper consolidation (UmbScraper v1/v2) — completed in v5.0, no longer relevant

## Context

- Brownfield Rails 7.2 app for carom billiard tournament management
- Ruby 3.2.1, PostgreSQL, Redis, ActionCable, StimulusReflex
- **v1.0 shipped 2026-04-10:** TableMonitor 3903→1611 lines (4 services), RegionCc 2728→491 lines (10 services)
- **v2.0 shipped 2026-04-10:** 72 test files audited, 475 runs green, 1121 assertions, ApiProtectorTestOverride added
- **v2.1 shipped 2026-04-11:** Tournament 1775→575 lines (3 services), TournamentMonitor 499→181 lines (4 services), lib/tournament_monitor_support.rb deleted
- **v4.0 shipped 2026-04-12:** League 2221→663 lines (4 services), PartyMonitor 605→217 lines (2 services), 30 controller + 10 reflex tests
- **v5.0 shipped 2026-04-12:** UmbScraper 2133→175 lines (10 services), UmbScraperV2 deleted (585 lines absorbed), SoopLive JSON API integrated, video cross-referencing built
- Test suite: 1130 runs, 0 failures, 0 errors
- Sync: PaperTrail + RegionTaggable filtering, local servers pull via Version.update_from_carambus_api
- ApiProtector + LocalProtector both have test overrides in test_helper.rb
- Extracted services (37 total): ScoreEngine, GameSetup, OptionsPresenter, ResultRecorder, ClubCloudClient + 9 syncers (v1.0), RankingCalculator, TableReservationService, PublicCcScraper, PlayerGroupDistributor, RankingResolver, ResultProcessor, TablePopulator (v2.1), League::StandingsCalculator, League::GamePlanReconstructor, League::ClubCloudScraper, League::BbvScraper, PartyMonitor::TablePopulator, PartyMonitor::ResultProcessor (v4.0), Umb::HttpClient, Umb::DisciplineDetector, Umb::DateHelpers, Umb::PlayerResolver, Umb::PdfParser::PlayerListParser, Umb::PdfParser::GroupResultParser, Umb::PdfParser::RankingParser, Umb::FutureScraper, Umb::ArchiveScraper, Umb::DetailsScraper (v5.0)
- Video services (v5.0): Video::MetadataExtractor, Video::TournamentMatcher, SoopliveBilliardsClient
- Codebase map available at `.planning/codebase/`
- **v3.0 shipped 2026-04-11:** Capybara/Selenium system test infrastructure, 5 broadcast isolation tests (morph, score:update, table_scores, rapid-fire, 3-session), BROADCAST-GAP-REPORT.md documenting all results + deferred FIX-01/FIX-02
- Broadcast isolation: client-side JS filtering on global `table-monitor-stream` verified correct; server-side targeted broadcasts deferred (FIX-01/FIX-02)

## Constraints

- **Behavior preservation**: All existing functionality must continue to work identically
- **Incremental**: Each change must be independently deployable
- **Test-first**: Tests before any refactoring

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Start with TableMonitor and RegionCc only | Worst offenders by line count (3900 and 2700 lines) | ✓ Good — both reduced significantly |
| Write characterization tests before extracting | Ensures refactoring doesn't break existing behavior | ✓ Good — 58 char tests caught every regression |
| Extract to service classes, not concerns | Services are more testable and explicit than concerns | ✓ Good — 14 services extracted with clear boundaries |
| ScoreEngine as PORO, not ApplicationService | Stateful hash wrapper called many times per game | ✓ Good — lazy accessor pattern reused by OptionsPresenter |
| Fine-grained RegionCc syncers (9 classes) | User chose focused services over 3 large ones | ✓ Good — each syncer independently testable |
| suppress_broadcast replacing skip_update_callbacks | Explicit flag with no leaked state | ✓ Good — 79 call sites migrated cleanly |
| Fixtures primary, not FactoryBot | Already dominant, no factory definitions existed | ✓ Good — zero FactoryBot usage confirmed by audit |
| Delete empty test stubs rather than backfill | False confidence worse than no test file | ✓ Good — 10 stubs removed cleanly |
| Fix sole-assertion cases only | Precondition checks (followed by stronger assertions) are acceptable | ✓ Good — targeted fixes, no over-correction |
| ApiProtectorTestOverride in test_helper.rb | Prevents silent save rollbacks in API server context tests | ✓ Good — resolved hidden test failures |
| Production fixture plans for T04/T06 tests | Real executor_params JSON, not programmatic generation | ✓ Good — pins real-world plan structure |
| Test files by plan type (T04/T06/KO) not by concern | Each file covers all paths for one tournament format | ✓ Good — focused, readable test files |
| PORO for pure algorithms, ApplicationService for side effects | PlayerGroupDistributor/RankingResolver/RankingCalculator as POROs, PublicCcScraper/TableReservationService as ApplicationService | ✓ Good — consistent pattern |
| Services in app/services/tournament/ and tournament_monitor/ | Follows existing table_monitor/ pattern from v1.0 | ✓ Good — clean namespace separation |
| DB lock stays inside ResultProcessor service | Pessimistic lock is result processing logic, not model infrastructure | ✓ Good — lock behavior preserved exactly |
| AASM events fired on @tournament_monitor from services | After_enter callbacks execute correctly through model reference | ✓ Good — no AASM coupling leaks |
| Delete lib/tournament_monitor_support.rb after extraction | File empty after all methods moved to services | ✓ Good — eliminated 1078-line legacy module |
| Global async cable adapter for system tests | Simpler than per-test override; ActionCable::TestHelper swaps adapter for channel unit tests | ✓ Good — zero channel test regressions |
| local_server? via ApplicationSystemTestCase setup/teardown | Global carambus.yml change would break 50+ tests; scoped override safer | ✓ Good — established pattern, zero regressions |
| DOM marker for console.warn capture (not Selenium logs API) | More portable across ChromeDriver versions | ✓ Good — reliable filter proof |
| Verify-only milestone (no broadcast fix) | Document gaps, defer FIX-01/FIX-02 to future milestone | ✓ Good — clean separation of concerns |
| League:: namespace for extracted services | Matches Tournament::, TournamentMonitor::, TableMonitor:: patterns | ✓ Good — consistent namespace hierarchy |
| PORO for standings, ApplicationService for scraping | Pure calculation vs side-effect-heavy operations | ✓ Good — StandingsCalculator PORO, scrapers as ApplicationService |
| PartyMonitor PORO matching TournamentMonitor | Direct analog — same AASM-driven extraction pattern | ✓ Good — TablePopulator + ResultProcessor mirror TournamentMonitor services |
| Pessimistic lock stays in model for PartyMonitor | Lock boundary and AASM events are model responsibilities | ✓ Good — services do data work only, model owns state |
| Thin delegation wrappers (permanent API) | Zero caller changes, wrappers are permanent not transitional | ✓ Good — all controllers/reflexes/jobs unmodified |
| Fix fixtures before controller tests | Party fixture chain broken (party_id → nonexistent party) | ✓ Good — unblocked 4 skipped tests immediately |
| Research-first for UMB data sources | Complexity may be inherent to data source, not just code | ✓ Good — discovered SoopLive JSON API, avoided wasted effort on umbevents/Cuesco |
| Umb:: namespace for all extracted services | Consistent with League::, Tournament::, etc. | ✓ Good — 10 services in clean namespace |
| Delete UmbScraperV2 entirely (not facade) | Zero production callers; only PDF parsing was valuable | ✓ Good — clean break, PDF logic in first-class Umb::PdfParser::* POROs |
| Pull Umb::HttpClient into Phase 25 (early) | SSL fix needed before extraction; reused in Phase 26 | ✓ Good — single SSL config point from the start |
| Split PdfParser by type (3 classes) | Player lists, group results, rankings have distinct formats | ✓ Good — independently testable, clean D-08 output contracts |
| Merge Phase 27 (V2 Resolution) into Phase 26 | V2 unused; PDF parsing is V2's only value | ✓ Good — eliminated unnecessary phase, tighter milestone |
| SoopLive replay_no over data-seq HTML | JSON API provides same data structured; no HTML scraping needed | ✓ Good — higher precision, simpler implementation |
| Regex-first + AI fallback for MetadataExtractor | Most titles have known patterns; AI only for outliers | ✓ Good — avoids API cost for majority of videos |
| Confidence scoring with 0.75 threshold | Auto-assign above threshold; below requires review | ✓ Good — measurable, tunable |
| Both backfill + incremental for video matching | Rake task for existing backlog, daily job for new videos | ✓ Good — enables measuring match rate before automation |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-13 after Phase 29 (Break-Fix) complete — zero broken links, zero stale code refs in active docs*
