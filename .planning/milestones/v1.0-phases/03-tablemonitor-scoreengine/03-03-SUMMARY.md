---
phase: 03-tablemonitor-scoreengine
plan: "03"
subsystem: table_monitor
tags: [logging, refactor, gap-closure, TMON-05]
dependency_graph:
  requires: ["03-02"]
  provides: ["TMON-05-complete"]
  affects: ["app/models/table_monitor.rb"]
tech_stack:
  added: []
  patterns: ["Rails.logger.debug { block }", "Rails.logger.error"]
key_files:
  modified:
    - app/models/table_monitor.rb
decisions:
  - "Used Rails.logger.debug { block } form (lazy evaluation) for all trace logging"
  - "Used Rails.logger.error (eager, no block) for all rescue block error logging"
  - "Collapsed duplicate Tournament.logger.info + Rails.logger.info error lines in get_progress_bar_status rescue into single Rails.logger.error"
  - "Converted `elsif debug` guard in evaluate_result to `else` with Rails.logger.debug { block }"
metrics:
  duration_minutes: 20
  completed_date: "2026-04-10T08:29:57Z"
  tasks_completed: 2
  files_modified: 1
---

# Phase 03 Plan 03: DEBUG Guard Conversion Summary

**One-liner:** Converted all 68 `if DEBUG` / `if debug` conditional logging guards in table_monitor.rb to explicit `Rails.logger.debug { block }` and `Rails.logger.error` calls, fully satisfying TMON-05.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Convert all DEBUG/debug guards to Rails.logger calls | 7acf9454 | app/models/table_monitor.rb |
| 2 | Verify characterization tests pass after DEBUG conversion | (verification only) | — |

## What Was Built

Converted every `if DEBUG` / `if debug` guard in `app/models/table_monitor.rb` using two patterns:

**Pattern A — Trace logging (entry markers, variable inspection):**
```ruby
# Before:
if DEBUG
  Rails.logger.info "-----------m6[#{id}]---------->>> method_name <<<---"
end
# After:
Rails.logger.debug { "-----------m6[#{id}]---------->>> method_name <<<---" }
```

**Pattern B — Error logging in rescue blocks:**
```ruby
# Before:
Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
# After:
Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
```

**Removed local variable assignments:**
- Line 632: `# debug = DEBUG` (commented-out line removed)
- Line 633: `debug = false` (removed)
- Line 1924: `debug = true # true` (removed)

**Specific methods converted:** `get_progress_bar_status`, `switch_players`, `set_start_time`, `set_end_time`, `assign_game`, `initialize_game`, `display_name`, `seeding_from`, `evaluate_panel_and_current`, `more_sets?`, `save_current_set`, `get_max_number_of_wins`, `switch_to_next_set`, `evaluate_result`, `start_game`, `revert_players`, `set_player_sequence`, `end_of_set?`, `deep_merge_data!`, `deep_delete!`, `prepare_final_game_result`, `force_next_state`, `reset_table_monitor`, `update_innings_history`

## Verification Results

| Check | Result |
|-------|--------|
| `grep -c "if DEBUG" table_monitor.rb` | 0 |
| `grep -c "if debug" table_monitor.rb` | 0 |
| `grep -c "debug = " table_monitor.rb` | 0 |
| `grep -c "Rails.logger.debug" table_monitor.rb` | 60 |
| `ruby -c table_monitor.rb` | Syntax OK |
| characterization tests (41 runs) | 0 failures, 0 errors |
| score_engine unit tests (69 runs) | 0 failures, 0 errors |
| all characterization tests (58 runs) | 0 failures, 0 errors, 7 skips |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `elsif debug` in evaluate_result needed structural fix**
- **Found during:** Task 1
- **Issue:** The `debug = true` local variable at line 1924 guarded an `elsif debug` branch (not an `if debug`), so simply removing the assignment would leave an `elsif` referencing an undefined variable.
- **Fix:** Removed the `debug = true` line and converted `elsif debug` to `else` with `Rails.logger.debug { block }` inside — preserving the same logging behavior while eliminating the dead variable dependency.
- **Files modified:** app/models/table_monitor.rb
- **Commit:** 7acf9454

**2. [Rule 1 - Bug] Duplicate error logging in get_progress_bar_status rescue**
- **Found during:** Task 1
- **Issue:** The rescue block had both `Tournament.logger.info "ERROR: ..."` (always runs) and `Rails.logger.info "ERROR: ..." if debug` (guarded by local debug variable). After removing `debug = false`, keeping both would produce duplicate error logs.
- **Fix:** Collapsed both into a single `Rails.logger.error "ERROR: ..."` per plan Pattern D instructions.
- **Files modified:** app/models/table_monitor.rb
- **Commit:** 7acf9454

## Known Stubs

None. This plan modifies logging only; no data rendering or UI stubs introduced.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes. Error messages that were previously suppressed in production (logged only when `DEBUG=true`) now always log via `Rails.logger.error` — this is standard practice and was explicitly accepted in the plan's threat model (T-03-01).

## Self-Check: PASSED

- [x] app/models/table_monitor.rb exists and modified
- [x] Commit 7acf9454 exists in git log
- [x] Zero `if DEBUG` guards remain
- [x] Zero `if debug` guards remain
- [x] Zero `debug = ` assignments remain
- [x] Syntax valid
- [x] All characterization tests pass
