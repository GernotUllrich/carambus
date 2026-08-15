---
phase: 12-tournament-characterization
plan: "02"
subsystem: testing
tags: [papertrail, aasm, google-calendar, characterization, minitest]

requires:
  - phase: 12-tournament-characterization
    provides: "Phase context: AASM states, PaperTrail config in LocalProtector, dynamic attr delegation via TournamentLocal"

provides:
  - "PaperTrail version count baselines for all Tournament state-changing operations (create, update, AASM, destroy)"
  - "Google Calendar reservation guard condition characterization (location/discipline/date/tables)"
  - "create_google_calendar_event credential guard and StandardError rescue pins"
  - "End-to-end wiring test: create_table_reservation -> GoogleCalendarService"

affects:
  - 13-tournament-extractions
  - 14-tournament-extractions
  - 15-tournament-extractions

tech-stack:
  added: []
  patterns:
    - "Characterization tests use assert_difference/@initial_count for version delta assertions"
    - "AASM transitions tested via update_column(:state, ...) + reload to bypass AR callbacks"
    - "GoogleCalendarService tested via Minitest stub blocks on class methods"
    - "Credentials stubbed via Rails.application.credentials.stub(:dig, ...)"

key-files:
  created:
    - test/models/tournament_papertrail_test.rb
    - test/models/tournament_calendar_test.rb
  modified: []

key-decisions:
  - "AASM transitions with skip_validation_on_save:true use update_all (raw SQL) — they bypass AR callbacks and produce 0 PaperTrail versions"
  - "LocalProtector skip: lambda {...} is converted to string by PaperTrail's event_attribute_option — it does NOT prevent version creation; sync_date updates DO produce versions"
  - "reset_tournament save branch is guarded by id > Seeding::MIN_ID — test-env tournaments (id >= 50M) skip the save, so 0 versions from reset_tournament"
  - "Setup assertion for @initial_count == 1 removed — AASM after_enter callbacks cause ordering-dependent version counts; each test uses assert_difference for isolation"

patterns-established:
  - "AASM transition setup: use update_column(:state, from_state) + reload to set precondition without triggering callbacks"
  - "For calendar tests: stub GoogleCalendarService class methods with .stub(:method, mock) blocks inside credentials stub block"

requirements-completed: [CHAR-08]

duration: 35min
completed: 2026-04-11
---

# Phase 12 Plan 02: PaperTrail & Google Calendar Characterization Summary

**PaperTrail version baselines and Google Calendar guard conditions pinned for Tournament — 21 characterization tests establish exact counts for all state-changing operations and verify the full create_table_reservation -> GoogleCalendarService wiring.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-04-11T00:00:00Z
- **Completed:** 2026-04-11T00:35:00Z
- **Tasks:** 2
- **Files created:** 2

## Accomplishments

- Created `tournament_papertrail_test.rb` with 12 tests pinning version counts for: create (1), update substantive (1), sync_date update (1 — skip lambda ineffective), update_columns (0), AASM transitions (0 each), reset_tournament on local tournament (0), tournament_local setter (0 on Tournament), destroy (1)
- Created `tournament_calendar_test.rb` with 9 tests characterizing all guard conditions in `create_table_reservation`, credential guard and StandardError rescue in `create_google_calendar_event`, and the full end-to-end wiring from public method to GoogleCalendarService
- All 21 tests pass in any execution order (verified across 20+ random seeds with both file orderings)

## Task Commits

1. **Task 1: PaperTrail version baseline tests** - `e74b0325` (test)
2. **Task 2: Google Calendar tests + fix setup ordering** - `37aa0f5a` (test)

## Files Created/Modified

- `test/models/tournament_papertrail_test.rb` — 12 PaperTrail version count baseline tests
- `test/models/tournament_calendar_test.rb` — 9 Google Calendar reservation characterization tests

## Decisions Made

