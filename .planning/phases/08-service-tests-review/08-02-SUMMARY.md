---
phase: 08-service-tests-review
plan: "02"
subsystem: testing
tags: [minitest, table_monitor, game_setup, result_recorder, assertions]

requires:
  - phase: 06-audit-baseline-standards
    provides: Audit report identifying D-06/D-07/D-08 weak assertion cases

provides:
  - Strengthened game_id assertion in game_setup_test.rb (assert_equal Game.last.id vs assert_not_nil)
  - Post-condition assertion in result_recorder_test.rb Test 1 (state=set_over, panel_state=protocol_final)
  - Post-condition assertions in result_recorder_test.rb Test 7 (state=playing after switch_to_next_set, game_id unchanged)

affects: [08-service-tests-review]

tech-stack:
  added: []
  patterns:
    - "Post-condition assertions after assert_nothing_raised blocks verify actual state transitions"
    - "Use Game.last.id after assert_difference to verify exact record created"

key-files:
  created: []
  modified:
    - test/services/table_monitor/game_setup_test.rb
    - test/services/table_monitor/result_recorder_test.rb

key-decisions:
  - "game_setup_test.rb: added assert_equal Game.last.id, @tm.game_id after assert_difference block to verify the created game ID, not just presence"
  - "result_recorder_test.rb Test 1: post-condition asserts state=set_over and panel_state=protocol_final, reflecting actual evaluate_result path (balls_goal reached, single set, was_playing)"
  - "result_recorder_test.rb Test 7: post-condition asserts state=playing (automatic_next_set=true causes switch_to_next_set, not acknowledge) and game_id unchanged; save_current_set/get_max_number_of_wins stubs are no-ops since ResultRecorder calls perform_* methods directly on self, not on @tm"

patterns-established:
  - "Reload @tm after assert_nothing_raised and assert on AASM state to verify evaluate_result path taken"

requirements-completed: [SRVC-01]

duration: 15min
completed: 2026-04-10
---

# Phase 08 Plan 02: TableMonitor Service Test Assertion Strengthening Summary

**3 presence-only and sole-assertion weak spots fixed in GameSetup and ResultRecorder tests — game_id now verified by value; evaluate_result path confirmed via state and panel_state assertions**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-10T15:30:00Z
- **Completed:** 2026-04-10T15:45:00Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments

- game_setup_test.rb Test 1: replaced sole `assert_not_nil @tm.game_id` with additional `assert_equal Game.last.id, @tm.game_id` — verifies the exact created game, not just presence
- result_recorder_test.rb Test 1: added `@tm.reload; assert_equal "set_over", @tm.state; assert_equal "protocol_final", @tm.panel_state` — confirms evaluate_result took the non-simple-set end_of_set path
- result_recorder_test.rb Test 7: added `@tm.reload; assert_equal "playing", @tm.state; assert_equal @game.id, @tm.game_id` — confirms switch_to_next_set fired (automatic_next_set=true) and game association intact

## Task Commits

1. **Task 1: Strengthen 3 weak assertions in TableMonitor service tests** - `5424151b` (fix)

## Files Created/Modified

- `test/services/table_monitor/game_setup_test.rb` — Added `assert_equal Game.last.id, @tm.game_id` after assert_difference block (line 98)
- `test/services/table_monitor/result_recorder_test.rb` — Added post-condition assertions after assert_nothing_raised in Tests 1 and 7

## Decisions Made

- Discovered that `automatic_next_set` always returns `true` in TableMonitor (hardcoded), meaning Test 7's flow calls `perform_switch_to_next_set` (state → `playing`), not `acknowledge_result!`. The post-condition assertion was initially wrong (`set_over`) and corrected to `playing` after running the tests.
- The stubs in Test 7 (`save_current_set`, `get_max_number_of_wins`) stub methods on `@tm` but ResultRecorder calls `perform_save_current_set` and `perform_get_max_number_of_wins` on itself — the stubs are effectively no-ops. This was pre-existing test design; not changed since plan scope is limited to adding post-condition assertions only.

## Deviations from Plan

None — plan executed exactly as written, with one correction iteration after initial test run revealed incorrect state assumption for Test 7.

## Issues Encountered

- First run: Test 7 post-condition asserted `"set_over"` but actual state was `"playing"`. Root cause: `automatic_next_set` always returns `true`, so `perform_switch_to_next_set` fires (sets state to `playing`) rather than `acknowledge_result!`. Fixed by correcting the expected state value to `"playing"`.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- All 3 audit-identified weak assertions (D-07, D-08) in TableMonitor service tests are resolved
- 19 tests pass, 58 assertions
- Phase 08 plan 02 complete; phase 08 (service-tests-review) is now complete

---
*Phase: 08-service-tests-review*
*Completed: 2026-04-10*
