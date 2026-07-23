---
phase: 03-tablemonitor-scoreengine
plan: 01
subsystem: table_monitor
tags: [extraction, poro, score-engine, unit-tests]
dependency_graph:
  requires: []
  provides: [TableMonitor::ScoreEngine PORO with all pure hash mutation methods]
  affects: [app/models/table_monitor.rb]
tech_stack:
  added: []
  patterns: [plain Ruby object (PORO), hash mutation by reference, signal return values]
key_files:
  created:
    - app/models/table_monitor/score_engine.rb
    - test/models/table_monitor/score_engine_test.rb
  modified: []
decisions:
  - "ScoreEngine lives in app/models/table_monitor/ (model collaborator, not a cross-cutting service)"
  - "Signal return values used: :goal_reached, :inning_terminated, :snooker_frame_complete"
  - "innings_history accepts optional gps: [] parameter for player name resolution — keeps ScoreEngine free of AR"
  - "undo_hash / redo_hash implement non-PaperTrail branches only; PaperTrail paths stay in TableMonitor"
  - "recalculate_player_stats accepts save_now: false to allow caller to batch saves"
  - "update_innings_history / delete_inning / insert_inning accept playing_or_set_over: bool to avoid AASM coupling"
metrics:
  duration: "~25 minutes"
  completed_date: "2026-04-09"
  tasks_completed: 2
  files_modified: 2
---

# Phase 03 Plan 01: ScoreEngine PORO Creation Summary

**One-liner:** Pure Ruby ScoreEngine class with 27 hash mutation methods extracted from TableMonitor, plus 69 unit tests validating behavior without database interaction.

## What Was Built

`TableMonitor::ScoreEngine` is a plain Ruby object that receives the live `data` Hash from TableMonitor by reference and mutates it in place. It has zero ActiveRecord, AASM, or broadcast dependencies. The class provides all score computation logic required for Carambus carom billiard matches.

### Files Created

- `/app/models/table_monitor/score_engine.rb` — 1197 lines, 27 methods
- `/test/models/table_monitor/score_engine_test.rb` — 703 lines, 69 tests

## Task Outcomes

### Task 1: ScoreEngine class

27 methods extracted (boundary map from RESEARCH.md fully covered):

**Score input:** `add_n_balls`, `set_n_balls`, `foul_one`, `foul_two`, `balls_left`

**Result computation:** `recompute_result`, `init_lists`

**Undo/Redo (non-PaperTrail):** `undo_hash`, `redo_hash`

**HTML rendering:** `render_innings_list`, `render_last_innings`

**Innings history:** `innings_history`, `update_innings_history`, `increment_inning_points`, `decrement_inning_points`, `delete_inning`, `insert_inning`, `recalculate_player_stats`, `update_player_innings_data`, `calculate_running_totals`

**Snooker:** `initial_red_balls`, `update_snooker_state`, `undo_snooker_ball`, `recalculate_snooker_state_from_protocol`, `snooker_balls_on`, `snooker_remaining_points`

### Task 2: Unit tests

69 tests, 90 assertions. All pass without database. Key coverage:
- Hash mutation by reference (same `object_id` before/after)
- Signal return values (`:goal_reached`, `:inning_terminated`, `nil`)
- All public methods covered with at least one happy-path and one edge-case test
- Snooker methods: `initial_red_balls`, `update_snooker_state`, `snooker_balls_on`, `snooker_remaining_points`, `undo_snooker_ball`, `recalculate_snooker_state_from_protocol`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] innings_history AR coupling**
- **Found during:** Task 1
- **Issue:** `innings_history` in TableMonitor calls `game&.game_participations` for player names. Moving it to ScoreEngine as-is would require an AR reference.
- **Fix:** Added `gps: []` keyword parameter so the caller (TableMonitor) can pass game participations objects. ScoreEngine falls back to "Spieler A"/"Spieler B" when `gps` is empty. Keeps ScoreEngine free of AR.
- **Files modified:** `app/models/table_monitor/score_engine.rb`

**2. [Rule 2 - Missing critical functionality] AASM state check coupling**
- **Found during:** Task 1
- **Issue:** Several methods (`foul_two`, `add_n_balls`, `update_innings_history`, `delete_inning`, `insert_inning`) in the original TM check `playing?` before executing. Moving these checks into ScoreEngine would require an AASM reference.
- **Fix:** Added `playing_or_set_over: bool` parameters to methods that need state awareness. TableMonitor passes the result of `playing? || set_over?`. ScoreEngine itself has no AASM dependency.
- **Files modified:** `app/models/table_monitor/score_engine.rb`

**3. [Rule 1 - Bug] set_n_balls hardcoded `debug = true`**
- **Found during:** Task 1 (Pitfall 4 from RESEARCH.md)
- **Issue:** Line 2046 of TableMonitor had `debug = true` (not `DEBUG`), causing verbose production logging.
- **Fix:** Removed local `debug` variable; replaced all conditional log calls with `Rails.logger.debug { }` block form. Not carried into ScoreEngine.

## Known Stubs

None. ScoreEngine is a pure computation class with no stubs or placeholders.

## Threat Surface Scan

No new network endpoints, auth paths, or trust boundaries introduced. ScoreEngine is an internal PORO collaborator with no external surface.

## Commits

- `fdcde73d` feat(03-01): create TableMonitor::ScoreEngine PORO with all pure hash mutation methods
- `622cfba9` test(03-01): add ScoreEngine unit tests (69 tests, no database)

## Self-Check: PASSED

- `app/models/table_monitor/score_engine.rb` exists ✓
- `test/models/table_monitor/score_engine_test.rb` exists ✓
- Commit `fdcde73d` exists ✓
- Commit `622cfba9` exists ✓
- 69 tests pass, 0 failures ✓
- `save!` count: 0 ✓
- `CableReady` count: 0 ✓
- Method count: 27 (>= 25) ✓
