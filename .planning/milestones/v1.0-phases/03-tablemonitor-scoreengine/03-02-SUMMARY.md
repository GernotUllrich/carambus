---
phase: "03"
plan: "02"
subsystem: TableMonitor
tags: [delegation, score-engine, debug-cleanup, refactor]
dependency_graph:
  requires: ["03-01"]
  provides: ["TableMonitor delegates all hash-mutation scoring to ScoreEngine"]
  affects: [TableMonitor, TableMonitor::ScoreEngine]
tech_stack:
  added: []
  patterns:
    - "Lazy accessor pattern: @score_engine ||= ScoreEngine.new(data, discipline:)"
    - "reload override to reset @score_engine = nil"
    - "Signal-return delegation: ScoreEngine returns symbols, TM wrapper handles side effects"
    - "Rails.logger.debug { block } replaces if DEBUG guarded info logging"
key_files:
  modified:
    - app/models/table_monitor.rb
  created: []
decisions:
  - "Keep playing?/set_over? guards in TableMonitor wrappers (not in ScoreEngine) — TM owns AR lifecycle"
  - "score_engine lazy accessor placed in private section after the single private keyword"
  - "Old innings_history implementation (with INNINGS_HISTORY_DEBUG warn blocks) replaced by delegation to ScoreEngine"
  - "DEBUG constant and all if DEBUG / debug = DEBUG patterns fully removed; converted to Rails.logger.debug { } blocks"
  - "Malformed backslash-continuation debug strings fixed inline during conversion"
metrics:
  duration: "~2 sessions (context overflow split)"
  completed_date: "2026-04-09"
  tasks_completed: 2
  files_modified: 1
---

# Phase 03 Plan 02: ScoreEngine Delegation Wiring Summary

**One-liner:** Thin delegation wrappers in TableMonitor replace ~646 lines of hash-mutation logic by forwarding to TableMonitor::ScoreEngine, with DEBUG constant fully removed.

## What Was Built

### Task 1 — Wire ScoreEngine Delegation

All pure hash-mutation methods in `TableMonitor` were replaced with thin delegation wrappers calling the corresponding `TableMonitor::ScoreEngine` methods. The ScoreEngine receives the `data` Hash by reference and mutates it in place; the TM wrapper handles persistence (`data_will_change! + save!`) and AASM side effects.

**Methods delegated:**
- `add_n_balls` — delegates to `score_engine.add_n_balls`; handles `:goal_reached` / `:snooker_frame_complete` / `nil` signal returns
- `set_n_balls` — delegates to `score_engine.set_n_balls`; handles `:goal_reached` signal
- `foul_one` — delegates to `score_engine.foul_one`; handles `:inning_terminated` / `nil` signals
- `foul_two` — delegates to `score_engine.foul_two`; always terminates inning
- `undo` — delegates hash branch to `score_engine.undo_hash`; PaperTrail branches stay in TM
- `redo` — delegates hash branch to `score_engine.redo_hash`; handles `:inning_terminated` signal
- `innings_history` — delegates to `score_engine.innings_history(gps: gps)`; old 185-line implementation removed
- `update_innings_history` — delegates with `playing_or_set_over:` flag; TM handles persistence
- `increment_inning_points` — delegates; TM handles persistence
- `decrement_inning_points` — delegates; TM handles persistence
- `delete_inning` — delegates with `playing_or_set_over:` flag; TM handles persistence
- `insert_inning` — delegates with `playing_or_set_over: true`; TM handles persistence
- `recalculate_player_stats` — delegates; TM handles `data_will_change! + save!` when `save_now: true`
- `update_player_innings_data` — delegates; TM handles persistence
- `calculate_running_totals` — one-line delegation, pure computation

**Added:**
- `score_engine` private lazy accessor: `@score_engine ||= TableMonitor::ScoreEngine.new(data, discipline: discipline)`
- `reload` override: resets `@score_engine = nil` then calls `super`

