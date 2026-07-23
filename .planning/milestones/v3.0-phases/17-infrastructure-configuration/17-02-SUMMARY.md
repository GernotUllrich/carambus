---
phase: 17-infrastructure-configuration
plan: 02
subsystem: testing
tags: [actioncable, capybara, selenium, system-tests, cable-ready, websocket, table-monitor]

# Dependency graph
requires:
  - phase: 17-01
    provides: "async cable adapter + local_server? setup/teardown + in_session/visit_scoreboard helpers"
provides:
  - End-to-end broadcast delivery smoke test (INFRA-04)
  - Complete Table -> Location -> TableKind fixture chain for scoreboard rendering
  - wait_for_actioncable_connection helper preventing WebSocket race condition
  - data-cable-connected DOM marker in TableMonitorChannel for test synchronization
  - TrixSystemTestHelper (was missing, now created)
affects:
  - 18-broadcast-isolation-tests

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "DOM marker pattern: JS connected() callback sets data-cable-connected on <html>, Capybara asserts it — clean WebSocket synchronization without sleep"
    - "System test teardown: explicit cleanup of created records (Game) since system tests don't roll back transactions"
    - "table_kinds.yml fixture with explicit id (50_000_001) enables FK chain for tables fixture"

key-files:
  created:
    - test/system/table_monitor_broadcast_smoke_test.rb
    - test/fixtures/table_kinds.yml
    - test/support/system/trix.rb
  modified:
    - test/fixtures/tables.yml
    - test/application_system_test_case.rb
    - app/javascript/channels/consumer.js
    - app/javascript/channels/table_monitor_channel.js

key-decisions:
  - "DOM marker in TableMonitorChannel#connected() for WebSocket synchronization — no sleep, no JS evaluate_script polling"
  - "Explicit teardown in smoke test to prevent Game(50_000_100) from persisting and breaking game_setup_test.rb (Game.last assertion)"
  - "table_kind_id as explicit integer in tables.yml (not label reference) to match explicit id in table_kinds.yml fixture"
  - "Precompiled assets (public/assets/) clobbered to ensure Sprockets serves fresh esbuild build with new JS changes"

patterns-established:
  - "WebSocket sync: set DOM attribute in connected() callback, assert_selector waits in test — avoids broadcast-before-subscription race"
  - "System test teardown pattern: update_columns + destroy for records created in setup"

requirements-completed: [INFRA-04]

# Metrics
duration: ~45min
completed: 2026-04-11
---

# Phase 17 Plan 02: Broadcast Smoke Test Summary

**Passing Capybara/Selenium smoke test proving AASM state change -> TableMonitorJob.perform_now -> CableReady inner_html -> browser DOM update via ActionCable async adapter**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-04-11T13:05:00Z
- **Completed:** 2026-04-11T13:40:00Z
- **Tasks:** 1 of 2 (Task 2 is human-verify checkpoint)
- **Files modified:** 7

## Accomplishments

- Created `test/system/table_monitor_broadcast_smoke_test.rb` — smoke test visits scoreboard, waits for WebSocket, triggers `ready!` AASM transition, calls `TableMonitorJob.perform_now`, asserts "Frei" appears in the browser DOM via Capybara wait
- Created `test/fixtures/table_kinds.yml` and updated `test/fixtures/tables.yml` to complete the `TableMonitor -> Table -> Location -> TableKind` FK chain required by `get_options!`
- Created `test/support/system/trix.rb` — `TrixSystemTestHelper` was referenced in `ApplicationSystemTestCase` but the file was missing; unblocked all system tests
- Added `wait_for_actioncable_connection` helper to `ApplicationSystemTestCase` — uses DOM marker pattern (no sleep) to synchronize before broadcasting
- Added `data-cable-connected="true"` attribute to `<html>` in `TableMonitorChannel#connected()` — clean signal that server confirmed the subscription
- Full test suite green: 751 runs, 1769 assertions, 0 failures, 0 errors, 13 skips

## Task Commits

1. **Task 1: Create fixtures and smoke test for end-to-end broadcast delivery** - `bc79305f` (feat)

## Files Created/Modified

- `test/system/table_monitor_broadcast_smoke_test.rb` — End-to-end broadcast delivery smoke test (INFRA-04)
- `test/fixtures/table_kinds.yml` — New fixture for TableKind FK chain
- `test/fixtures/tables.yml` — Added `location: one` and `table_kind_id: 50_000_001` to complete FK chain
- `test/support/system/trix.rb` — TrixSystemTestHelper (was missing, unblocks ApplicationSystemTestCase)
- `test/application_system_test_case.rb` — Added `wait_for_actioncable_connection` helper
- `app/javascript/channels/consumer.js` — Added `window.consumer = consumer` for test debugging
- `app/javascript/channels/table_monitor_channel.js` — Added `data-cable-connected` DOM marker in `connected()`

## Decisions Made

