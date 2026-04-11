# Roadmap: Carambus API — Model Refactoring & Test Coverage

## Milestones

- ✅ **v1.0 Model Refactoring** - Phases 1-5 (shipped 2026-04-10)
- ✅ **v2.0 Test Suite Audit & Improvement** - Phases 6-10 (shipped 2026-04-10)
- 🚧 **v2.1 Tournament & TournamentMonitor Refactoring** - Phases 11-16 (in progress)

## Phases

<details>
<summary>✅ v1.0 Model Refactoring (Phases 1-5) - SHIPPED 2026-04-10</summary>

### Phase 1: Characterization Tests & Hardening
**Goal**: Existing behavior is fully pinned by characterization tests and structural issues that would corrupt tests are fixed, making extraction safe to begin
**Depends on**: Nothing (first phase)
**Requirements**: TEST-01, TEST-02, QUAL-01
**Success Criteria** (what must be TRUE):
  1. TableMonitor characterization tests cover all state transitions, all three after_update_commit speed branches, skip_update_callbacks suppression, timer callbacks, local_server? branch, and PartyMonitor polymorphic branch — test suite is green
  2. RegionCc characterization tests cover all sync_* and fix operations with VCR cassette coverage — test suite is green
  3. AASM whiny_transitions: true is set and existing tests still pass (no silent guard failures hidden)
  4. Non-transactional test configuration is in place for after_commit coverage; after_commit callbacks fire in test context
  5. Reek baseline report is committed to .planning/ documenting LargeClass and TooManyMethods smells on TableMonitor and RegionCc before any extraction
**Plans:** 3 plans
Plans:
- [x] 01-01-PLAN.md — Infrastructure setup (test_after_commit, AASM whiny_transitions, test directory) + TableMonitor characterization tests
- [x] 01-02-PLAN.md — RegionCc characterization tests with VCR cassettes + Reek baseline reports
- [x] 01-03-PLAN.md — Gap closure: end-to-end tests for ultra_fast and simple after_update_commit speed branches

### Phase 2: RegionCc Extraction
**Goal**: RegionCc is reduced from 2728 lines to under 500 lines by extracting all HTTP and sync logic into independently testable service objects
**Depends on**: Phase 1
**Requirements**: RGCC-01, RGCC-02, RGCC-03, RGCC-04, RGCC-05, RGCC-06
**Success Criteria** (what must be TRUE):
  1. RegionCc::ClubCloudClient exists as a pure I/O service with zero ActiveRecord coupling; existing VCR cassettes replay correctly through the new calling pattern
  2. Nine syncer services (LeagueSyncer, ClubSyncer, BranchSyncer, TournamentSyncer, RegistrationSyncer, CompetitionSyncer, PartySyncer, GamePlanSyncer, MetadataSyncer) each exist as standalone services that inject ClubCloudClient; all sync operations still produce correct database records
  3. RegionCc model is under 500 lines; the public model interface (all sync_* and fix method signatures) is unchanged
  4. All sync service unit tests pass with injected doubles; characterization tests pass through delegation layer
**Plans:** 5 plans
Plans:
- [x] 02-01-PLAN.md — Extract ClubCloudClient (HTTP transport + PATH_MAP)
- [x] 02-02-PLAN.md — Extract LeagueSyncer, ClubSyncer, BranchSyncer
- [x] 02-03-PLAN.md — Extract TournamentSyncer, RegistrationSyncer, CompetitionSyncer
- [x] 02-04-PLAN.md — Extract PartySyncer, GamePlanSyncer, MetadataSyncer
- [x] 02-05-PLAN.md — Wire delegation in RegionCc + full verification + Reek measurement

