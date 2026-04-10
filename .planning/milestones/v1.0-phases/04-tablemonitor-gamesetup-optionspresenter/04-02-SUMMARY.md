---
phase: 04-tablemonitor-gamesetup-optionspresenter
plan: "02"
subsystem: table_monitor
tags: [refactoring, delegation, service-extraction]
dependency_graph:
  requires: ["04-01"]
  provides: ["TableMonitor::GameSetup wired via delegation", "suppress_broadcast flag"]
  affects: ["app/models/table_monitor.rb"]
tech_stack:
  added: []
  patterns: ["thin delegation wrapper", "alias_method shim for backward compatibility"]
key_files:
  modified:
    - path: app/models/table_monitor.rb
      role: "Thin delegation wrappers for start_game and assign_game; suppress_broadcast replaces skip_update_callbacks"
decisions:
  - "Kept initialize_game in model — GameSetup calls @tm.initialize_game externally; plan incorrectly stated 'remove entirely'"
  - "Removed set_player_sequence from model — GameSetup has its own private copy and no external callers exist"
  - "alias_method shim chosen over attr_accessor to preserve 30+ reflex call sites with zero risk"
metrics:
  duration_minutes: 15
  completed_date: "2026-04-10"
  tasks_completed: 2
  files_modified: 1
---

# Phase 04 Plan 02: GameSetup Delegation Wiring Summary

Wire GameSetup delegation into TableMonitor: suppress_broadcast replaces skip_update_callbacks, start_game and assign_game delegate to GameSetup, set_player_sequence removed from model.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Replace skip_update_callbacks with suppress_broadcast + alias shim | 631dc5f4 | app/models/table_monitor.rb |
| 2 | Wire GameSetup delegation and remove extracted method bodies | 73e1029c | app/models/table_monitor.rb |

## What Was Built

### Task 1: suppress_broadcast flag
- Replaced `attr_accessor :skip_update_callbacks` with `attr_writer :suppress_broadcast` + explicit reader (defaults to false)
- Added `alias_method` shim so `skip_update_callbacks=` and `skip_update_callbacks` route to the new flag
- Updated `after_update_commit` lambda to check `suppress_broadcast` instead of `skip_update_callbacks`
- Zero changes required to the 30+ reflex call sites or characterization tests

### Task 2: GameSetup delegation wiring
- `start_game(options_ = {})` replaced with `TableMonitor::GameSetup.call(table_monitor: self, options: options_)`
- `assign_game(game_p)` replaced with `TableMonitor::GameSetup.assign(table_monitor: self, game_participation: game_p)`
- `set_player_sequence` removed from model (GameSetup has its own private copy; no external callers)
- `initialize_game`, `seeding_from`, `switch_players`, `revert_players` retained in model

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Kept initialize_game in model**
- **Found during:** Task 2 analysis
- **Issue:** Plan stated "Remove def initialize_game entirely — it is now a private method inside GameSetup." However, GameSetup calls `@tm.initialize_game` at lines 51 and 84 of game_setup.rb, meaning initialize_game must remain as a public model method.
- **Fix:** Kept initialize_game in model unchanged. Only set_player_sequence was removed (no external callers).
- **Files modified:** app/models/table_monitor.rb (no change needed — kept existing method)
- **Commit:** 73e1029c

## Verification Results

- `ruby -c app/models/table_monitor.rb` — Syntax OK
- `bin/rails test test/characterization/table_monitor_char_test.rb` — 41 runs, 75 assertions, 0 failures
- `bin/rails test test/services/table_monitor/game_setup_test.rb` — 10 runs, 29 assertions, 0 failures
- `wc -l app/models/table_monitor.rb` — 2549 lines (down from 2713, -164 lines)

## Line Count Reduction

The plan projected a 400-500 line reduction from a 2882-line baseline. The actual baseline at execution was 2713 lines (reduced already by Wave 1 plan 01). The reduction achieved in this plan is 164 lines (-6%). The gap from projected reduction is because initialize_game (~193 lines) was kept in the model per the deviation above.

## Known Stubs

None — all delegation wires to fully implemented GameSetup service.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- `app/models/table_monitor.rb` — FOUND (2549 lines)
- Commit 631dc5f4 — FOUND (Task 1)
- Commit 73e1029c — FOUND (Task 2)
- `grep -q "TableMonitor::GameSetup.call" app/models/table_monitor.rb` — FOUND
- `grep -q "TableMonitor::GameSetup.assign" app/models/table_monitor.rb` — FOUND
- `grep -q "alias_method :skip_update_callbacks=, :suppress_broadcast=" app/models/table_monitor.rb` — FOUND
- `grep -q "if suppress_broadcast" app/models/table_monitor.rb` — FOUND
- All characterization and GameSetup tests pass — CONFIRMED
