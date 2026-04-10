# Roadmap: Carambus API — Model Refactoring & Test Coverage

## Overview

This project extracts two Rails god-objects — TableMonitor (3903 lines) and RegionCc (2728 lines) — into focused service objects without changing external behavior. The approach is strictly incremental: characterization tests pin existing behavior as a hard gate, RegionCc is extracted first (lower real-time risk), then TableMonitor in three passes ordered by coupling surface (ScoreEngine first, ResultRecorder last). Reek baselines are measured before and after to confirm quality improvement.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Characterization Tests & Hardening** - Pin existing behavior with tests; fix AASM and transactional test config before any extraction (completed 2026-04-09)
- [ ] **Phase 2: RegionCc Extraction** - Extract ClubCloudClient and all sync services from RegionCc; verify VCR cassette compatibility
- [x] **Phase 3: TableMonitor ScoreEngine** - Extract pure data hash mutation logic; validate lazy accessor delegation pattern (completed 2026-04-10)
- [x] **Phase 4: TableMonitor GameSetup & OptionsPresenter** - Extract start_game entanglement; replace skip_update_callbacks flag (completed 2026-04-10)
- [x] **Phase 5: TableMonitor ResultRecorder & Final Cleanup** - Extract highest-risk AASM-coupled service; full test coverage; Reek final measurement (completed 2026-04-10)

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
**Plans:** 3 plans (2 complete + 1 gap closure)
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
**Plans:** 3 plans (2 complete + 1 gap closure)
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
**Plans:** 4/4 plans complete
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
**Plans:** 3/3 plans complete
Plans:
- [x] 05-01-PLAN.md — Create ResultRecorder ApplicationService + wire delegation in TableMonitor
- [x] 05-02-PLAN.md — Wire 8 ScoreEngine delegations + clean up DEBUG references in game_protocol_reflex.rb
- [x] 05-03-PLAN.md — Verify full test coverage for all 4 services + Reek final measurement

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Characterization Tests & Hardening | 3/3 | Complete | 2026-04-09 |
| 2. RegionCc Extraction | 0/5 | Planned | - |
| 3. TableMonitor ScoreEngine | 3/3 | Complete | 2026-04-10 |
| 4. TableMonitor GameSetup & OptionsPresenter | 4/4 | Complete   | 2026-04-10 |
| 5. TableMonitor ResultRecorder & Final Cleanup | 3/3 | Complete   | 2026-04-10 |