### Phase 3: TableMonitor ScoreEngine
**Goal**: Score mutation logic is extracted from TableMonitor into a pure data service, validating the lazy accessor delegation pattern for subsequent extractions
**Depends on**: Phase 2
**Requirements**: TMON-01, TMON-05
**Success Criteria** (what must be TRUE):
  1. TableMonitor::ScoreEngine exists and handles all add_n_balls, undo/redo, innings rendering, and snooker methods; it mutates the data hash only — no AASM calls, no CableReady, no database writes
  2. TableMonitor delegates to ScoreEngine via a lazy accessor; all reflex interactions that trigger score changes produce identical results to before extraction
  3. DEBUG constants are removed from TableMonitor; equivalent behavior is available via Rails.logger levels
  4. TableMonitor line count is reduced by approximately 500-600 lines from pre-extraction baseline
**Plans:** 3 plans
Plans:
- [x] 03-01-PLAN.md — Create ScoreEngine PORO with all pure hash mutation methods + unit tests
- [x] 03-02-PLAN.md — Wire delegation in TableMonitor + remove DEBUG constants + verify extraction
- [x] 03-03-PLAN.md — Gap closure: convert remaining 55 `if DEBUG` guards to Rails.logger level calls

### Phase 4: TableMonitor GameSetup & OptionsPresenter
**Goal**: The most entangled method cluster (start_game) and view-preparation logic are extracted; the skip_update_callbacks flag is replaced with an explicit broadcast: false keyword argument
**Depends on**: Phase 3
**Requirements**: TMON-02, TMON-04
**Success Criteria** (what must be TRUE):
  1. TableMonitor::GameSetup exists and handles start_game, initialize_game, assign_game, and player sequence/switching; Game and GameParticipation record creation occurs inside GameSetup, not the model
  2. The skip_update_callbacks flag is gone; batch operations use an explicit broadcast: false keyword argument; job enqueue count assertions verify no extra jobs fire during batch saves
  3. TableMonitor::OptionsPresenter exists and handles all view-preparation logic; reflex interactions that render options produce identical UI output to before extraction
**Plans:** 4 plans
Plans:
- [x] 04-01-PLAN.md — Create GameSetup ApplicationService with unit tests
- [x] 04-02-PLAN.md — Wire GameSetup delegation + replace skip_update_callbacks with suppress_broadcast
- [x] 04-03-PLAN.md — Create OptionsPresenter PORO + wire delegation in get_options!
- [x] 04-04-PLAN.md — Gap closure: remove skip_update_callbacks name from all call sites, replace with suppress_broadcast

### Phase 5: TableMonitor ResultRecorder & Final Cleanup
**Goal**: The highest-risk extraction is complete; TableMonitor is under 1500 lines; full test coverage for all extracted services is verified; Reek final measurement confirms quality improvement
**Depends on**: Phase 4
**Requirements**: TMON-03, TMON-06
**Success Criteria** (what must be TRUE):
  1. TableMonitor::ResultRecorder exists and handles save_result, save_current_set, evaluate_result, switch_to_next_set, and get_max_number_of_wins; it fires AASM events on the model reference (finish_match!, end_of_set!) and never calls CableReady directly
  2. All AASM after_enter callbacks still fire correctly when events are called from ResultRecorder; live match end-to-end flow (result saved → state transition → broadcast → browser update) works identically
  3. All extracted TableMonitor services (ScoreEngine, GameSetup, OptionsPresenter, ResultRecorder) have unit tests with passing assertions; no extraction-related test failures remain
  4. TableMonitor model is under 1500 lines; Reek post-extraction report shows measurable reduction in LargeClass and TooManyMethods smells relative to the Phase 1 baseline
**Plans:** 3 plans
Plans:
- [x] 05-01-PLAN.md — Create ResultRecorder ApplicationService + wire delegation in TableMonitor
- [x] 05-02-PLAN.md — Wire 8 ScoreEngine delegations + clean up DEBUG references in game_protocol_reflex.rb
- [x] 05-03-PLAN.md — Verify full test coverage for all 4 services + Reek final measurement

</details>

---

<details>
<summary>✅ v2.0 Test Suite Audit & Improvement (Phases 6-10) - SHIPPED 2026-04-10</summary>

