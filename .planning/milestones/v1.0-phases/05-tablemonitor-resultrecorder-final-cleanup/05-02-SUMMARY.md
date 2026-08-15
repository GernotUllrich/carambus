---
phase: 05-tablemonitor-resultrecorder-final-cleanup
plan: "02"
subsystem: table_monitor
tags: [refactoring, delegation, score-engine, game-setup, cleanup]
dependency_graph:
  requires: ["05-01"]
  provides: ["05-03"]
  affects: [table_monitor, score_engine, game_setup, game_protocol_reflex]
tech_stack:
  added: []
  patterns:
    - "Thin AR wrapper pattern: state guard -> score_engine.method -> data_will_change! -> save!"
    - "ScoreEngine receives playing: kwarg for state checks (matching delete_inning pattern)"
    - "GameSetup class method receives table_monitor: kwarg for initialize_game body"
key_files:
  created: []
  modified:
    - app/models/table_monitor.rb
    - app/models/table_monitor/score_engine.rb
    - app/services/table_monitor/game_setup.rb
    - app/reflexes/game_protocol_reflex.rb
decisions:
  - "ScoreEngine#terminate_inning_data accepts playing: kwarg (not @tm reference) — consistent with existing delete_inning(playing_or_set_over:) pattern; ScoreEngine remains a pure hash collaborator with no AR dependency"
  - "GameSetup.initialize_game uses local tm variable (not @tm) since it is a class method — avoids instance variable naming confusion"
  - "recalculate_player_stats removed from TableMonitor entirely — all callers (increment/decrement/delete/insert inning) were already being replaced; ScoreEngine handles recalculation internally"
  - "Line count target of 1550 was not met (actual: 1611) — plan estimate was off; all behavioral delegations are complete and no duplicate implementation remains"
metrics:
  duration_minutes: 35
  completed_date: "2026-04-09"
  tasks_completed: 3
  tasks_total: 3
  files_changed: 4
---

# Phase 05 Plan 02: ScoreEngine Delegation and Debug Cleanup Summary

Wire 8 ScoreEngine delegation wrappers, delegate initialize_game to GameSetup and terminate_current_inning hash mutation to ScoreEngine, and remove 19 dead TableMonitor::DEBUG references from game_protocol_reflex.rb.

## What Was Built

### Task 1: 8 ScoreEngine delegation wrappers (commit 7c927587)

Replaced 7 full method implementations in TableMonitor with thin AR wrappers delegating to `score_engine.*`:

- `update_innings_history` — delegates with `playing_or_set_over:` kwarg; saves if success
- `increment_inning_points` — state guard + delegate + `data_will_change!; save!`
- `decrement_inning_points` — same pattern
- `delete_inning` — state guard + delegate + save on success
- `insert_inning` — state guard + delegate + save
- `update_player_innings_data` (private) — delegate + save
- `calculate_running_totals` (private) — pure delegation, no save (returns computed values)

`recalculate_player_stats` was removed entirely from TableMonitor — it was private and only called from the methods being replaced. ScoreEngine handles recalculation internally.

Line reduction: 2250 → 1893 lines (-357 lines).

### Task 2: Clean up TableMonitor::DEBUG references (commit 0a64f933)

Replaced all 19 `Rails.logger.info "..." if TableMonitor::DEBUG` guards in `game_protocol_reflex.rb` with `Rails.logger.debug { "..." }` blocks. The `TableMonitor::DEBUG` constant was removed in Phase 3 (TMON-05), creating a latent NameError risk. All messages, emoji prefixes, and interpolations preserved exactly.

### Task 3: initialize_game and terminate_current_inning delegations (commit 8a550a14)

**Part A: initialize_game → GameSetup**

Moved the full ~193-line `initialize_game` body from TableMonitor into a new `GameSetup.initialize_game(table_monitor:)` class method. The method adapts all bare method calls (`data`, `deep_merge_data!`, `tournament_monitor`, etc.) to `tm.` prefix. TableMonitor keeps a 3-line thin wrapper.

The two existing `@tm.initialize_game` calls in GameSetup (`perform_assign` line 51, `perform_start_game` line 84) remain unchanged — they route through the TM wrapper, which is correct behavior.

**Part B: terminate_current_inning → ScoreEngine#terminate_inning_data**

Added `ScoreEngine#terminate_inning_data(player, playing:)` containing the full hash mutation logic (~95 lines). The `playing:` kwarg follows the established pattern from `delete_inning(playing_or_set_over:)`. ScoreEngine has direct access to `init_lists` and `recompute_result` internally. Returns `:ok` on success, `:game_finished` when innings_goal reached. TableMonitor keeps a transaction-wrapped AR wrapper that persists and calls `evaluate_result`.

Line reduction after Task 3: 1893 → 1611 lines (-282 lines).

## Deviations from Plan

### Auto-fixed Issues

None — plan executed as written with one noted variance.

### Line Count Deviation (documented, not a bug)

**Found during:** Task 3 completion check
**Issue:** Plan projected TableMonitor at ~1535 lines after all tasks. Actual result is 1611 lines.
**Cause:** The plan's line count estimate was calculated against the pre-Task-1 file (2250 lines) and underestimated method header/comment overhead. The 61-line overage (1611 vs 1550 target) does not reflect any missing delegation — all 8 ScoreEngine methods are delegated, recalculate_player_stats is removed, initialize_game and terminate_current_inning hash mutations are moved.
**Impact:** No behavioral impact. All duplicate implementations removed. Remaining code is legitimately TableMonitor-owned (AASM callbacks, state queries, AR lifecycle, broadcasting, result evaluation).

## Known Stubs

None. All delegation wrappers call live ScoreEngine/GameSetup methods.

## Threat Flags

None. No new network endpoints or auth paths introduced. ScoreEngine remains an internal pure-hash collaborator. GameSetup is internal-only with no new data exposure surface.

## Verification

```
bin/rails test test/characterization/table_monitor_char_test.rb \
  test/models/table_monitor/score_engine_test.rb \
  test/services/table_monitor/game_setup_test.rb
# 120 runs, 194 assertions, 0 failures, 0 errors, 0 skips
```

Acceptance criteria met:
- score_engine.update_innings_history present in TM: YES
- score_engine.increment_inning_points present: YES
- score_engine.decrement_inning_points present: YES
- score_engine.delete_inning present: YES
- score_engine.insert_inning present: YES
- score_engine.calculate_running_totals present: YES
- score_engine.update_player_innings_data present: YES
- def recalculate_player_stats absent from TM: YES (removed)
- TableMonitor::DEBUG count in game_protocol_reflex.rb: 0
- GameSetup.initialize_game class method present: YES
- ScoreEngine#terminate_inning_data present: YES
- score_engine.terminate_inning_data in TM: YES
- All characterization tests pass: YES (120 runs, 0 failures)
- Line count under 1550: NO — actual 1611 (deviation documented above)

## Self-Check: PASSED
