---
phase: 21-league-extraction
plan: "01"
subsystem: testing
tags: [ruby, rails, refactoring, service-objects, league, standings, game-plan]

# Dependency graph
requires:
  - phase: 20-characterization
    provides: Characterization tests for League critical paths (25 tests, standings + game plan + scraping)
provides:
  - League::StandingsCalculator PORO (karambol, snooker, pool, schedule_by_rounds)
  - League::GamePlanReconstructor ApplicationService (reconstruct, reconstruct_for_season, delete_for_season)
  - Thin delegation wrappers in league.rb for all extracted methods
affects:
  - 21-league-extraction (plans 02+)
  - future league-related changes

# Tech tracking
tech-stack:
  added: []
  patterns:
    - PORO calculator pattern (League::StandingsCalculator follows Tournament::RankingCalculator)
    - ApplicationService dispatcher pattern with operation: keyword (League::GamePlanReconstructor)
    - Private shim delegation to service private methods (analyze_game_plan_structure compatibility shim)

key-files:
  created:
    - app/services/league/standings_calculator.rb
    - app/services/league/game_plan_reconstructor.rb
    - test/services/league/standings_calculator_test.rb
    - test/services/league/game_plan_reconstructor_test.rb
  modified:
    - app/models/league.rb

key-decisions:
  - "Private analyze_game_plan_structure shim added to League — characterization test calls league.send(:analyze_game_plan_structure) which requires the method to remain accessible via the model"
  - "reconstruct_game_plan_from_existing_data moved to public section of League — plan called for public delegation wrapper, original was private"
  - "find_leagues_with_same_gameplan and find_or_create_shared_gameplan moved entirely to service as private helpers — zero external callers confirmed"

patterns-established:
  - "League:: service namespace under app/services/league/ for all extracted League code"
  - "Thin one-liner delegation wrappers in league.rb are permanent public API (D-11, D-12)"
  - "Private service method compatibility shims for characterization tests that use .send"

requirements-completed: [EXTR-01, EXTR-03]

# Metrics
duration: 45min
completed: 2026-04-11
---

# Phase 21 Plan 01: League Extraction (StandingsCalculator + GamePlanReconstructor) Summary

**League::StandingsCalculator PORO and League::GamePlanReconstructor ApplicationService extracted from league.rb, reducing model by 618 lines (2221 -> 1603) while preserving all 25 Phase 20 characterization tests unchanged**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-04-11T20:30:00Z
- **Completed:** 2026-04-11T22:45:00Z
- **Tasks:** 2
- **Files modified:** 5 (2 new services, 2 new test files, 1 model updated)

## Accomplishments

- Extracted `League::StandingsCalculator` PORO with 4 public methods (karambol, snooker, pool, schedule_by_rounds) — ~226 lines moved from league.rb
- Extracted `League::GamePlanReconstructor` ApplicationService with dispatcher pattern (`operation: :reconstruct / :reconstruct_for_season / :delete_for_season`) — ~392 lines moved from league.rb
- Removed `analyze_game_plan_structure`, `find_leagues_with_same_gameplan`, `find_or_create_shared_gameplan` from league.rb (moved to service as private helpers)
- All 25 Phase 20 characterization tests pass without modification
- 20 new service tests added (12 for StandingsCalculator, 8 for GamePlanReconstructor)

## Task Commits

Each task was committed atomically:

1. **Task 1: Extract League::StandingsCalculator PORO** - `55b65794` (feat)
2. **Task 2: Extract League::GamePlanReconstructor ApplicationService** - `cec2410f` (feat)

## Files Created/Modified

- `app/services/league/standings_calculator.rb` — PORO with karambol, snooker, pool, schedule_by_rounds methods
- `app/services/league/game_plan_reconstructor.rb` — ApplicationService with dispatcher pattern for all game plan operations
- `test/services/league/standings_calculator_test.rb` — 12 tests verifying service returns same results as League model delegation
- `test/services/league/game_plan_reconstructor_test.rb` — 8 tests verifying dispatcher, result contracts, and unknown operation raises
- `app/models/league.rb` — Replaced 618 lines with thin delegation wrappers; added private analyze_game_plan_structure shim

## Decisions Made

- Added private `analyze_game_plan_structure` shim on League model (delegates to service via `.send`) — the Phase 20 characterization test calls `league.send(:analyze_game_plan_structure, ...)` directly and must not be modified per plan constraints
- Made `reconstruct_game_plan_from_existing_data` delegation wrapper public (placed above `private` keyword) — the plan specifies it should be a permanent public API wrapper; the original was private due to pre-Phase-20 design
- `find_leagues_with_same_gameplan` and `find_or_create_shared_gameplan` moved to service as private methods, completely removed from league.rb — zero external callers confirmed per RESEARCH.md

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Private analyze_game_plan_structure shim required**
- **Found during:** Task 2 (Extract League::GamePlanReconstructor)
- **Issue:** Phase 20 characterization test calls `league.send(:analyze_game_plan_structure, party, game_plan_hash, disciplines_hash)` — after moving the method to the service, the test raised `NoMethodError: undefined method 'analyze_game_plan_structure'`
- **Fix:** Added a private delegation shim on League that forwards to `League::GamePlanReconstructor.new(league: self).send(:analyze_game_plan_structure, ...)` — preserves `.send` accessibility without changing test code
- **Files modified:** app/models/league.rb
- **Verification:** `bin/rails test test/models/league_test.rb` passes; 0 failures
- **Committed in:** cec2410f (Task 2 commit)

**2. [Rule 1 - Bug] reconstruct_game_plan_from_existing_data was private — delegation wrapper must be public**
- **Found during:** Task 2 (GamePlanReconstructor test run)
- **Issue:** Delegation wrapper was placed after `private` keyword; `League::GamePlanReconstructorTest` called it directly and got `NoMethodError: private method called`
- **Fix:** Moved the delegation wrapper to the public section (before `private` keyword)
- **Files modified:** app/models/league.rb
- **Verification:** All 8 GamePlanReconstructor tests pass
- **Committed in:** cec2410f (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs)
**Impact on plan:** Both fixes required for test correctness. No scope creep — both are direct consequences of the extraction.

## Issues Encountered

- StandardRB reported useless variable assignments in the service files (initial `partien_str = "0:0"` and `frames_str = "0:0"` values) — fixed by inlining the string interpolation directly into the hash return
- StandardRB multiline method call indentation for the `.where(regions:...)` chain — fixed by breaking to explicit 2-space indented chain

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- League::StandingsCalculator and League::GamePlanReconstructor fully extracted and tested
- league.rb reduced from 2221 to 1603 lines (618 lines removed in plan 01)
- Phase 21 Plan 02 (ClubCloud + BBV scrapers) can proceed independently
- No blockers

## Self-Check: PASSED

- app/services/league/standings_calculator.rb: FOUND
- app/services/league/game_plan_reconstructor.rb: FOUND
- test/services/league/standings_calculator_test.rb: FOUND
- test/services/league/game_plan_reconstructor_test.rb: FOUND
- Commit 55b65794 (Task 1): FOUND
- Commit cec2410f (Task 2): FOUND

---
*Phase: 21-league-extraction*
*Completed: 2026-04-11*
