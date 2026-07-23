---
phase: 07-model-tests-review
plan: 01
subsystem: testing
tags: [minitest, frozen_string_literal, test-hygiene, scaffold-cleanup]

# Dependency graph
requires:
  - phase: 06-audit-baseline-standards
    provides: AUDIT-REPORT.md identifying E01 empty stubs and D-05 frozen_string_literal gaps

provides:
  - 10 empty scaffold test stubs deleted from test/models/
  - frozen_string_literal: true added to tournament_auto_reserve_test.rb and user_test.rb

affects: [07-02-model-tests-review]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "All model test files must have frozen_string_literal: true as first line"
    - "Empty scaffold stubs (0 test methods) are deleted, not kept"

key-files:
  created: []
  modified:
    - test/models/tournament_auto_reserve_test.rb
    - test/models/user_test.rb
  deleted:
    - test/models/club_location_test.rb
    - test/models/discipline_phase_test.rb
    - test/models/game_plan_test.rb
    - test/models/party_monitor_test.rb
    - test/models/slot_test.rb
    - test/models/source_attribution_test.rb
    - test/models/sync_hash_test.rb
    - test/models/table_local_test.rb
    - test/models/training_source_test.rb
    - test/models/upload_test.rb

key-decisions:
  - "Pre-existing test failures (225 runs, 7 failures, 73 errors) confirmed unchanged — not introduced by this plan"
  - "Stub deletion verified by reading all 10 files first: each had 0 test methods, only commented-out scaffold boilerplate"

patterns-established:
  - "Empty scaffold stubs provide false confidence and must be deleted, not left as placeholders"
  - "frozen_string_literal: true is required as first line in all Ruby test files"

requirements-completed: [MODL-01]

# Metrics
duration: 12min
completed: 2026-04-10
---

# Phase 07 Plan 01: Model Tests Review — Stub Deletion & Pragma Addition Summary

**10 empty scaffold test stubs deleted from test/models/ and frozen_string_literal: true added to 2 clean model test files**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-04-10T14:35:00Z
- **Completed:** 2026-04-10T14:47:00Z
- **Tasks:** 2
- **Files modified:** 2 (plus 10 deleted)

## Accomplishments

- Deleted 10 empty scaffold test stubs that contained only commented-out boilerplate and 0 test methods
- Added `# frozen_string_literal: true` as first line to `tournament_auto_reserve_test.rb` and `user_test.rb`
- Confirmed pre-existing test failures (7 failures, 73 errors) are unchanged by this plan's changes

## Task Commits

1. **Task 1: Delete 10 empty scaffold test stubs** - `6092842b` (chore)
2. **Task 2: Add frozen_string_literal to clean model test files** - `f9bc5332` (chore)

## Files Created/Modified

- `test/models/tournament_auto_reserve_test.rb` - Added `# frozen_string_literal: true` as first line
- `test/models/user_test.rb` - Added `# frozen_string_literal: true` as first line
- `test/models/club_location_test.rb` - Deleted (was empty scaffold stub)
- `test/models/discipline_phase_test.rb` - Deleted (was empty scaffold stub)
- `test/models/game_plan_test.rb` - Deleted (was empty scaffold stub)
- `test/models/party_monitor_test.rb` - Deleted (was empty scaffold stub)
- `test/models/slot_test.rb` - Deleted (was empty scaffold stub)
- `test/models/source_attribution_test.rb` - Deleted (was empty scaffold stub)
- `test/models/sync_hash_test.rb` - Deleted (was empty scaffold stub)
- `test/models/table_local_test.rb` - Deleted (was empty scaffold stub)
- `test/models/training_source_test.rb` - Deleted (was empty scaffold stub)
- `test/models/upload_test.rb` - Deleted (was empty scaffold stub)

## Decisions Made

- Confirmed all 10 stub files by reading them before deletion: each had only schema annotations and the default commented-out `# test "the truth"` block with no actual test methods
- Confirmed pre-existing failures are not regressions by running `bin/rails test test/models/` on the base commit (483d6b3a) before and after changes — same 225 runs, 7 failures, 73 errors in both cases

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

The full model test suite has 7 failures and 73 errors on the base commit (pre-existing). The primary sources are `tournament_auto_reserve_test.rb` (unique constraint violations in setup due to missing `truncate` between runs) and `tournament_monitor_ko_test.rb` (unknown attribute `shortname` for Player). These are pre-existing issues tracked for Plan 02.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 01 complete: 10 empty stubs removed, pragma added to 2 clean files
- Plan 02 ready to proceed: will fix weak assertions in league_test.rb and tournament_test.rb and add frozen_string_literal to those files

---
*Phase: 07-model-tests-review*
*Completed: 2026-04-10*