### Phase 6: Audit Baseline & Standards
**Goal**: A documented quality baseline exists for all 72 test files and consistent patterns are established, so every subsequent review phase applies the same standard
**Depends on**: Phase 5
**Requirements**: QUAL-01, CONS-01, CONS-02, CONS-03, CONS-04
**Success Criteria** (what must be TRUE):
  1. Every test file has been read and catalogued — a written audit list identifies which files have weak assertions, inconsistent setup, naming violations, or bad helper usage
  2. A decision on fixtures vs factories is documented and applied as the project standard going forward
  3. A consistent assertion style (assert/refute) is chosen and documented; files that violate the standard are listed for correction
  4. Test naming conventions are documented (method naming, describe block usage); files that deviate are listed
  5. Test helper and support file usage is reviewed; redundant or unused helpers are identified
**Plans:** 2 plans
Plans:
- [x] 06-01-PLAN.md — Create STANDARDS.md (test suite conventions for Phases 7-9)
- [x] 06-02-PLAN.md — Automated scan + compile AUDIT-REPORT.md (per-file issue catalogue)

### Phase 7: Model Tests Review
**Goal**: All 22 model test files are reviewed and improved — weak assertions fixed, large files restructured if needed, and all model tests reflect the Phase 6 standards
**Depends on**: Phase 6
**Requirements**: MODL-01, MODL-02
**Success Criteria** (what must be TRUE):
  1. All 22 model test files have been reviewed against Phase 6 standards; every weak or missing assertion is fixed
  2. The three largest model test files (table_heater_management 824L, score_engine 703L, tournament_auto_reserve 586L) are assessed and any structural problems (duplicate tests, unclear grouping) are resolved
  3. Model tests pass after improvements; no regressions introduced
**Plans:** 2 plans
Plans:
- [x] 07-01-PLAN.md — Delete 10 empty stubs + add frozen_string_literal to clean model test files
- [x] 07-02-PLAN.md — Fix weak assertions and skipped test in 5 model test files

### Phase 8: Service Tests Review
**Goal**: All 12 service test files are reviewed and improved — the 10 RegionCc syncer tests and 2 TableMonitor service tests meet the Phase 6 standards
**Depends on**: Phase 6
**Requirements**: SRVC-01
**Success Criteria** (what must be TRUE):
  1. All 12 service test files have been reviewed against Phase 6 standards; every weak or missing assertion is fixed
  2. RegionCc syncer tests use injected doubles consistently; no syncer test depends on live HTTP or real ActiveRecord writes where a double suffices
  3. Service tests pass after improvements; no regressions introduced
**Plans:** 2 plans
Plans:
- [x] 08-01-PLAN.md — Strengthen RegionCc syncer + client test assertions (8 files)
- [x] 08-02-PLAN.md — Strengthen TableMonitor service test assertions (2 files)

### Phase 9: Controller, System & Other Tests Review
**Goal**: All 27 remaining test files (controller, system, other) are reviewed and improved against Phase 6 standards
**Depends on**: Phase 6
**Requirements**: CTRL-01, SYST-01, OTHR-01
**Success Criteria** (what must be TRUE):
  1. All 11 controller test files have been reviewed; auth, routing, and response assertions are present and meaningful
  2. All 13 system test files have been reviewed; brittle selectors or timing dependencies are identified and fixed
  3. All other test files (characterization 2, scraping 3, concerns 2, helpers 2, integration 1, tasks 1, optimistic_updates 1) have been reviewed and improved
  4. All 27 reviewed files pass after improvements; no regressions introduced
**Plans:** 2 plans
Plans:
- [x] 09-01-PLAN.md — Bulk frozen_string_literal sweep (22 controller/system/integration/task test files)
- [x] 09-02-PLAN.md — 6 targeted logic fixes (delete non-test, fix assertions, replace regex, remove sleep)