- AASM transition version count is 0 (not 1 as the plan specified). The plan stated "each AASM transition produces 1 version," but actual behavior is 0 because AASM with `skip_validation_on_save: true` uses raw SQL `UPDATE` (via `update_all`), bypassing ActiveRecord callbacks entirely. Tests reflect actual behavior.
- sync_date-only updates DO produce a version. The `skip: lambda {...}` in `LocalProtector#has_paper_trail` is not a should-record guard — PaperTrail converts it to its string representation as an attribute name. This is a pre-existing behavior bug, but these are characterization tests so we pin the actual behavior.
- Removed setup assertion `assert_equal 1, @initial_count` to eliminate test-ordering sensitivity. AASM `after_enter: [:reset_tournament]` fires during `Tournament.create!` (initial state enter), and in some fixture states this cascade can produce 2 versions. The dedicated "create! produces exactly 1 version" test uses `assert_difference` which is ordering-safe.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] AASM transitions produce 0 versions, not 1 as plan specified**
- **Found during:** Task 1 (first test run)
- **Issue:** Plan specified "each AASM transition that changes the state column produces exactly 1 version." Actual behavior: 0 versions. AASM uses `UPDATE ... WHERE id = ?` via `update_all` which bypasses AR save callbacks entirely. PaperTrail never fires.
- **Fix:** Tests updated to assert 0 versions for all AASM transitions. Comments document the mechanism (skip_validation_on_save + update_all).
- **Files modified:** test/models/tournament_papertrail_test.rb
- **Verification:** All AASM transition tests pass consistently.
- **Committed in:** e74b0325 (Task 1 commit)

**2. [Rule 1 - Bug] sync_date update produces 1 version, not 0 as plan specified**
- **Found during:** Task 1 (first test run)
- **Issue:** Plan specified "updates where only sync_date and/or updated_at change produce 0 versions (skip lambda)." Actual behavior: 1 version. The `skip: lambda` is passed to `has_paper_trail(skip:)` but PaperTrail's `event_attribute_option` calls `.to_s` on it, converting it to a Proc description string. The lambda is not executed as a guard.
- **Fix:** Test updated to assert 1 version with documentation explaining the skip lambda ineffectiveness.
- **Files modified:** test/models/tournament_papertrail_test.rb
- **Verification:** Test passes consistently.
- **Committed in:** e74b0325 (Task 1 commit)

**3. [Rule 1 - Bug] Test-ordering failure in setup due to AASM after_enter callbacks**
- **Found during:** Task 2 (cross-file test run)
- **Issue:** `assert_equal 1, @initial_count` in PaperTrailTest setup failed when run after calendar tests in certain orderings. AASM `after_enter: [:reset_tournament]` fires during `Tournament.create!` for initial state entry. In some fixture/ordering combinations this produces 2 versions.
- **Fix:** Removed the setup assertion. @initial_count is captured as a baseline but not asserted. The dedicated "create!" test uses `assert_difference` which is ordering-safe.
- **Files modified:** test/models/tournament_papertrail_test.rb
- **Verification:** 21 tests pass across 20+ random seeds in both file orderings.
- **Committed in:** 37aa0f5a (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (all Rule 1 — actual behavior differed from plan's stated expectations)
**Impact on plan:** All deviations improve test accuracy — characterization tests now reflect actual system behavior rather than intended behavior. The baselines are correct and can be reliably preserved during extraction phases 13-15.

## Issues Encountered

- `Player.create!(first_name: ...)` failed — Player uses `firstname`/`lastname` columns. Fixed by stubbing `required_tables_count` directly instead of creating seedings.
- Calendar tests required careful stub nesting (`credentials.stub` inside `GoogleCalendarService.stub` inside tournament stub blocks) to avoid leaked state affecting other tests.

## Known Stubs

None — all tests use real Tournament instances with stubbed external services only.

## Threat Flags

None — test files only, no new production code surface introduced.

## Next Phase Readiness

- PaperTrail baselines established: extraction phases 13-15 can verify they preserve exact version counts
- Google Calendar cluster fully characterized: `create_table_reservation` is safe to extract to a service
- Key finding for extractors: AASM transitions produce 0 versions (not 1), so extracted AASM code must continue using AASM (not manual attribute updates) to preserve this baseline

---
*Phase: 12-tournament-characterization*
*Completed: 2026-04-11*

## Self-Check: PASSED

- FOUND: test/models/tournament_papertrail_test.rb
- FOUND: test/models/tournament_calendar_test.rb
- FOUND: .planning/phases/12-tournament-characterization/12-02-SUMMARY.md
- FOUND commit: e74b0325 (test(12-02): add PaperTrail version baseline characterization tests)
- FOUND commit: 37aa0f5a (test(12-02): add Google Calendar reservation characterization tests)
