# Roadmap: Carambus API — Model Refactoring & Test Coverage

## Milestones

- ✅ **v1.0 Model Refactoring** - Phases 1-5 (shipped 2026-04-10)
- 🚧 **v2.0 Test Suite Audit & Improvement** - Phases 6-10 (in progress)

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

### v2.0 Test Suite Audit & Improvement (In Progress)

**Milestone Goal:** Every existing test file is reviewed, consistent, and trustworthy — no dead tests, no skipped tests without justification, no brittle patterns.

- [ ] **Phase 6: Audit Baseline & Standards** - Survey all 72 test files; document quality issues; establish consistent patterns for the suite
- [ ] **Phase 7: Model Tests Review** - Review and improve all 22 model test files, including the three largest (table_heater_management 824L, score_engine 703L, tournament_auto_reserve 586L)
- [ ] **Phase 8: Service Tests Review** - Review and improve all 12 service test files (10 RegionCc syncers + 2 TableMonitor services)
- [ ] **Phase 9: Controller, System & Other Tests Review** - Review and improve all 27 remaining test files (11 controller + 13 system + 3 other categories)
- [ ] **Phase 10: Final Pass & Green Suite** - Resolve all skipped/pending tests; remove dead/redundant tests; fix brittle tests; verify full suite passes

## Phase Details

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
**Plans:** 3 plans
Plans:
- [ ] 10-01-PLAN.md — Infrastructure fixes: ApiProtectorTestOverride, missing fixtures, invalid JSON fixtures
- [ ] 10-02-PLAN.md — Fix remaining failures: PG::UniqueViolation, controller scaffolds, KO integration, misc
- [ ] 10-03-PLAN.md — VCR cassette recording attempt for 7 skipped RegionCcCharTest tests

## Progress

**Execution Order:**
Phases execute in numeric order: 6 -> 7 -> 8 -> 9 -> 10

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Characterization Tests & Hardening | v1.0 | 3/3 | Complete | 2026-04-09 |
| 2. RegionCc Extraction | v1.0 | 5/5 | Complete | 2026-04-10 |
| 3. TableMonitor ScoreEngine | v1.0 | 3/3 | Complete | 2026-04-10 |
| 4. TableMonitor GameSetup & OptionsPresenter | v1.0 | 4/4 | Complete | 2026-04-10 |
| 5. TableMonitor ResultRecorder & Final Cleanup | v1.0 | 3/3 | Complete | 2026-04-10 |
| 6. Audit Baseline & Standards | v2.0 | 2/2 | Complete | 2026-04-10 |
| 7. Model Tests Review | v2.0 | 2/2 | Complete | 2026-04-10 |
| 8. Service Tests Review | v2.0 | 0/2 | Planning complete | - |
| 9. Controller, System & Other Tests Review | v2.0 | 0/2 | Planning complete | - |
| 10. Final Pass & Green Suite | v2.0 | 0/3 | Planning complete | - |