### Phase 10: Final Pass & Green Suite
**Goal**: All cross-cutting quality issues are resolved — skipped tests are fixed or removed, brittle tests are hardened, dead tests are deleted, and the full test suite is green
**Depends on**: Phase 9
**Requirements**: QUAL-02, QUAL-03, QUAL-04, PASS-01
**Success Criteria** (what must be TRUE):
  1. All 8 files with skipped/pending tests have been resolved — each skip is either fixed (test now runs) or removed with a documented justification committed to the codebase
  2. No brittle tests remain — time-dependent, order-dependent, and external-state-dependent tests are fixed or explicitly guarded
  3. All dead and redundant tests are removed — no duplicate assertions, no tests for deleted features, no unreachable code
  4. `bin/rails test` passes with zero failures and zero errors after all improvements
**Plans:** 3/3 plans complete
Plans:
- [x] 10-01-PLAN.md — Infrastructure fixes: ApiProtectorTestOverride, missing fixtures, invalid JSON fixtures
- [x] 10-02-PLAN.md — Fix remaining failures: PG::UniqueViolation, controller scaffolds, KO integration, misc
- [x] 10-03-PLAN.md — VCR cassette recording attempt for 7 skipped RegionCcCharTest tests

</details>

---

### v2.1 Tournament & TournamentMonitor Refactoring (In Progress)

**Milestone Goal:** Reduce Tournament (1775 lines) and TournamentMonitor (499 lines) into maintainable, well-tested components with comprehensive test coverage across models, services, controllers, channels, and jobs.

- [x] **Phase 11: TournamentMonitor Characterization** - Pin TournamentMonitor behavior (AASM, result pipeline, game sequencing, player distribution) before any extraction (completed 2026-04-10)
- [x] **Phase 12: Tournament Characterization** - Pin Tournament behavior (AASM, scraping pipeline, dynamic attributes, PaperTrail baselines) before any extraction (completed 2026-04-10)
- [x] **Phase 13: Low-Risk Extractions** - Extract three smallest services (RankingCalculator, TableReservationService, PlayerGroupDistributor) to prove the pattern (completed 2026-04-10)
- [x] **Phase 14: Medium-Risk Extractions** - Extract PublicCcScraper and RankingResolver, the largest complexity reductions requiring VCR cassettes (completed 2026-04-10)
- [x] **Phase 15: High-Risk Extractions** - Extract ResultProcessor and TablePopulator, which involve DB locks, AASM, and complex algorithms (completed 2026-04-11)
- [ ] **Phase 16: Controller, Job & Channel Coverage** - Add test coverage for controllers, jobs, and channels that touch Tournament and TournamentMonitor; verify quality metrics

## Phase Details

### Phase 11: TournamentMonitor Characterization
**Goal**: TournamentMonitor's critical behavior is fully pinned by characterization tests and ApiProtectorTestOverride is verified, making all TournamentMonitor extractions safe to begin
**Depends on**: Phase 10
**Requirements**: CHAR-01, CHAR-02, CHAR-03, CHAR-04, CHAR-09
**Success Criteria** (what must be TRUE):
  1. TournamentMonitor AASM state machine transitions are covered by tests — every valid transition fires, every invalid transition is rejected, and after_enter callbacks execute correctly
  2. The result pipeline (report_result, write_game_result_data) is covered by tests that verify the exact sequence of DB writes and state changes
  3. populate_tables game sequencing is covered by tests that verify which games are assigned to which tables in deterministic input scenarios
  4. distribute_to_group player distribution is covered by tests that verify group membership and ordering for given player sets
  5. ApiProtectorTestOverride is confirmed active for TournamentMonitor tests — saves succeed without silent rollback in API server context
**Plans:** 2/2 plans complete
Plans:
- [x] 11-01-PLAN.md — T04 (round-robin) characterization: AASM transitions, distribute_to_group, game sequencing, ApiProtector verification
- [x] 11-02-PLAN.md — T06 (with finals) characterization: full AASM lifecycle, result pipeline, group-to-finals transition, Reek baseline

