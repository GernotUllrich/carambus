---
phase: 14-medium-risk-extractions
plan: "01"
subsystem: testing
tags: [ruby, rails, tournament_monitor, refactoring, poro, extraction, ranking]

# Dependency graph
requires:
  - phase: 13-low-risk-extractions
    provides: PlayerGroupDistributor PORO (called directly by RankingResolver per D-05)
provides:
  - TournamentMonitor::RankingResolver PORO with 5 ranking resolution methods
  - Delegation wrapper on TournamentMonitor for player_id_from_ranking
  - Unit tests for all RankingResolver resolution paths
  - Cross-service call from RankingResolver to PlayerGroupDistributor (D-05)
affects: [15-high-risk-extractions, tournament_monitor_support, tournament_monitor_state]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "PORO extraction: constructor stores @tournament_monitor, all data/tournament references via accessor"
    - "Cross-service delegation: RankingResolver calls PlayerGroupDistributor directly (D-05)"
    - "Delegation wrapper: TournamentMonitor.player_id_from_ranking → RankingResolver.new(self)"
    - "Private ko_ranking delegation wrapper kept on TournamentMonitor for characterization test send(:ko_ranking) compatibility"

key-files:
  created:
    - app/services/tournament_monitor/ranking_resolver.rb
    - test/services/tournament_monitor/ranking_resolver_test.rb
  modified:
    - app/models/tournament_monitor.rb

key-decisions:
  - "Keep private ko_ranking delegation wrapper on TournamentMonitor — characterization tests call @tm.send(:ko_ranking) directly, preserving test compatibility without modifying tests"
  - "group_rank calls TournamentMonitor::PlayerGroupDistributor.distribute_to_group directly per D-05 — no indirect routing through TournamentMonitor.distribute_to_group"
  - "TournamentMonitor.ranking class method stays on model per Pitfall 5 — RankingResolver calls it as TournamentMonitor.ranking (fully qualified)"

patterns-established:
  - "PORO pattern established in Phase 13 (PlayerGroupDistributor) reused exactly: frozen_string_literal, German docstring, @tournament_monitor accessor pattern"
  - "Cross-service calls between extracted POROs use fully qualified class names, not TournamentMonitor delegation wrappers"

requirements-completed: [TMEX-02]

# Metrics
duration: 25min
completed: 2026-04-10
---

# Phase 14 Plan 01: RankingResolver Extraction Summary

**RankingResolver PORO extracted from TournamentMonitor with 5 methods, cross-service call to PlayerGroupDistributor (D-05), and delegation wrapper reducing TournamentMonitor by ~168 lines**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-10T23:30:00Z
- **Completed:** 2026-04-10T23:55:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Extracted 5 ranking resolution methods (player_id_from_ranking, ko_ranking, group_rank, random_from_group_ranks, rank_from_group_ranks) into TournamentMonitor::RankingResolver PORO
- Implemented D-05: group_rank calls PlayerGroupDistributor.distribute_to_group directly (not TournamentMonitor.distribute_to_group wrapper)
- TournamentMonitor reduced from 349 to 181 lines (~168 lines removed)
- All 70 characterization + resolver tests pass (0 failures, 0 errors, 0 skips)

## Task Commits

Each task was committed atomically:

1. **Task 1 (RED): Add failing tests** - `a0e6da9b` (test)
2. **Task 1 (GREEN): Create RankingResolver PORO** - `2740b27b` (feat)
3. **Task 2: Wire delegation in TournamentMonitor** - `3fbcafc4` (feat)

_Note: TDD task has two commits (test RED → feat GREEN)_

## Files Created/Modified

- `app/services/tournament_monitor/ranking_resolver.rb` — RankingResolver PORO with 5 extracted methods, D-05 direct cross-service call
- `test/services/tournament_monitor/ranking_resolver_test.rb` — 8 unit tests covering all resolution paths and D-05 verification
- `app/models/tournament_monitor.rb` — Delegation wrapper for player_id_from_ranking, private ko_ranking wrapper for test compatibility, 168 lines removed

## Decisions Made

- Keep private `ko_ranking` delegation wrapper on TournamentMonitor: characterization tests call `@tm.send(:ko_ranking, ...)` directly. Deleting the method would break the tests without modification — added a thin private wrapper that delegates to `RankingResolver.new(self).send(:ko_ranking, rule_str)`.
- D-05 implemented: `group_rank` calls `TournamentMonitor::PlayerGroupDistributor.distribute_to_group` directly instead of routing through `TournamentMonitor.distribute_to_group` wrapper.
- `TournamentMonitor.ranking` class method stays on model (Pitfall 5) — called as fully-qualified class method from RankingResolver.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added private ko_ranking delegation wrapper to preserve characterization test compatibility**
- **Found during:** Task 2 (Wire delegation in TournamentMonitor)
- **Issue:** Plan said to DELETE ko_ranking from TournamentMonitor entirely, but tournament_monitor_ko_test.rb calls `@tm.send(:ko_ranking, ...)` directly on 3 tests. Deleting the method caused 2 test errors (NoMethodError).
- **Fix:** Added thin private wrapper `def ko_ranking(rule_str); TournamentMonitor::RankingResolver.new(self).send(:ko_ranking, rule_str); end` — preserves test behavior without modifying characterization tests.
- **Files modified:** app/models/tournament_monitor.rb
- **Verification:** All 70 tests pass (0 failures, 0 errors)
- **Committed in:** 3fbcafc4 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug/behavior preservation)
**Impact on plan:** Essential for satisfying the plan's own must_have truth "All Phase 11-12 characterization tests pass without modification." No scope creep.

## Issues Encountered

None beyond the ko_ranking deviation documented above.

## User Setup Required

None - pure internal refactoring, no external service configuration required.

## Next Phase Readiness

- RankingResolver PORO complete, cross-service D-05 dependency established
- TournamentMonitor at 181 lines (down from 349)
- Ready for Phase 14 Plan 02 (next extraction in medium-risk phase)
- All characterization tests green — no regressions

## Self-Check

- [x] `app/services/tournament_monitor/ranking_resolver.rb` exists
- [x] `test/services/tournament_monitor/ranking_resolver_test.rb` exists
- [x] Commits a0e6da9b, 2740b27b, 3fbcafc4 exist
- [x] 70 tests pass (0 failures)
- [x] TournamentMonitor reduced to 181 lines
- [x] D-05: PlayerGroupDistributor.distribute_to_group called directly in group_rank

---
*Phase: 14-medium-risk-extractions*
*Completed: 2026-04-10*
