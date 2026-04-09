# Roadmap: Carambus API — Model Refactoring & Test Coverage

## Overview

This project extracts two Rails god-objects — TableMonitor (3903 lines) and RegionCc (2728 lines) — into focused service objects without changing external behavior. The approach is strictly incremental: characterization tests pin existing behavior as a hard gate, RegionCc is extracted first (lower real-time risk), then TableMonitor in three passes ordered by coupling surface (ScoreEngine first, ResultRecorder last). Reek baselines are measured before and after to confirm quality improvement.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Characterization Tests & Hardening** - Pin existing behavior with tests; fix AASM and transactional test config before any extraction
- [ ] **Phase 2: RegionCc Extraction** - Extract HttpClient and all sync services from RegionCc; re-record VCR cassettes
- [ ] **Phase 3: TableMonitor ScoreEngine** - Extract pure data hash mutation logic; validate lazy accessor delegation pattern
- [ ] **Phase 4: TableMonitor GameSetup & OptionsPresenter** - Extract start_game entanglement; replace skip_update_callbacks flag
- [ ] **Phase 5: TableMonitor ResultRecorder & Final Cleanup** - Extract highest-risk AASM-coupled service; full test coverage; Reek final measurement

## Phase Details

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
**Plans:** 2 plans
Plans:
- [x] 01-01-PLAN.md — Infrastructure setup (test_after_commit, AASM whiny_transitions, test directory) + TableMonitor characterization tests
- [ ] 01-02-PLAN.md — RegionCc characterization tests with VCR cassettes + Reek baseline reports

### Phase 2: RegionCc Extraction
**Goal**: RegionCc is reduced from 2728 lines to ~200-300 lines by extracting all HTTP and sync logic into independently testable service objects
**Depends on**: Phase 1
**Requirements**: RGCC-01, RGCC-02, RGCC-03, RGCC-04, RGCC-05, RGCC-06
**Success Criteria** (what must be TRUE):
  1. RegionCc::HttpClient exists as a pure I/O service with zero ActiveRecord coupling; existing VCR cassettes are re-recorded against the new calling pattern
  2. RegionCc::LeagueSyncer, RegionCc::TournamentSyncer, and RegionCc::PartySyncer each exist as standalone services that inject HttpClient; all sync operations still produce correct database records
  3. RegionCc model is under 500 lines; the public model interface (all sync_* and fix method signatures) is unchanged
  4. All sync service unit tests pass with injected doubles; assert_requested count assertions guard against cassette drift
**Plans**: TBD

### Phase 3: TableMonitor ScoreEngine
**Goal**: Score mutation logic is extracted from TableMonitor into a pure data service, validating the lazy accessor delegation pattern for subsequent extractions
**Depends on**: Phase 2
**Requirements**: TMON-01, TMON-05
**Success Criteria** (what must be TRUE):
  1. TableMonitor::ScoreEngine exists and handles all add_n_balls, undo/redo, innings rendering, and snooker methods; it mutates the data hash only — no AASM calls, no CableReady, no database writes
  2. TableMonitor delegates to ScoreEngine via a lazy accessor; all reflex interactions that trigger score changes produce identical results to before extraction
  3. DEBUG constants are removed from TableMonitor; equivalent behavior is available via Rails.logger levels
  4. TableMonitor line count is reduced by approximately 500-600 lines from pre-extraction baseline
**Plans**: TBD

### Phase 4: TableMonitor GameSetup & OptionsPresenter
**Goal**: The most entangled method cluster (start_game) and view-preparation logic are extracted; the skip_update_callbacks flag is replaced with an explicit broadcast: false keyword argument
**Depends on**: Phase 3
**Requirements**: TMON-02, TMON-04
**Success Criteria** (what must be TRUE):
  1. TableMonitor::GameSetup exists and handles start_game, initialize_game, assign_game, and player sequence/switching; Game and GameParticipation record creation occurs inside GameSetup, not the model
  2. The skip_update_callbacks flag is gone; batch operations use an explicit broadcast: false keyword argument; job enqueue count assertions verify no extra jobs fire during batch saves
  3. TableMonitor::OptionsPresenter exists and handles all view-preparation logic; reflex interactions that render options produce identical UI output to before extraction
**Plans**: TBD

### Phase 5: TableMonitor ResultRecorder & Final Cleanup
**Goal**: The highest-risk extraction is complete; TableMonitor is under 800 lines; full test coverage for all extracted services is verified; Reek final measurement confirms quality improvement
**Depends on**: Phase 4
**Requirements**: TMON-03, TMON-06
**Success Criteria** (what must be TRUE):
  1. TableMonitor::ResultRecorder exists and handles save_result, save_current_set, evaluate_result, switch_to_next_set, and get_max_number_of_wins; it fires AASM events on the model reference (finish_match!, end_of_set!) and never calls CableReady directly
  2. All AASM after_enter callbacks still fire correctly when events are called from ResultRecorder; live match end-to-end flow (result saved → state transition → broadcast → browser update) works identically
  3. All extracted TableMonitor services (ScoreEngine, GameSetup, OptionsPresenter, ResultRecorder) have unit tests with passing assertions; no extraction-related test failures remain
  4. TableMonitor model is under 800 lines; Reek post-extraction report shows measurable reduction in LargeClass and TooManyMethods smells relative to the Phase 1 baseline

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Characterization Tests & Hardening | 0/2 | Not started | - |
| 2. RegionCc Extraction | 0/? | Not started | - |
| 3. TableMonitor ScoreEngine | 0/? | Not started | - |
| 4. TableMonitor GameSetup & OptionsPresenter | 0/? | Not started | - |
| 5. TableMonitor ResultRecorder & Final Cleanup | 0/? | Not started | - |