### Phase 12: Tournament Characterization
**Goal**: Tournament's critical behavior is fully pinned — AASM, scraping pipeline, dynamic attribute delegation, and PaperTrail version counts — making all Tournament extractions safe to begin
**Depends on**: Phase 11
**Requirements**: CHAR-05, CHAR-06, CHAR-07, CHAR-08
**Success Criteria** (what must be TRUE):
  1. Tournament AASM state machine transitions are covered by tests — every valid transition fires and guard methods are verified before extraction moves them
  2. The scraping pipeline (scrape_single_tournament_public) is covered by VCR-backed tests that verify the exact records created or updated from a known cassette
  3. All 12 dynamic attribute define_method getters and setters are covered by tests that verify each getter returns the correct value and each setter persists the correct value
  4. PaperTrail version baselines are established — tests assert the exact version count produced by each significant operation (create, update, state transition) so regressions are caught immediately
**Plans:** 3/3 plans complete
Plans:
- [x] 12-01-PLAN.md — AASM state machine + dynamic attribute delegation characterization
- [x] 12-02-PLAN.md — PaperTrail version count baselines
- [x] 12-03-PLAN.md — VCR-backed scraping pipeline characterization + full verification

### Phase 13: Low-Risk Extractions
**Goal**: Three small, pure-logic services are extracted from Tournament and TournamentMonitor — proving the delegation pattern on the easiest targets before tackling larger extractions
**Depends on**: Phase 12
**Requirements**: TEXT-01, TEXT-02, TMEX-01
**Success Criteria** (what must be TRUE):
  1. Tournament::RankingCalculator exists in app/services/tournament/ with unit tests; Tournament delegates to it and produces identical ranking output to before extraction
  2. Tournament::TableReservationService exists in app/services/tournament/ with unit tests; Tournament delegates to it and table reservation behavior is unchanged
  3. TournamentMonitor::PlayerGroupDistributor exists in app/services/tournament_monitor/ with unit tests covering the pure distribution algorithm; TournamentMonitor delegates to it and group assignments are identical to before extraction
  4. All existing characterization tests from Phases 11-12 pass without modification after these extractions
**Plans:** 3/3 plans complete
Plans:
- [x] 13-01-PLAN.md — Extract PlayerGroupDistributor PORO from TournamentMonitor + wire delegation
- [x] 13-02-PLAN.md — Extract RankingCalculator PORO from Tournament + wire delegation
- [x] 13-03-PLAN.md — Extract TableReservationService ApplicationService from Tournament + wire delegation

### Phase 14: Medium-Risk Extractions
**Goal**: PublicCcScraper (700 lines, VCR required) and RankingResolver (regex rule parser) are extracted — the two largest complexity reductions in this milestone
**Depends on**: Phase 13
**Requirements**: TEXT-03, TMEX-02
**Success Criteria** (what must be TRUE):
  1. Tournament::PublicCcScraper exists in app/services/tournament/ with VCR-backed tests; Tournament delegates to it and the scraping pipeline produces identical records to the Phase 12 characterization baseline
  2. TournamentMonitor::RankingResolver exists in app/services/tournament_monitor/ with unit tests covering the regex rule parser; all ranking resolution outcomes match the Phase 11 characterization baseline
  3. Tournament model line count is meaningfully reduced from the Phase 12 baseline (PublicCcScraper extraction alone removes ~700 lines)
  4. All existing characterization tests from Phases 11-12 pass without modification after these extractions
**Plans:** 2/2 plans complete
Plans:
- [x] 14-01-PLAN.md — Extract RankingResolver PORO from TournamentMonitor + wire delegation
- [x] 14-02-PLAN.md — Extract PublicCcScraper ApplicationService from Tournament + wire delegation

### Phase 15: High-Risk Extractions
**Goal**: ResultProcessor (DB lock + AASM) and TablePopulator (complex sequencing algorithm) are extracted — the highest-risk TournamentMonitor extractions, dependent on all prior characterization work
**Depends on**: Phase 14
**Requirements**: TMEX-03, TMEX-04
**Success Criteria** (what must be TRUE):
  1. TournamentMonitor::ResultProcessor exists in app/services/tournament_monitor/ with unit tests; DB lock behavior is preserved — concurrent result submissions do not produce duplicate records or corrupt state
  2. TournamentMonitor::ResultProcessor fires AASM events on the TournamentMonitor model reference; after_enter callbacks execute correctly when events are fired from the service
  3. TournamentMonitor::TablePopulator exists in app/services/tournament_monitor/ with unit tests; populate_tables output is identical to the Phase 11 characterization baseline for all tested input scenarios
  4. All existing characterization tests from Phases 11-12 pass without modification after these extractions
