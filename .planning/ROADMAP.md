# Roadmap: Carambus API — Model Refactoring & Test Coverage

## Milestones

- ✅ **v1.0 Model Refactoring** - Phases 1-5 (shipped 2026-04-10)
- ✅ **v2.0 Test Suite Audit** - Phases 6-10 (shipped 2026-04-10)
- ✅ **v2.1 Tournament & TournamentMonitor Refactoring** - Phases 11-16 (shipped 2026-04-11)
- ✅ **v3.0 Broadcast Isolation Testing** - Phases 17-19 (shipped 2026-04-11)
- 🚧 **v4.0 League & PartyMonitor Refactoring** - Phases 20-23 (in progress)

## Phases

<details>
<summary>✅ v1.0 Model Refactoring (Phases 1-5) - SHIPPED 2026-04-10</summary>

### Phase 1: TableMonitor Characterization
**Goal**: TableMonitor critical paths are pinned by tests before any extraction begins
**Plans**: Complete

Plans:
- [x] 01-01: AASM state machine and after_enter callbacks characterization
- [x] 01-02: after_update_commit routing branches characterization

### Phase 2: RegionCc Characterization
**Goal**: RegionCc critical paths and Reek baselines established before extraction
**Plans**: Complete

### Phase 3: TableMonitor Extraction
**Goal**: Service classes extracted from TableMonitor, model size reduced significantly
**Plans**: Complete

### Phase 4: RegionCc Extraction
**Goal**: Service classes extracted from RegionCc, model size reduced significantly
**Plans**: Complete

### Phase 5: Verification
**Goal**: All extracted services verified with tests, Reek improvement measured
**Plans**: Complete

</details>

<details>
<summary>✅ v2.0 Test Suite Audit (Phases 6-10) - SHIPPED 2026-04-10</summary>

### Phase 6: Standards
**Goal**: Test standards documented and audit criteria defined
**Plans**: Complete

### Phase 7: Audit
**Goal**: All 72 test files catalogued for issues
**Plans**: Complete

### Phase 8: Cleanup
**Goal**: Empty stubs deleted, frozen_string_literal added
**Plans**: Complete

### Phase 9: Fixes
**Goal**: Weak assertions strengthened, pre-existing bugs fixed
**Plans**: Complete

### Phase 10: Green Suite
**Goal**: All tests passing with ApiProtectorTestOverride in place
**Plans**: Complete

</details>

<details>
<summary>✅ v2.1 Tournament & TournamentMonitor Refactoring (Phases 11-16) - SHIPPED 2026-04-11</summary>

### Phase 11: TournamentMonitor Characterization (T04)
**Goal**: T04 round-robin behavior pinned by characterization tests
**Plans**: Complete

### Phase 12: TournamentMonitor Characterization (T06)
**Goal**: T06 with-finals behavior pinned by characterization tests
**Plans**: Complete

### Phase 13: Tournament Characterization
**Goal**: Tournament AASM, PaperTrail baselines, and Calendar wiring pinned
**Plans**: Complete

### Phase 14: Tournament Extraction
**Goal**: Service classes extracted from Tournament model
**Plans**: Complete

### Phase 15: TournamentMonitor Extraction
**Goal**: Service classes extracted from TournamentMonitor, lib module deleted
**Plans**: Complete

### Phase 16: Controller & Channel Coverage
**Goal**: TournamentsController, TournamentMonitorsController, channels, and jobs covered
**Plans**: Complete

</details>

<details>
<summary>✅ v3.0 Broadcast Isolation Testing (Phases 17-19) - SHIPPED 2026-04-11</summary>

### Phase 17: System Test Infrastructure
**Goal**: Capybara/Selenium infrastructure enabling broadcast isolation tests
**Plans**: Complete

### Phase 18: Broadcast Isolation Tests
**Goal**: Multi-scoreboard broadcast isolation verified by passing system tests
**Plans**: Complete

### Phase 19: Gap Report
**Goal**: All broadcast isolation requirements documented, deferred items tracked
**Plans**: Complete

