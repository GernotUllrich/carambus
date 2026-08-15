---
phase: 01-characterization-tests-hardening
plan: 03
subsystem: testing
tags: [minitest, characterization-tests, table-monitor, activejob, end-to-end, speed-branches]

requires:
  - phase: 01-01
    provides: test/characterization/ directory, 39 TableMonitor characterization tests, capture_enqueued_jobs helper

provides:
  - 41 passing TableMonitor characterization tests (was 39) — adds end-to-end ultra_fast and simple speed branch coverage
  - VERIFICATION.md SC-1 gap closed: all three after_update_commit speed branches now have end-to-end tests exercising the full before_save -> log_state_change -> @collected_data_changes -> routing pipeline

affects:
  - phase-03 (TableMonitor extraction is now fully pinned: predicate logic, data pipeline, and job routing all characterized)

tech-stack:
  added: []
  patterns:
    - "TableMonitor.find(tm.id) after create! to get fresh instance — clears @collected_data_changes/@collected_changes residue from before_save log_state_change on create"
    - "End-to-end speed branch test: update!(data: ...) with fresh instance triggers real before_save -> after_update_commit pipeline without instance_variable_set bypasses"

key-files:
  created: []
  modified:
    - test/characterization/table_monitor_char_test.rb

key-decisions:
  - "Use TableMonitor.find(id) after create! instead of the created instance: before_save :log_state_change fires on create! and populates @collected_data_changes/@collected_changes on the instance object. Since after_update_commit does not fire on create!, these instance variables are never cleared. Using find() returns a fresh object with nil instance variables — the correct precondition for end-to-end update! tests."
  - "updated_at is NOT in changes during before_save: Rails sets updated_at after before_save callbacks run, so changes.except('data') is empty when only data changes. The @collected_changes stays empty, allowing ultra_fast/simple predicates to return true."

patterns-established:
  - "Fresh instance via find() for end-to-end update tests — prevents log_state_change residue from create! polluting the update test"

requirements-completed: [TEST-01]

duration: 12min
completed: 2026-04-09
---

# Phase 01 Plan 03: End-to-End Speed Branch Characterization Tests Summary

**Two end-to-end tests close the VERIFICATION.md SC-1 gap: ultra_fast ("score_data") and simple ("player_score_panel") after_update_commit branches are now pinned through the full before_save -> log_state_change -> @collected_data_changes -> routing pipeline**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-04-09T20:46:00Z
- **Completed:** 2026-04-09T20:58:28Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added two end-to-end characterization tests to `test/characterization/table_monitor_char_test.rb`
- Test 1 (`ultra_fast`): creates a TableMonitor with `state: "playing"` and full player data, reloads via `find()`, calls `update!(data: ...)` changing only `innings_redo_list` for one player, asserts `TableMonitorJob` enqueued with `"score_data"` and `player: "playera"`
- Test 2 (`simple`): same setup, changes `result` for one player (not just `innings_redo_list`), asserts `"player_score_panel"` job enqueued and no `"score_data"` job (confirms ultra_fast did not fire)
- Both tests exercise the real `before_save :log_state_change` -> `@collected_data_changes` population -> `after_update_commit` routing — no `instance_variable_set` bypasses
- Test count increased from 39 to 41, 75 assertions

## Task Commits

1. **Task 1: Add end-to-end speed branch tests** - `6b372dfd` (test)

## Files Created/Modified

- `test/characterization/table_monitor_char_test.rb` — 2 new end-to-end speed branch tests added after line 367 (after predicate tests, before section D)

## Decisions Made

- **Fresh instance via `find()` required:** After `create!(state: "playing", data: {...})`, the `before_save :log_state_change` callback fires and populates `@collected_data_changes` and `@collected_changes` on the Ruby object. Because `after_update_commit` does not fire on create, these instance variables are never cleared. If the same object is then used for `update!`, `@collected_data_changes ||= []` is a no-op (not nil), and the second `log_state_change` call appends to the existing arrays. The `@collected_changes` would then contain `[{"state" => [nil, "playing"]}]` from the create, making both speed predicates return false. Calling `TableMonitor.find(tm.id)` returns a fresh ActiveRecord instance with all instance variables at their default nil state — the correct precondition for these tests.

- **`updated_at` NOT in `changes` during `before_save`:** The plan's assumption that `@collected_changes` stays empty when only `data` changes was verified correct. Rails sets `updated_at` via the timestamp mechanism after `before_save` callbacks run, so `changes` in `log_state_change` only contains `"data"` on a pure data update. `changes.except('data')` is empty, leaving `@collected_changes` empty — which is required for the speed predicates to return true.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fresh instance required to avoid log_state_change residue from create!**
- **Found during:** Task 1 (first test run)
- **Issue:** After `create!`, `@collected_data_changes` contained `[{initial_diff}]` and `@collected_changes` contained `[{"state" => [nil, "playing"]}]` from the create's `before_save`. Since `after_update_commit` does not fire on create, these were never cleared. The subsequent `update!` appended to these arrays, making both `ultra_fast_score_update?` and `simple_score_update?` return false (due to `@collected_changes.present?` guard). The teaser + slow path (`""`) fired instead of the fast paths.
- **Fix:** Changed `tm = TableMonitor.create!(...)` to `tm = TableMonitor.find(TableMonitor.create!(...).id)`. The `find()` call returns a fresh object with nil instance variables.
- **Files modified:** test/characterization/table_monitor_char_test.rb
- **Commit:** 6b372dfd

---

**Total deviations:** 1 auto-fixed (test setup bug)
**Impact on plan:** Fix was necessary and minimal — one-line change per test. No scope creep. All acceptance criteria met.

## Known Stubs

None.

## Threat Flags

None — test-only change, no production code modified.

## Self-Check: PASSED

- `test/characterization/table_monitor_char_test.rb` — FOUND (modified)
- Commit `6b372dfd` — FOUND (`git log --oneline | grep 6b372dfd`)
- 41 tests, 0 failures confirmed
- `score_data` appears 10 times in test file
- `player_score_panel` appears 6 times in test file

---
*Phase: 01-characterization-tests-hardening*
*Completed: 2026-04-09*
