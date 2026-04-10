---
phase: 09-controller-system-other-tests-review
plan: "02"
subsystem: testing
tags: [minitest, integration-tests, system-tests, csrf, invisible-captcha, source-handler]

# Dependency graph
requires:
  - phase: 06-audit-baseline-standards
    provides: Issue catalogue (D-01 through D-06) identifying concrete test quality problems
provides:
  - 1 non-test script deleted (optimistic_updates_test.rb)
  - scraping_smoke_test.rb with no bare assert-true
  - current_helper_test.rb rewritten to test the actual local_server? helper
  - source_handler_test.rb with sync_date postcondition assertion
  - registrations_controller_test.rb with no CSRF regex, correct params and redirect assertions
  - user_authentication_test.rb with no hardcoded sleep (uses travel instead)
affects: [phase-10, future-test-reviews]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Use travel N.seconds to advance past invisible_captcha timestamp threshold instead of sleep"
    - "In Rails integration tests with allow_forgery_protection=false, do not extract CSRF tokens — test behavior directly"
    - "assert_select for DOM assertions instead of response.body.match regex"

key-files:
  created: []
  modified:
    - test/scraping/scraping_smoke_test.rb
    - test/helpers/current_helper_test.rb
    - test/concerns/source_handler_test.rb
    - test/controllers/registrations_controller_test.rb
    - test/system/user_authentication_test.rb
  deleted:
    - test/optimistic_updates_test.rb

key-decisions:
  - "current_helper_test.rb had tests for current_account/current_account_user/current_roles methods that do not exist — rewrote to test the actual local_server? method in current_helper.rb"
  - "CSRF token extraction in integration tests is unnecessary since allow_forgery_protection=false in test env — removed extraction, test behavior directly"
  - "registrations_controller#update redirects to root_path (not edit path) — fixed test assertions to match actual behavior"

patterns-established:
  - "When replacing a sleep in system tests for invisible_captcha, use travel N.seconds"
  - "Before writing assertions about controller redirects, verify actual controller code"

requirements-completed: [CTRL-01, SYST-01, OTHR-01]

# Metrics
duration: 25min
completed: 2026-04-10
---

# Phase 09 Plan 02: Controller/System/Other Test Fixes Summary

**6 targeted test quality fixes: deleted non-test script, removed always-passing assertion, rewrote phantom-method tests against actual helper, strengthened sync_date assertion, replaced brittle CSRF regex, removed hardcoded sleep**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-04-10T15:58:00Z
- **Completed:** 2026-04-10T16:05:23Z
- **Tasks:** 2
- **Files modified:** 5 (+ 1 deleted)

## Accomplishments

- Deleted `test/optimistic_updates_test.rb` — a standalone Ruby script with puts statements, no test class, no assertions (D-01)
- Removed the always-passing `assert true, "Individual failures should not stop batch scraping"` from scraping_smoke_test.rb; replaced with a comment documenting why the behavior is validated by production rather than a unit test (D-02)
- Rewrote `current_helper_test.rb` entirely: removed empty `LoggedInTest` class, added `frozen_string_literal`, replaced 5 tests calling non-existent methods (`current_account`, `current_account_user`, `current_roles`) with 2 passing tests that cover the actual `local_server?` method in `current_helper.rb` (D-03)
- Added `sync_date` postcondition assertion to `source_handler_test.rb` — the "only runs when record has changes" test now verifies `sync_date` equals its pre-save value after a no-op save (D-04)
- Replaced brittle CSRF regex extraction in `registrations_controller_test.rb` with direct behavioral testing; fixed params structure (`theme/locale/timezone` are top-level, not nested under `preferences`) and corrected redirect assertion to match actual controller behavior (`root_path`); added `frozen_string_literal` (D-05)
- Replaced `sleep 3` in `user_authentication_test.rb` with `travel 4.seconds` to advance past invisible_captcha timestamp threshold deterministically; added `frozen_string_literal` (D-06)

## Task Commits