**Plans:** 2/2 plans complete
Plans:
- [x] 15-01-PLAN.md — Extract ResultProcessor service from lib modules + wire delegation
- [x] 15-02-PLAN.md — Extract TablePopulator service from lib modules + wire delegation + lib cleanup

### Phase 16: Controller, Job & Channel Coverage
**Goal**: Test coverage exists for all controllers, jobs, and channels that touch Tournament and TournamentMonitor; Tournament is under 1000 lines; all tests are green; PaperTrail version counts are unchanged
**Depends on**: Phase 15
**Requirements**: COV-01, COV-02, COV-03, COV-04, COV-05, COV-06, QUAL-01, QUAL-02, QUAL-03
**Success Criteria** (what must be TRUE):
  1. TournamentsController has test coverage for all 20+ actions — auth, routing, and response assertions present for each action
  2. TournamentMonitorsController has test coverage for all game pipeline actions — result submission, table assignment, and state transition responses are verified
  3. TournamentMonitorChannel and TournamentChannel each have test coverage — subscription, broadcast triggering, and message format are verified
  4. TournamentStatusUpdateJob and TournamentMonitorUpdateResultsJob each have test coverage — job execution produces the expected model state changes
  5. Tournament model is under 1000 lines; `bin/rails test` passes with zero failures and zero errors; PaperTrail version counts per operation match the Phase 12 baselines
**Plans:** 3 plans
Plans:
- [ ] 16-01-PLAN.md — TournamentsController test coverage (20+ actions, auth + local server guards)
- [ ] 16-02-PLAN.md — TournamentMonitorsController + channels + jobs test coverage
- [ ] 16-03-PLAN.md — Quality gate verification (line count, green suite, PaperTrail baselines)

## Progress

**Execution Order:**
Phases execute in numeric order: 11 -> 12 -> 13 -> 14 -> 15 -> 16

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Characterization Tests & Hardening | v1.0 | 3/3 | Complete | 2026-04-09 |
| 2. RegionCc Extraction | v1.0 | 5/5 | Complete | 2026-04-10 |
| 3. TableMonitor ScoreEngine | v1.0 | 3/3 | Complete | 2026-04-10 |
| 4. TableMonitor GameSetup & OptionsPresenter | v1.0 | 4/4 | Complete | 2026-04-10 |
| 5. TableMonitor ResultRecorder & Final Cleanup | v1.0 | 3/3 | Complete | 2026-04-10 |
| 6. Audit Baseline & Standards | v2.0 | 2/2 | Complete | 2026-04-10 |
| 7. Model Tests Review | v2.0 | 2/2 | Complete | 2026-04-10 |
| 8. Service Tests Review | v2.0 | 2/2 | Complete | 2026-04-10 |
| 9. Controller, System & Other Tests Review | v2.0 | 2/2 | Complete | 2026-04-10 |
| 10. Final Pass & Green Suite | v2.0 | 3/3 | Complete | 2026-04-10 |
| 11. TournamentMonitor Characterization | v2.1 | 2/2 | Complete   | 2026-04-10 |
| 12. Tournament Characterization | v2.1 | 3/3 | Complete   | 2026-04-10 |
| 13. Low-Risk Extractions | v2.1 | 3/3 | Complete   | 2026-04-10 |
| 14. Medium-Risk Extractions | v2.1 | 2/2 | Complete   | 2026-04-10 |
| 15. High-Risk Extractions | v2.1 | 2/2 | Complete   | 2026-04-11 |
| 16. Controller, Job & Channel Coverage | v2.1 | 0/3 | Not started | - |