- **DOM marker for WebSocket sync**: Instead of `sleep` or JS `evaluate_script` polling, the `TableMonitorChannel#connected()` callback sets `data-cable-connected="true"` on `<html>`. Capybara's `assert_selector "html[data-cable-connected='true']"` retries until the attribute appears — proper synchronization with zero sleep.
- **Explicit teardown**: System tests don't wrap in transactions. The smoke test creates `Game(id: 50_000_100)`. Without teardown, this record persists and breaks `game_setup_test.rb` (which uses `Game.last`). Added explicit `teardown` to destroy the game and reset the table monitor.
- **Stale precompiled assets**: `public/assets/` contained old esbuild output (missing `data-cable-connected` code). Ran `bin/rails assets:clobber` so Sprockets serves from `app/assets/builds/` (the fresh esbuild output). This is a local dev concern — CI/CD should run `yarn build` before tests.
- **table_kind_id as integer**: Using `table_kind: one` (label reference) in `tables.yml` resolved to a different MD5-based ID than the explicit `id: 50_000_001` in `table_kinds.yml`. Used `table_kind_id: 50_000_001` directly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created missing TrixSystemTestHelper**
- **Found during:** Task 1 (running smoke test)
- **Issue:** `test/application_system_test_case.rb` includes `TrixSystemTestHelper` but no file in `test/support/system/` defined it (directory didn't exist)
- **Fix:** Created `test/support/system/trix.rb` with `TrixSystemTestHelper` module (copied from sibling project `carambus/test/support/system/trix.rb`)
- **Files modified:** `test/support/system/trix.rb` (created)
- **Verification:** `NameError` on `TrixSystemTestHelper` resolved; test runner proceeds
- **Committed in:** `bc79305f` (Task 1 commit)

**2. [Rule 3 - Blocking] Added WebSocket synchronization to prevent broadcast-before-subscription race**
- **Found during:** Task 1 (smoke test failed with DOM not updating)
- **Issue:** `TableMonitorJob.perform_now` was called before the browser's WebSocket subscription was confirmed server-side; broadcast had no subscribers and was silently dropped
- **Fix:** Added `data-cable-connected` DOM marker in `TableMonitorChannel#connected()` + `wait_for_actioncable_connection` helper in `ApplicationSystemTestCase`
- **Files modified:** `app/javascript/channels/table_monitor_channel.js`, `test/application_system_test_case.rb`
- **Verification:** Smoke test passes; `assert_selector "html[data-cable-connected='true']"` confirms subscription established before broadcast
- **Committed in:** `bc79305f` (Task 1 commit)

**3. [Rule 3 - Blocking] Stale precompiled assets in public/assets/ shadowed fresh esbuild build**
- **Found during:** Task 1 (new JS code not executing in browser)
- **Issue:** Sprockets served `public/assets/application-012f...js` (from manifest) which didn't contain new JS code; `app/assets/builds/application.js` (fresh) was ignored
- **Fix:** Ran `bin/rails assets:clobber` to remove stale precompiled files; Sprockets now serves dynamically from `app/assets/builds/`
- **Files modified:** none (operational fix — `public/assets/` deleted)
- **Verification:** `window.consumer` and `data-cable-connected` work correctly after clobber
- **Committed in:** Not committed (runtime/local fix; CI should run `yarn build` before `bin/rails test`)

**4. [Rule 3 - Blocking] Smoke test Game record persisted across runs, breaking game_setup_test.rb**
- **Found during:** Task 1 (full suite run showed 1 failure)
- **Issue:** `Game.create!(id: 50_000_100)` in setup persisted (system tests don't rollback); `game_setup_test.rb` asserts `Game.last.id == @tm.game_id` which failed when 50_000_100 > new game ID
- **Fix:** Added `teardown` block to destroy `@game` and reset `@table_monitor` after each test
- **Files modified:** `test/system/table_monitor_broadcast_smoke_test.rb`
- **Verification:** Full suite green on second run; 751 runs, 0 failures
- **Committed in:** `bc79305f` (Task 1 commit)

---

**Total deviations:** 4 auto-fixed (3 Rule 3 - Blocking, 1 Rule 3 - Blocking)
**Impact on plan:** All fixes necessary for the smoke test to run correctly. No scope creep. The DOM marker addition to `table_monitor_channel.js` is a minimal, non-disruptive addition that also benefits future Phase 18 tests.

## Known Stubs

None — smoke test exercises the real rendering pipeline (no mocks/stubs for `get_options!` or CableReady).

## Issues Encountered

- **Stale precompiled assets**: `public/assets/` was left over from a previous `assets:precompile` run. This silently served old JS, making new code invisible in system tests. Fixed by clobbering. CI should always run `yarn build` before system tests.
- **Thread-local CableReady::Channels**: CableReady uses `Thread::Local` for its `Channels` singleton, but the final `ActionCable.server.broadcast` call is shared across threads — so `perform_now` from the test thread correctly delivers to Puma-managed WebSocket connections.

## User Setup Required

**Before running system tests**: Run `yarn build` to ensure `app/assets/builds/application.js` is current. If `public/assets/` exists with stale precompiled files, run `bin/rails assets:clobber` first.

## Next Phase Readiness

- Phase 18 (broadcast isolation tests) can begin immediately
- The smoke test proves the full broadcast chain works end-to-end
- `wait_for_actioncable_connection` helper is available in `ApplicationSystemTestCase` for all Phase 18 tests
- DOM marker pattern established for WebSocket synchronization without sleep

---
*Phase: 17-infrastructure-configuration*
*Completed: 2026-04-11*
