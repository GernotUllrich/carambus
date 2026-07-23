---
phase: 13-low-risk-extractions
plan: "02"
subsystem: tournament
tags: [ruby, rails, refactoring, poro, extraction, ranking, seedings]

requires:
  - phase: 13-low-risk-extractions
    plan: "01"
    provides: PlayerGroupDistributor PORO pattern — same constructor/delegation approach used here

provides:
  - Tournament::RankingCalculator PORO at app/services/tournament/ranking_calculator.rb
  - Unit tests at test/services/tournament/ranking_calculator_test.rb
  - Delegation wrappers on Tournament model for calculate_and_cache_rankings and reorder_seedings

affects:
  - 13-03 (next low-risk extraction in same phase)
  - tournament model consumers (TournamentsController lines 112, 961 — transparent via delegation)

tech-stack:
  added: []
  patterns:
    - "PORO extraction: initialize(tournament) constructor, all bare method calls prefixed with @tournament."
    - "1-line delegation wrapper in model: Tournament::RankingCalculator.new(self).method_name"

key-files:
  created:
    - app/services/tournament/ranking_calculator.rb
    - test/services/tournament/ranking_calculator_test.rb
  modified:
    - app/models/tournament.rb

key-decisions:
  - "PORO (no ApplicationService inheritance) per D-02 — ranking logic is pure computation + DB write, not a service workflow"
  - "Test 4 (caching) required explicit discipline fixture to trigger the non-early-return path"

patterns-established:
  - "Tournament service directory: app/services/tournament/ — established by this plan"
  - "Tournament test service directory: test/services/tournament/ — established by this plan"

requirements-completed: [TEXT-01]

duration: 15min
completed: 2026-04-10
---

# Phase 13 Plan 02: RankingCalculator Extraction Summary

**Tournament::RankingCalculator PORO extracted from tournament.rb — calculate_and_cache_rankings and reorder_seedings delegated, 50 lines removed**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-10T23:00:00Z
- **Completed:** 2026-04-10T23:15:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created `Tournament::RankingCalculator` PORO with `calculate_and_cache_rankings` and `reorder_seedings` methods
- All self-references converted to `@tournament.` prefix — PORO is fully self-contained
- 5 unit tests covering early-return guards (no Region, no discipline, global id), caching, and seeding reorder
- Tournament model reduced from 1775 to 1725 lines (50 lines removed)
- All 42 characterization and unit tests pass without modification

## Task Commits

1. **Task 1: Create RankingCalculator PORO with unit tests** - `065c1af8` (feat)
2. **Task 2: Wire delegation in Tournament and verify characterization tests** - `84290611` (feat)

## Files Created/Modified
- `app/services/tournament/ranking_calculator.rb` - PORO with both methods, frozen_string_literal, no ApplicationService inheritance
- `test/services/tournament/ranking_calculator_test.rb` - 5 unit tests
- `app/models/tournament.rb` - calculate_and_cache_rankings and reorder_seedings replaced with 1-line delegation wrappers

## Decisions Made
- PORO (no ApplicationService inheritance) per D-02 — this is DB-mutating business logic, not a service workflow
- Established `app/services/tournament/` and `test/services/tournament/` directories (first plan to use them)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test fixture reference: clubs(:club_one) → clubs(:bcw)**
- **Found during:** Task 1 (RED test run)
- **Issue:** Test referenced non-existent fixture key `club_one`; clubs.yml uses `bcw`
- **Fix:** Updated fixture reference to `clubs(:bcw)`
- **Files modified:** test/services/tournament/ranking_calculator_test.rb
- **Verification:** Tests pass
- **Committed in:** `065c1af8` (Task 1 commit)

**2. [Rule 1 - Bug] Test 4 required explicit discipline to trigger non-early-return path**
- **Found during:** Task 1 (GREEN test run, 1 failure)
- **Issue:** `build_local_tournament` without discipline caused early return; `player_rankings` was never written to data hash so assert_not_nil failed
- **Fix:** Added `discipline: disciplines(:carom_3band)` to Test 4 tournament creation
- **Files modified:** test/services/tournament/ranking_calculator_test.rb
- **Verification:** All 5 tests pass
- **Committed in:** `065c1af8` (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (2 × Rule 1 - Bug)
**Impact on plan:** Both fixes were test-side corrections to match actual fixture data and method behavior. No scope creep.

## Issues Encountered
None beyond the two auto-fixed test bugs above.

## Next Phase Readiness
- Both low-risk Tournament extractions (PlayerGroupDistributor in 13-01, RankingCalculator in 13-02) are complete
- Pattern is proven: PORO with `initialize(model)` + delegation wrappers
- Ready for 13-03 (next plan in wave 3)

---
*Phase: 13-low-risk-extractions*
*Completed: 2026-04-10*
