---
phase: 15-high-risk-extractions
plan: "01"
subsystem: tournament_monitor
tags: [extraction, result-pipeline, db-lock, aasm, service]
dependency_graph:
  requires: []
  provides: [TournamentMonitor::ResultProcessor]
  affects: [app/models/tournament_monitor.rb, lib/tournament_monitor_support.rb, lib/tournament_monitor_state.rb]
tech_stack:
  added: [TournamentMonitor::ResultProcessor]
  patterns: [PORO service with @tournament_monitor accessor, pessimistic DB lock preservation, AASM event delegation]
key_files:
  created:
    - app/services/tournament_monitor/result_processor.rb
    - test/services/tournament_monitor/result_processor_test.rb
  modified:
    - app/models/tournament_monitor.rb
    - lib/tournament_monitor_support.rb
    - lib/tournament_monitor_state.rb
decisions:
  - "ResultProcessor is a PORO (not ApplicationService) — multiple public entry points preclude single .call convention"
  - "write_game_result_data and update_game_participations_for_game added as model delegation wrappers — required by existing characterization tests that call these directly on TournamentMonitor"
  - "game.with_lock DB lock scope preserved exactly — 4 operations inside lock (table_monitor.reload, game.reload, write_game_result_data, game.reload + table_monitor.reload + finish_match!), everything else outside"
  - "AASM events (end_of_tournament!, start_playing_finals!, start_playing_groups!) fire on @tournament_monitor, not self (D-02)"
  - "accumulate_results is public — required by TablePopulator (Plan 15-02) via model delegation"
  - "TournamentMonitor.current_admin used for cattr_accessor access (not self.class.current_admin)"
metrics:
  duration: "~25 minutes"
  completed_date: "2026-04-11"
  tasks_completed: 2
  files_created: 2
  files_modified: 3
  tests_added: 19
  test_results: "81 runs, 309 assertions, 0 failures, 0 errors, 2 skips"
---

# Phase 15 Plan 01: ResultProcessor Extraction Summary

**One-liner:** Extracted 9-method result processing pipeline (report_result, write_game_result_data, finalize_game_result, accumulate_results, add_result_to, update_ranking, update_game_participations, update_game_participations_for_game, write_finale_csv_for_upload) from TournamentMonitor lib modules into TournamentMonitor::ResultProcessor PORO, preserving game.with_lock DB lock scope and AASM event delegation exactly.

## What Was Built

### TournamentMonitor::ResultProcessor (app/services/tournament_monitor/result_processor.rb)

Plain Ruby class following the RankingResolver pattern. Constructor receives a TournamentMonitor instance stored as `@tournament_monitor`. All model operations use the `@tournament_monitor.` prefix — no bare `self` calls for model state.

**Public methods (4):**
- `report_result(table_monitor)` — main result pipeline entry point with `game.with_lock` pessimistic lock
- `accumulate_results` — aggregates GameParticipation results into rankings (also used by TablePopulator via Plan 15-02)
- `update_ranking` — computes final ranking from executor_params RK rules
- `update_game_participations(tabmon)` — delegates to update_game_participations_for_game

**Private methods (5):**
- `write_game_result_data(table_monitor)` — writes TableMonitor data to Game (inside DB lock)
- `finalize_game_result(table_monitor)` — ClubCloud upload, GP updates, KO cleanup (outside lock)
- `update_game_participations_for_game(game, data)` — updates GameParticipation records
- `add_result_to(gp, hash)` — accumulates one GP's results into a rankings hash
- `write_finale_csv_for_upload` — generates CSV and sends result emails

### TournamentMonitor Model Delegation Wrappers (app/models/tournament_monitor.rb)

Six delegation wrappers added after `player_id_from_ranking`:
- `report_result`, `update_game_participations`, `accumulate_results`, `update_ranking` — public wrappers (4 per plan spec)
- `write_game_result_data`, `update_game_participations_for_game` — additional wrappers required by characterization tests that call these directly on the model (see Deviations)

### Lib Module Cleanup

From `lib/tournament_monitor_support.rb` (477 → 0 lines of extracted code):
- Removed: update_game_participations, update_game_participations_for_game, accumulate_results, add_result_to, report_result, update_ranking, write_finale_csv_for_upload

From `lib/tournament_monitor_state.rb`:
- Removed: write_game_result_data, finalize_game_result

## Test Results

| Suite | Runs | Assertions | Failures | Errors | Skips |
|-------|------|-----------|----------|--------|-------|
| ResultProcessor unit tests | 19 | 48 | 0 | 0 | 2 |
| Characterization (t04 + t06 + ko) | 62 | 261 | 0 | 0 | 0 |
| **Combined** | **81** | **309** | **0** | **0** | **2** |

The 2 skips are expected: tests needing tournament plans with RK rules or local games that don't exist in all fixture states.

## Commits

| Hash | Description |
|------|-------------|
| 0d4324e3 | feat(15-01): extract ResultProcessor service from TournamentMonitor lib modules |
| 9ee757e4 | feat(15-01): wire ResultProcessor delegation in TournamentMonitor + remove lib module methods |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Added delegation wrappers for write_game_result_data and update_game_participations_for_game on TournamentMonitor model**

- **Found during:** Task 2 (after removing lib methods, running characterization tests)
- **Issue:** `tournament_monitor_t06_test.rb` calls `@tm.write_game_result_data(table_monitor)` and `@tm.update_game_participations_for_game(game, data)` directly on the model — 4 test failures
- **Fix:** Added delegation wrappers on TournamentMonitor that call `ResultProcessor.new(self).send(:method_name, ...)` — preserves test interface while routing to the service
- **Files modified:** app/models/tournament_monitor.rb
- **Commit:** 9ee757e4

The plan specified 4 delegation wrappers; 6 were needed to preserve the existing characterization test interface. This is correct behavior per the plan constraint "All Phase 11-12 characterization tests pass unchanged after extraction."

## Known Stubs

None — all methods are fully implemented with real logic from the original lib modules.

## Threat Flags

No new security surface introduced. The `game.with_lock` DB lock scope was preserved exactly — T-15-01 mitigated.

## Self-Check: PASSED

- app/services/tournament_monitor/result_processor.rb — FOUND
- test/services/tournament_monitor/result_processor_test.rb — FOUND
- Commit 0d4324e3 — FOUND
- Commit 9ee757e4 — FOUND