**DEBUG constant removal:**
- Removed `DEBUG = Rails.env != "production"` constant
- Converted all `Rails.logger.info "..." if DEBUG` → `Rails.logger.debug { "..." }`
- Converted all `Rails.logger.info "ERROR:..." if DEBUG` → `Rails.logger.error "..."` (always log errors)
- Removed `debug = DEBUG` / `debug = true` / `debug = false` local variable assignments
- Converted all `if debug ... end` multi-line blocks to `Rails.logger.debug { }` single-line calls
- Fixed malformed backslash-continuation strings that resulted from the multi-line `if DEBUG` block conversion

### Task 2 — Verification

| Check | Result |
|-------|--------|
| `ruby -c app/models/table_monitor.rb` | Syntax OK |
| `bin/rails test test/models/table_monitor/score_engine_test.rb` | 69 runs, 90 assertions, 0 failures |
| `bin/rails test test/characterization/table_monitor_char_test.rb` | 41 runs, 75 assertions, 0 failures |
| `bin/rails test test/characterization/` (all char tests) | 58 runs, 97 assertions, 0 failures, 7 skips |
| Line count | 3903 → 3257 (−646 lines, −16.6%) |

The 7 skips are pre-existing VCR cassette deferrals (ClubCloud credentials not in test env) documented in STATE.md.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Old innings_history method not replaced in previous session**
- **Found during:** Task 1 verification — `def innings_history` still existed at line 3112 with full 185-line implementation
- **Issue:** Previous session had replaced it but the change did not persist (method was in private section below other new wrappers)
- **Fix:** Replaced with 12-line delegation wrapper calling `score_engine.innings_history(gps: gps)`
- **Files modified:** app/models/table_monitor.rb

**2. [Rule 1 - Bug] Malformed debug lines from backslash-continuation multi-line strings**
- **Found during:** Syntax check after bulk conversion
- **Issue:** Multi-line `if DEBUG` blocks with backslash-continued strings converted incorrectly, leaving unclosed string literals like `Rails.logger.debug { "...<<\ }` followed by orphaned `--...--"` continuation lines
- **Fix:** Fixed 8 malformed lines individually; for `render_last_innings`, `get_progress_bar_status`, `foul_two`, `foul_one`, `assign_game`, `seeding_from`, `balls_left`, `add_n_balls`, `evaluate_panel_and_current`, `set_n_balls` — collapsed multi-line strings to single-line equivalents
- **Files modified:** app/models/table_monitor.rb

**3. [Rule 1 - Bug] Duplicate STATE_CHANGED debug log (both Tournament.logger and Rails.logger)**
- **Found during:** Conversion of `if state_changed?` block that had both loggers guarded by `if DEBUG`
- **Issue:** When both lines were converted to `Rails.logger.debug { }`, they became identical duplicate calls
- **Fix:** Kept only one `Rails.logger.debug { }` call (removed duplicate Tournament.logger line)
- **Files modified:** app/models/table_monitor.rb

**4. [Rule 2 - Missing] score_engine accessor and reload override absent**
- **Found during:** Post-conversion check — `score_engine` called throughout but accessor not defined
- **Issue:** Previous session (context overflow) had not written the accessor to the file
- **Fix:** Added `score_engine` lazy accessor and `reload` override to private section
- **Files modified:** app/models/table_monitor.rb

## Known Stubs

None. All delegation wrappers call into live ScoreEngine code.

## Threat Flags

None. This is a pure refactoring — no new network endpoints, auth paths, or schema changes.

## Self-Check: PASSED

- SUMMARY.md created: FOUND
- Task 1 commit 4997fe40: FOUND
- app/models/table_monitor.rb: FOUND (3257 lines)
- ScoreEngine tests: 69 runs, 0 failures
- Characterization tests: 41 runs, 0 failures
- Syntax check: OK
