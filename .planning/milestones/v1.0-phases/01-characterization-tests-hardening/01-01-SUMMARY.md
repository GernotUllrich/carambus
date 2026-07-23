---
phase: 01-characterization-tests-hardening
plan: 01
subsystem: testing
tags: [minitest, aasm, characterization-tests, table-monitor, party-monitor, activejob]

requires: []
provides:
  - test/characterization/ directory with Rake task for isolated characterization test runs
  - 39 passing TableMonitor characterization tests pinning state machine, callbacks, and after_update_commit branches
  - AASM whiny_transitions: true enabled in TableMonitor (silent guard failures now surface as errors)
  - Explicit Sidekiq::Testing.fake! in test_helper for deterministic job assertions
affects:
  - 01-02 (RegionCc characterization tests use same test/characterization/ infrastructure)
  - phase-03 (TableMonitor extraction relies on these tests as safety net)
  - phase-05 (ResultRecorder extraction needs AASM callback tests as guard)

tech-stack:
  added:
    - "Rails 7.2 native after_commit in transactional tests (no gem needed — confirmed incompatible test_after_commit gem removed)"
  patterns:
    - "Characterization tests in test/characterization/ — separate from unit tests, run via bin/rails test test/characterization/"
    - "ApplicationRecord.stub(:local_server?, bool) for after_update_commit branch isolation"
    - "instance.stub(:get_options!, nil) to isolate job-enqueueing assertions from table/location setup"
    - "update_columns for bypassing callbacks when setting up precondition state"
    - "capture_enqueued_jobs helper for inspecting enqueued job args"

key-files:
  created:
    - test/characterization/table_monitor_char_test.rb
  modified:
    - Gemfile
    - Gemfile.lock
    - app/models/table_monitor.rb
    - test/test_helper.rb
    - lib/tasks/test.rake

key-decisions:
  - "test_after_commit gem is incompatible with Rails 5+ (raises error on load); removed — Rails 7.2 fires after_commit natively"
  - "AASM whiny_transitions: true added to TableMonitor; zero test regressions (31 existing failures/107 errors are pre-existing unrelated bugs)"
  - "PartyMonitor is NOT an STI subclass of TableMonitor — it has its own table (party_monitors); plan description was incorrect"
  - "after_update_commit default path enqueues 3 jobs (table_scores + teaser + full scoreboard), not 2 — no early return between relevant_keys block and slow path"
  - "get_options! stubbed in after_update_commit branch tests to avoid table.location nil crash when no Table associated"

patterns-established:
  - "Characterization test naming: {model_name}_char_test.rb in test/characterization/"
  - "setup/teardown resets all cattr_accessors to nil to prevent state leaks between tests"
  - "Use update_columns (bypasses callbacks) to set up precondition state without side effects"

requirements-completed: [TEST-01]

duration: 8min
completed: 2026-04-09
---

# Phase 01 Plan 01: TableMonitor Characterization Test Infrastructure Summary

**39-test characterization suite pins TableMonitor AASM state machine, after_enter callbacks, and all after_update_commit routing branches before extraction work begins**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-09T21:02:50Z
- **Completed:** 2026-04-09T21:11:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Created `test/characterization/` directory with `test:characterization` Rake task for isolated runs
- Enabled `AASM whiny_transitions: true` in TableMonitor with zero test regressions (verified against baseline of 31 pre-existing failures)
- Added `Sidekiq::Testing.fake!` explicitly to test_helper for deterministic job assertions
- Wrote 39 characterization tests covering: all 13 AASM events, invalid transition behavior, after_enter callbacks (set_game_over, set_start_time, set_end_time with idempotency), all 7 after_update_commit branches, PartyMonitor polymorphic routing, ultra_fast/simple_score_update? guard logic, and log_state_transition registration

## Task Commits

1. **Task 1: Test infrastructure setup** - `ab4f0da0` (chore)
2. **Task 2: TableMonitor characterization tests** - `3c997b3a` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `test/characterization/table_monitor_char_test.rb` - 39 characterization tests for TableMonitor
- `app/models/table_monitor.rb` - Added `whiny_transitions: true` to AASM block
- `test/test_helper.rb` - Added explicit `Sidekiq::Testing.fake!`
- `lib/tasks/test.rake` - Added `test:characterization` Rake task
- `Gemfile` / `Gemfile.lock` - Removed incompatible `test_after_commit` gem

## Decisions Made

- **Rails 7.2 native after_commit support confirmed:** `test_after_commit` gem raises on load with Rails 5+. Removed from Gemfile. Rails 7.2 natively fires `after_commit` in transactional tests (per rails/rails#18458, since Rails 5.0).
- **PartyMonitor architecture corrected:** Plan stated PartyMonitor is an STI subclass of TableMonitor. Actual code shows PartyMonitor has its own table (`party_monitors`) and inherits from `ApplicationRecord`, not `TableMonitor`. Characterization tests document this correct relationship.
- **3-job default path confirmed:** The `after_update_commit` default path for a state change enqueues `table_scores` + `teaser` + `""` (full scoreboard) — 3 total. The relevant_keys block does NOT early-return; execution continues to the slow path.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed incompatible test_after_commit gem**
- **Found during:** Task 1 (infrastructure setup)
- **Issue:** Adding `gem 'test_after_commit'` to Gemfile caused `bundle exec rails test` to fail with "after_commit testing is baked into rails 5, you no longer need test_after_commit gem". The gem itself raises this error on load when Rails >= 5.0 is detected.
- **Fix:** Removed the gem from Gemfile entirely. Rails 7.2 natively fires `after_commit` in transactional tests.
- **Files modified:** Gemfile, Gemfile.lock
- **Verification:** `bin/rails test` runs successfully after removal
- **Committed in:** ab4f0da0 (Task 1 commit)

**2. [Rule 2 - Correction] PartyMonitor STI assumption was wrong**
- **Found during:** Task 2 (writing characterization tests)
- **Issue:** Plan described PartyMonitor as "STI subclass of TableMonitor." Reading the actual source code shows `class PartyMonitor < ApplicationRecord` (not `< TableMonitor`), with its own `party_monitors` table.
- **Fix:** Wrote tests that document the actual relationship: PartyMonitor is a separate model that can be referenced as a polymorphic `tournament_monitor` by TableMonitor.
- **Files modified:** test/characterization/table_monitor_char_test.rb
- **Verification:** Tests pass and accurately reflect production code behavior
- **Committed in:** 3c997b3a (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 bug/incompatible gem, 1 incorrect assumption correction)
**Impact on plan:** Both corrections necessary for the tests to run. No scope creep. All plan acceptance criteria met (39 tests > 18 minimum).

## Issues Encountered

- `get_options!` in `after_update_commit` calls `table.location` which crashes when no `Table` is associated (nil). Fixed by stubbing `get_options!` on the test instance for after_update_commit branch tests — this is correct since `get_options!` is out of scope for job-enqueueing branch tests.

## Known Stubs

None — all test stubs are intentional isolation mechanisms, not placeholder implementations.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Task 2 of this plan (RegionCc characterization tests) is ready to execute
- TableMonitor is fully pinned with 39 characterization tests
- AASM whiny_transitions enabled — any silent guard failures in Phase 3-5 extraction will surface immediately
- Pre-existing test failures (31 failures, 107 errors in main test suite) are unrelated to this work and pre-date this plan

---
*Phase: 01-characterization-tests-hardening*
*Completed: 2026-04-09*
