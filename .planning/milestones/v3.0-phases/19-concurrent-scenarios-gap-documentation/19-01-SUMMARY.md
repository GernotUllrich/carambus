---
phase: 19-concurrent-scenarios-gap-documentation
plan: "01"
subsystem: testing
tags: [capybara, selenium, actioncable, cable-ready, table-monitor, isolation, concurrent, multi-session]

requires:
  - phase: 18-core-isolation-tests
    provides: "Two-session isolation test infrastructure: in_session helper, console.warn DOM counter, JS filter verification pattern"

provides:
  - "CONC-01: rapid-fire 6-iteration alternating broadcast test proving no bleed under high-frequency load"
  - "CONC-02: three-session all-pairs isolation test verifying all six cross-table broadcast directions"
  - "Inline third TableMonitor creation pattern (TM-C, id: 50_000_003) with full FK chain"

affects: [19-02-gap-report, future-broadcast-isolation-extensions]

tech-stack:
  added: []
  patterns:
    - "Rapid-fire simulation: update_columns(state: 'ready') + TableMonitorJob.perform_now in tight alternating loop (avoids AASM::InvalidTransition)"
    - "Three-session Capybara pattern: [:scoreboard_a, :scoreboard_b, :scoreboard_c].zip([@tm_a, @tm_b, @tm_c]).each { |s, tm| in_session(s) { ... } }"
    - "Inline inline TM creation: find_or_create_by!(id:) + update_columns for NOT NULL columns + Table FK chain"

key-files:
  created: []
  modified:
    - test/system/table_monitor_isolation_test.rb

key-decisions:
  - "Extended existing table_monitor_isolation_test.rb rather than creating a separate file (shared setup, same fixture basis)"
  - "Used local variable rapid_fire_count = 6 (not a constant) to avoid Minitest constant scope issues"
  - "Placed setup/teardown additions in the shared setup block — both CONC-01 and CONC-02 benefit from @tm_c existence"
  - "Committed Tasks 1 and 2 in a single commit because setup/teardown changes are prerequisite to both tests"

patterns-established:
  - "CONC rapid-fire: even iterations -> TM-A, odd iterations -> TM-B; update_columns resets state before each perform_now"
  - "Three-session all-pairs: fire each TM once, positive assert on owner session, negative assert on other two with sleep + counter check"
  - "Inline third TM FK chain: TableMonitor.find_or_create_by! + update_columns + Table.find_or_create_by! + Game.find_or_create_by!"

requirements-completed: [CONC-01, CONC-02]

duration: ~35min
completed: 2026-04-11
---

# Phase 19 Plan 01: Concurrent Scenarios Gap Documentation Summary

**Six rapid-fire alternating broadcasts and three simultaneous browser sessions all prove zero broadcast bleed via JS filter counter verification**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-04-11T17:45:00Z
- **Completed:** 2026-04-11T18:20:00Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Added CONC-01 test: 6-iteration rapid-fire loop alternating TM-A/TM-B broadcasts with two sessions open; filter counter confirms 3+ preventions per session, no DOM bleed detected
- Added CONC-02 test: three simultaneous browser sessions on TM-A, TM-B, TM-C; all six cross-table directions (A→B, A→C, B→A, B→C, C→A, C→B) verified isolated
- Extended setup/teardown with inline third TableMonitor creation (50_000_003) using full FK chain (TableMonitor → Table → Location + Game)
- Full suite: 5 isolation tests + 1 smoke test = 6 runs, 49 assertions, 0 failures

## Task Commits

Both tasks committed atomically together (setup/teardown changes are shared prerequisites):

1. **Tasks 1 + 2: CONC-01 + CONC-02 + setup/teardown** - `613f1fdb` (test)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `test/system/table_monitor_isolation_test.rb` - Added CONC-01 and CONC-02 test methods; extended setup/teardown with third TM inline creation

## Decisions Made

- Extended `table_monitor_isolation_test.rb` rather than creating a new file — the new tests share the same fixture basis, setup block, and helper pattern as the existing ISOL tests.
- Used local variable `rapid_fire_count = 6` instead of a class-level constant (`RAPID_FIRE_COUNT`) to avoid Ruby constant scoping ambiguity in Minitest.
- Third TableMonitor (50_000_003) created inline in the shared `setup` block (not in a fixture file) so both CONC-01 and CONC-02 benefit and teardown is centralized.
- Committed Tasks 1 and 2 together because the setup/teardown changes adding @tm_c/@table_c/@game_c are a prerequisite for the CONC-02 test — splitting would have resulted in a broken intermediate state.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Applied update_columns after find_or_create_by! for third TM**
- **Found during:** Task 2 (CONC-02 implementation)
- **Issue:** The plan's setup code snippet used `find_or_create_by!(id: 50_000_003)` without a block, relying on `update_columns` afterward. This is the correct idempotent pattern for NOT NULL columns but the plan's snippet lacked the `ip_address` field in update_columns.
- **Fix:** Added `ip_address: "192.168.1.3"` to the `update_columns` call to match the fixture pattern for `:one` and `:two`.
- **Files modified:** test/system/table_monitor_isolation_test.rb
- **Verification:** Test suite ran 6 runs 0 failures
- **Committed in:** 613f1fdb

---

**Total deviations:** 1 auto-fixed (1 missing critical — minor field omission)
**Impact on plan:** No scope creep. Fix ensures the third TM's ip_address column is explicitly set on both create and find paths.

## Issues Encountered

- Worktree environment cannot run `bin/rails test` standalone (no `config/database.yml` visible from worktree path). Resolved by running tests from the main repo with absolute paths to the worktree test file: `bin/rails test /absolute/path/to/worktree/test/system/...rb`.
- The `-n` filter `"test_CONC-01"` did not match because test names contain em-dashes and special characters. Ran the full file instead to verify all 5 tests pass.

## User Setup Required

None — test-only changes, no external service configuration required.

## Next Phase Readiness

- CONC-01 and CONC-02 both passing — concurrent scenario verification complete
- Ready for Plan 19-02: DOC-01 gap report (`BROADCAST-GAP-REPORT.md`) documenting all Phase 17-19 findings
- All six cross-table broadcast directions are now verified isolated under concurrent load

## Self-Check

### Files

- [x] `test/system/table_monitor_isolation_test.rb` - FOUND and MODIFIED (234 lines added)
- [x] `.planning/phases/19-concurrent-scenarios-gap-documentation/19-01-SUMMARY.md` - this file

### Commits

- [x] `613f1fdb` - test(19-01): add CONC-01 rapid-fire AASM transitions isolation test

### Test Results

- 5 isolation tests + 1 smoke test: 6 runs, 49 assertions, 0 failures, 0 errors — PASS
- CONC-01 test method: exists, passes (confirmed in verbose run)
- CONC-02 test method: exists, passes (confirmed in verbose run)

## Self-Check: PASSED

---
*Phase: 19-concurrent-scenarios-gap-documentation*
*Completed: 2026-04-11*