1. **Task 1: Delete non-test file + fix 3 assertion issues (D-01, D-02, D-03, D-04)** — `9a12b422` (fix)
2. **Task 2: Fix brittle CSRF regex + remove sleep 3 (D-05, D-06)** — `0b716dd7` (fix)

## Files Created/Modified

- `test/optimistic_updates_test.rb` — DELETED (non-test standalone script)
- `test/scraping/scraping_smoke_test.rb` — Removed always-passing assert true test method
- `test/helpers/current_helper_test.rb` — Full rewrite: removed phantom-method tests, added frozen_string_literal, added 2 tests for actual `local_server?` helper
- `test/concerns/source_handler_test.rb` — Added `assert_equal initial_sync, tournament.reload.sync_date` postcondition assertion
- `test/controllers/registrations_controller_test.rb` — Added frozen_string_literal, removed CSRF regex, fixed params and redirect assertions
- `test/system/user_authentication_test.rb` — Added frozen_string_literal, replaced `sleep 3` with `travel 4.seconds`

## Decisions Made

- `current_helper_test.rb` had 5 tests calling `current_account`, `current_account_user`, and `current_roles` — methods that do not exist anywhere in the codebase. These were already failing before this plan. Rather than add stub methods, the tests were rewritten to cover `local_server?`, the one method that `current_helper.rb` actually defines.
- CSRF token extraction (`response.body.match(/<meta name="csrf-token"...>/)`) was both brittle and unnecessary: `config.action_controller.allow_forgery_protection = false` in `config/environments/test.rb` means CSRF tokens are never rendered or checked in test mode. The tests now test behavior (params accepted, preferences saved, redirect correct) without any token handling.
- The registrations controller redirects to `root_path` on success (not `edit_user_registration_path`), and accepts `theme/locale/timezone` as top-level user params (not nested under `preferences`). Both the original regex tests and the plan's suggested replacement would have failed for these reasons — both were corrected.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] current_helper_test.rb called non-existent helper methods**
- **Found during:** Task 1 (D-03)
- **Issue:** All 5 tests in the original file called `current_account`, `current_account_user`, or `current_roles` — none of which exist in `current_helper.rb` or anywhere else. Tests were already failing before this plan.
- **Fix:** Rewrote the file to test `local_server?` — the one method that `current_helper.rb` actually provides.
- **Files modified:** `test/helpers/current_helper_test.rb`
- **Verification:** `bin/rails test test/helpers/current_helper_test.rb` — 2 runs, 0 failures
- **Committed in:** `9a12b422` (Task 1 commit)

**2. [Rule 1 - Bug] registrations_controller_test.rb had wrong params and wrong redirect assertion**
- **Found during:** Task 2 (D-05)
- **Issue:** (a) Preferences params were sent nested under `preferences:` key but controller expects `theme/locale/timezone` as top-level user params. (b) Tests expected redirect to `edit_user_registration_path` but controller redirects to `root_path`. Both were pre-existing failures.
- **Fix:** Corrected params structure to top-level keys; corrected redirect assertion to `root_path`.
- **Files modified:** `test/controllers/registrations_controller_test.rb`
- **Verification:** `bin/rails test test/controllers/registrations_controller_test.rb` — 2 runs, 0 failures
- **Committed in:** `0b716dd7` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — pre-existing bugs)
**Impact on plan:** Both fixes necessary for tests to pass at all. No scope creep — all changes stayed within the 5 target files.

## Issues Encountered

- CSRF meta tag is not rendered in integration test responses when `allow_forgery_protection = false` (test env default). The plan's suggested `assert_select 'meta[name="csrf-token"]'` replacement would also fail for this reason. Resolved by removing the CSRF assertion entirely and testing behavioral outcomes instead.
- System test file (`user_authentication_test.rb`) could not be executed in this environment (requires Chrome/Selenium). The `sleep` removal and `travel` substitution were verified by code inspection and grep.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- All 6 D-issues from the Phase 6 audit are resolved for this plan's scope
- 5 surviving files have `frozen_string_literal: true`
- No known stubs
- Phase 09 execution complete with both plans done

---
*Phase: 09-controller-system-other-tests-review*
*Completed: 2026-04-10*