</details>

---

### 🚧 v4.0 League & PartyMonitor Refactoring (In Progress)

**Milestone Goal:** Break down League (2219 lines) and PartyMonitor (605 lines) into smaller, well-tested service classes — following the characterization-first, test-driven extraction pattern proven in v1.0 and v2.1.

## Phase Details

### Phase 20: Characterization
**Goal**: All critical paths in League, PartyMonitor, Party, and LeagueTeam are pinned by tests before any extraction begins
**Depends on**: Phase 19
**Requirements**: CHAR-01, CHAR-02, CHAR-03, CHAR-04, CHAR-05, CHAR-06
**Success Criteria** (what must be TRUE):
  1. League AASM state machine transitions can be exercised and verified by tests without touching the model
  2. League sync operations (schedule, standings, team management) are pinned — a behavior change in League would cause at least one characterization test to fail
  3. PartyMonitor AASM transitions and game sequencing are pinned — round progression and state flow are observable by tests
  4. PartyMonitor player-to-game assignment and table placement are pinned by tests with fixture-backed assertions
  5. Party and LeagueTeam critical paths (associations, state, scoring, roster) are pinned and all new characterization tests are green
**Plans**: 3 plans

Plans:
- [x] 20-01-PLAN.md — LeagueTeam + Party characterization (associations, computed properties, fixtures)
- [x] 20-02-PLAN.md — League standings, game plan reconstruction, and scraping pipeline characterization
- [x] 20-03-PLAN.md — PartyMonitor AASM state machine + placement/result/round management characterization

### Phase 21: League Extraction
**Goal**: Service classes are extracted from League, model line count is reduced significantly, and all characterization tests remain green
**Depends on**: Phase 20
**Requirements**: EXTR-01, EXTR-03, EXTR-04
**Success Criteria** (what must be TRUE):
  1. League model line count is measurably reduced from 2219 lines (at least one cohesive responsibility extracted)
  2. All Phase 20 characterization tests pass without modification after extraction
  3. All 751+ existing tests remain green (0 failures, 0 errors) after extraction
  4. Each extracted service class has its own passing test coverage
**Plans**: TBD

### Phase 22: PartyMonitor Extraction
**Goal**: Service classes are extracted from PartyMonitor, model line count is reduced significantly, and all existing tests remain green
**Depends on**: Phase 21
**Requirements**: EXTR-02
**Success Criteria** (what must be TRUE):
  1. PartyMonitor model line count is measurably reduced from 605 lines (game sequencing, assignment, or table placement extracted)
  2. All Phase 20 characterization tests for PartyMonitor pass without modification after extraction
  3. All existing tests remain green (0 failures, 0 errors) after extraction
  4. Each extracted service class has its own passing test coverage
**Plans**: TBD

### Phase 23: Coverage
**Goal**: Controller, channel, and job test coverage for the League/Party/PartyMonitor ecosystem is in place and the full suite is green
**Depends on**: Phase 22
**Requirements**: COV-01, COV-02, COV-03
**Success Criteria** (what must be TRUE):
  1. LeaguesController and PartiesController (or equivalent action set) have integration tests covering key actions including access guards
  2. PartyMonitor-related channels and background jobs have unit or integration tests
  3. Full test suite is green (0 failures, 0 errors) after all coverage additions
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 20 → 21 → 22 → 23

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-5. v1.0 phases | v1.0 | Complete | Complete | 2026-04-10 |
| 6-10. v2.0 phases | v2.0 | Complete | Complete | 2026-04-10 |
| 11-16. v2.1 phases | v2.1 | Complete | Complete | 2026-04-11 |
| 17-19. v3.0 phases | v3.0 | Complete | Complete | 2026-04-11 |
| 20. Characterization | v4.0 | 3/3 | Complete    | 2026-04-11 |
| 21. League Extraction | v4.0 | 0/? | Not started | - |
| 22. PartyMonitor Extraction | v4.0 | 0/? | Not started | - |
| 23. Coverage | v4.0 | 0/? | Not started | - |
