---
phase: 17-infrastructure-configuration
plan: 01
subsystem: infra
tags: [actioncable, capybara, selenium, system-tests, local_server]

# Dependency graph
requires: []
provides:
  - ActionCable async adapter for test environment (broadcasts reach real WebSocket connections)
  - local_server? returns true during system tests via ApplicationSystemTestCase setup/teardown
  - Multi-session Capybara helpers (in_session, visit_scoreboard) for Phase 18 two-session tests
  - AR connection pool sized to 10 for multi-session system tests (config/database.yml, gitignored)
affects:
  - 18-broadcast-isolation-tests

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Scoped config override: set Carambus.config.carambus_api_url in setup, restore in teardown — does not touch config files"
    - "Multi-session Capybara via Capybara.using_session wrapped in in_session helper"

key-files:
  created: []
  modified:
    - config/cable.yml
    - test/application_system_test_case.rb

key-decisions:
  - "Use async ActionCable adapter (not test) for system tests — delivers broadcasts to real WebSocket connections opened by Selenium"
  - "Scope local_server? override to ApplicationSystemTestCase setup/teardown only — no carambus.yml test: section (would break 50+ existing tests)"
  - "config/database.yml is gitignored — pool increase to 10 documented here, must be applied manually per deployment"

patterns-established:
  - "ApplicationSystemTestCase setup/teardown as the canonical place for system-test-only config overrides"

requirements-completed: [INFRA-01, INFRA-02, INFRA-03]

# Metrics
duration: 5min
completed: 2026-04-11
---

# Phase 17 Plan 01: Infrastructure Configuration Summary

**ActionCable async adapter + scoped local_server? override in ApplicationSystemTestCase enabling Phase 18 Selenium broadcast isolation tests**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-04-11T11:03:31Z
- **Completed:** 2026-04-11T11:06:14Z
- **Tasks:** 2
- **Files modified:** 2 (committed); 1 (config/database.yml, gitignored — not committed)

## Accomplishments
- Switched cable.yml test adapter from `test` to `async` — broadcasts now reach real WebSocket connections in Selenium-driven system tests
- Added `local_server?` setup/teardown hooks to `ApplicationSystemTestCase` — `TableMonitorChannel` will accept subscriptions and `TableMonitorJob` will execute during system tests
- Added `in_session(name, &block)` and `visit_scoreboard(table_monitor, locale:)` helpers to `ApplicationSystemTestCase` for Phase 18 two-session isolation tests
- Full test suite remains green: 751 runs, 1769 assertions, 0 failures, 0 errors, 13 skips

## Task Commits

Each task was committed atomically:

1. **Task 1: Switch cable.yml test adapter from test to async** - `d9ea8cb0` (chore)
2. **Task 2: Add local_server? override, multi-session helpers, AR pool config** - `a8487c9d` (feat)

## Files Created/Modified
- `config/cable.yml` - Changed test adapter from `test` to `async`
- `test/application_system_test_case.rb` - Added setup/teardown hooks, in_session, visit_scoreboard helpers
- `config/database.yml` - Pool increased to 10 in test section (gitignored, not committed; applied locally)

## Decisions Made
- Use `async` ActionCable adapter for test environment instead of `test` — the `test` adapter silently drops broadcasts; `async` is in-process (no Redis) and delivers to real WebSocket connections
- Scope `carambus_api_url` override to `ApplicationSystemTestCase` setup/teardown, not config/carambus.yml — adding a `test:` section there would flip `local_server?` to true for all 751 tests and break those relying on it being false
- `config/database.yml` is gitignored (contains local credentials) — pool size increase documented here and applied locally only; note for new deployments

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed duplicate test section in config/database.yml**
- **Found during:** Task 2 (reading config/database.yml)
- **Issue:** File had two `test:` sections — one at line 12 and another at line 15, making the YAML invalid/ambiguous
- **Fix:** Merged into single `test:` section with `pool: 10`
- **Files modified:** config/database.yml (gitignored — not committed)
- **Verification:** YAML now parses correctly; test suite green
- **Committed in:** Not in git (gitignored file)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Minor cleanup of pre-existing YAML error in gitignored file. No scope creep.

## Issues Encountered
- `config/database.yml` is gitignored — pool size change was applied locally but cannot be committed. Documented for reference. Future deployments should ensure pool >= 10 in test section.

## User Setup Required
- Manually update `config/database.yml` test pool to 10 on any new deployment:
  ```yaml
  test:
    <<: *default
    database: carambus_api_test
    pool: 10
  ```

## Next Phase Readiness
- Phase 18 (broadcast isolation tests) can begin immediately
- `ApplicationSystemTestCase` provides all helpers Phase 18 needs: `in_session`, `visit_scoreboard`
- ActionCable async adapter delivers broadcasts to Selenium sessions
- `local_server?` returns true during system tests — `TableMonitorChannel` and `TableMonitorJob` work correctly

---
*Phase: 17-infrastructure-configuration*
*Completed: 2026-04-11*
