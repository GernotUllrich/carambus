# Architecture Research: ActionCable Broadcast Isolation Testing (v3.0)

**Domain:** End-to-end system tests for ActionCable broadcast isolation in Rails 7.2 + CableReady
**Researched:** 2026-04-11
**Confidence:** HIGH (all conclusions from direct codebase inspection)

---

## What This Document Covers

This milestone adds system tests that verify broadcast isolation. It does NOT change the production broadcast architecture. Everything here is about the test infrastructure layer and how it integrates with the existing production components.

---

## Existing Production Architecture (Read-Only Context)

Understanding what the tests must exercise — not change.

### Broadcast Path: From State Change to DOM Update

```
TableMonitor#update! (AASM state change)
    |
    v
after_update_commit callback (table_monitor.rb:79)
    |-- guard: ApplicationRecord.local_server? must be true
    |-- guard: suppress_broadcast must be false
    |-- enqueues TableMonitorJob.perform_later(id, operation_type)
    |
    v
TableMonitorJob#perform (table_monitor_job.rb)
    |-- receives Integer ID only (race condition prevention)
    |-- loads fresh TableMonitor.find(id)
    |-- renders partial to HTML string
    |-- sends to cable_ready["table-monitor-stream"]
    |-- key: ALL operations use the SAME stream name "table-monitor-stream"
    |-- broadcasts selector: "#full_screen_table_monitor_{id}" (full update)
    |-- broadcasts selector: "#teaser_{id}" (teaser update)
    |-- broadcasts selector: "#table_scores" (overview update)
    |-- broadcasts dispatch_event name: "score:update" with tableMonitorId in detail
    |
    v
ActionCable server.broadcast("table-monitor-stream", payload)
    |-- ALL connected clients receive ALL broadcasts
    |-- No server-side filtering by table_monitor_id
    |
    v
TableMonitorChannel (server, table_monitor_channel.rb)
    |-- subscribed: stream_from "table-monitor-stream" (shared for all clients)
    |-- rejects subscription if !ApplicationRecord.local_server?
    |
    v
table_monitor_channel.js (client)
    |-- received(data) — called for every broadcast on the stream
    |-- getPageContext() — detects: scoreboard / table_scores / tournament_scores / unknown
    |   |-- scoreboard: reads data-table-monitor-root="scoreboard" + data-table-monitor-id
    |   |-- meta tag fallback: <meta name="scoreboard-table-monitor-id" content="{id}">
    |   |-- DOM ID fallback: #full_screen_table_monitor_{id}
    |-- shouldAcceptOperation(op, pageContext) — filters each CableReady operation
    |   |-- scoreboard context: accept only ops with selector #full_screen_table_monitor_{context.tableMonitorId}
    |   |-- rejects selectors for other table monitors
    |   |-- logs console.warn for SCOREBOARD MIX-UP PREVENTED on rejection
    |-- CableReady.perform(applicableOperations) — applies accepted ops to DOM
```

### The Isolation Guarantee: Client-Side Only

The critical architectural fact: broadcast isolation is **entirely client-side**. The server sends every broadcast to every client on "table-monitor-stream". The client JavaScript decides which operations to apply based on the page's `data-table-monitor-id` attribute.

This means:
- Tests must run a real browser (Capybara + Selenium) — there is no server-side isolation to test with unit tests
- Tests must verify JavaScript filtering behavior, not Ruby behavior
- Two browser sessions on different scoreboards must independently validate their isolation

### local_server? Guard

`ApplicationRecord.local_server?` returns `Carambus.config.carambus_api_url.present?`. In the test environment, `carambus_api_url` is blank (see `config/carambus.yml`), so `local_server?` returns **false** in tests.

This means:
- `TableMonitorChannel` rejects subscriptions in the test environment by default
- `TableMonitorJob` skips execution in the test environment by default
- Tests need `ApplicationRecord.stub(:local_server?, true)` or a test-environment config override

Existing unit tests already use `ApplicationRecord.stub(:local_server?, true)` (see `table_monitor_char_test.rb:256`).

System tests cannot use `stub` across processes (Selenium runs in a separate browser process). The system test process itself must be configured so that `local_server?` returns true for the duration of the test.

---

## Test Infrastructure Components

### Component Map: New vs Existing

```
EXISTING (do not modify)                    NEW (build for v3.0)
-------------------------------             ----------------------------------
test/test_helper.rb                         test/support/system/broadcast_helpers.rb
test/application_system_test_case.rb        test/support/system/cable_ready_helpers.rb
app/channels/table_monitor_channel.rb       test/system/broadcast_isolation_test.rb
app/jobs/table_monitor_job.rb               config/environments/test.rb (small addition)
app/javascript/channels/table_monitor_channel.js
app/views/table_monitors/_scoreboard.html.erb
app/views/table_monitors/_table_monitor.html.erb
```

### What Changes vs What Does Not

**Does not change:**
- `TableMonitorChannel` — no test hooks needed
- `TableMonitorJob` — no test hooks needed
- The JavaScript filtering code — tests verify it, do not change it
- All existing test files
- Production broadcast behavior

**Must be added or modified:**
- `config/cable.yml` test adapter: currently `adapter: test` which does NOT support async broadcast. Must switch to `async` for system tests (see below)
- `config/carambus.yml` or test environment override: `local_server?` must return true in system test context
- System test support helpers (two files)
- System test file(s)

---

## The `adapter: test` Problem

`cable.yml` currently configures the test environment with `adapter: test`. The Rails `test` adapter is synchronous and designed for `ActionCable::Channel::TestCase` unit tests — it does not route broadcasts to actual WebSocket connections.

System tests open real browser sessions via Selenium. Those browser sessions connect via real WebSockets. The `test` adapter does not forward broadcasts to those WebSocket connections.

**Solution:** Switch the system test run to use `adapter: async` (in-process pub/sub). The `async` adapter is already used in development (queue_adapter) and supports real WebSocket routing within a single process.

Options for switching:
1. Change `cable.yml` test adapter to `async` — affects all tests, but `ActionCable::Channel::TestCase` tests work with both `test` and `async`
2. Override per-test with `ActionCable.server.config.cable = { adapter: "async" }` in system test setup
3. Add a separate `cable.yml` section for `system_test` and select it via ENV

Option 1 is simplest and safe. `ActionCable::Channel::TestCase` (used in `test/channels/`) does not use the configured adapter — it injects its own test infrastructure. Changing the cable.yml test adapter to `async` will not break existing channel tests.

**Confidence:** MEDIUM — based on Rails 7.2 ActionCable test documentation and community patterns. Verify `ActionCable::Channel::TestCase` is adapter-independent before committing to option 1.

---

## The local_server? Problem in System Tests

`TableMonitorChannel#subscribed` does:
```ruby
unless ApplicationRecord.local_server?
  reject
  return
end
```

`TableMonitorJob#perform` does:
```ruby
unless ApplicationRecord.local_server?
  Rails.logger.info "📡 TableMonitorJob skipped"
  return
end
```

For system tests to work end-to-end, both must be enabled. `ApplicationRecord.stub` is per-process and does not persist across the Rails server process that Capybara drives.

**Solution:** Set `carambus_api_url` in the test environment. The simplest approach is to add to `config/carambus.yml`:

```yaml
test:
  carambus_api_url: "http://localhost:3000"  # Makes local_server? return true
```

This makes ALL tests run as if on a local server. Check whether any existing tests rely on `local_server?` returning false. From the codebase search: existing characterization tests use `ApplicationRecord.stub(:local_server?, false)` explicitly for the "API server" case — they do not rely on the default. Setting `carambus_api_url` in the test config should be safe.

**Alternative:** Add `BroadcastIsolationSystemTestCase < ApplicationSystemTestCase` that overrides `local_server?` via a test-only controller endpoint or Rails configuration hook before the browser session starts.

---

## System Test Architecture: Two-Session Pattern

The core test pattern for isolation verification:

```
Test process (Rails server in Capybara)
    |
    |-- Session 1: Capybara opens scoreboard for TableMonitor A (TM_ID=101)
    |       browser tab displays #full_screen_table_monitor_101
    |       data-table-monitor-id="101" on scoreboard root
    |
    |-- Session 2: Capybara opens scoreboard for TableMonitor B (TM_ID=102)
    |       browser tab displays #full_screen_table_monitor_102
    |       data-table-monitor-id="102" on scoreboard root
    |
    |-- Test triggers state change on TableMonitor A via HTTP/ActiveRecord
    |       TableMonitorJob runs (same process as Rails server)
    |       ActionCable broadcasts to "table-monitor-stream"
    |
    |-- Both sessions receive the broadcast
    |-- Session 1 (TM_ID=101): shouldAcceptOperation accepts #full_screen_table_monitor_101
    |       DOM update applied
    |-- Session 2 (TM_ID=102): shouldAcceptOperation rejects #full_screen_table_monitor_101
    |       DOM not updated (stale content preserved)
    |
    |-- Assert: Session 1 DOM reflects TM A state change
    |-- Assert: Session 2 DOM does NOT reflect TM A state change
```

### Capybara Session Switching

Capybara supports multiple named sessions via `using_session`:

```ruby
using_session(:scoreboard_a) do
  visit table_monitor_path(table_monitor_a)
  # wait for WebSocket connection
end

using_session(:scoreboard_b) do
  visit table_monitor_path(table_monitor_b)
  # wait for WebSocket connection
end

# Trigger broadcast
table_monitor_a.update!(state: "playing")

# Verify isolation
using_session(:scoreboard_a) do
  assert_text "Playing"           # TM A updated
end

using_session(:scoreboard_b) do
  assert_no_text "Playing"        # TM B NOT updated with TM A content
  # assert TM B still shows its original content
end
```

Each Capybara session opens an independent browser context but shares the same Selenium driver. Both sessions connect to the same Puma server over ActionCable.

---

## Component Boundaries

### test/support/system/broadcast_helpers.rb (NEW)

Provides helpers for system tests that involve ActionCable broadcasts:

| Method | Responsibility |
|--------|---------------|
| `wait_for_cable_connection` | Polls until `consumer.connection.getState()` == "open" via JS eval |
| `wait_for_broadcast(selector)` | Waits for a selector to appear/change after a broadcast |
| `assert_broadcast_applied(selector, text)` | Asserts selector exists and contains text |
| `assert_broadcast_rejected(selector, original_text)` | Asserts selector still contains original (un-updated) text |
| `trigger_state_change(table_monitor, state)` | Triggers AASM state change + flushes job queue |

### test/support/system/cable_ready_helpers.rb (NEW)

Utilities for CableReady-specific assertions:

| Method | Responsibility |
|--------|---------------|
| `flush_broadcasts` | Ensures all enqueued CableReady operations are broadcast (waits for Sidekiq/async) |
| `assert_no_console_warnings(pattern)` | Checks browser console for "SCOREBOARD MIX-UP" warnings |
| `capture_console_warnings` | Returns console.warn entries from the browser session |

The "SCOREBOARD MIX-UP PREVENTED" console.warn in `table_monitor_channel.js:127` is the existing diagnostic hook. System tests can read browser console logs via Selenium's `driver.logs.get(:browser)` to verify the JS filtering is active without needing DOM-level assertions.

### test/system/broadcast_isolation_test.rb (NEW)

The test file itself. Structure:

```
BroadcastIsolationTest < ApplicationSystemTestCase
  setup: create two TableMonitors with fixture-based data
  setup: open two Capybara sessions, navigate each to respective scoreboard
  setup: wait for both WebSocket connections

  test "state change on TM A updates TM A scoreboard"
  test "state change on TM A does NOT update TM B scoreboard"
  test "state change on TM B does NOT update TM A scoreboard"
  test "concurrent state changes update only respective scoreboards"
  test "score update event (score:update) filtered by tableMonitorId"
  test "teaser update on TM A does not appear on TM B scoreboard page"
  teardown: close sessions, clean up fixtures
```

---

## Data Flow for Multi-Session Tests

```
Test Setup
    |
    |-- fixtures: table_monitors(:alpha), table_monitors(:beta)
    |       alpha: state: "ready", id: 50_000_001
    |       beta:  state: "ready", id: 50_000_002
    |
    |-- login_as users(:admin) [Warden helper, shared across sessions]
    |
    |-- using_session(:alpha) { visit scoreboard_path(table_monitors(:alpha)) }
    |-- using_session(:beta)  { visit scoreboard_path(table_monitors(:beta)) }
    |
    |-- wait_for_cable_connection in both sessions
    |
Test Trigger
    |
    |-- table_monitors(:alpha).update!(state: "warmup")
    |       NOTE: must be done in the TEST process (not a browser action)
    |       after_update_commit fires in Rails server process
    |       TableMonitorJob runs inline (async adapter) or enqueued
    |       cable_ready broadcasts to "table-monitor-stream"
    |       Both sessions receive the WebSocket message
    |
Test Assertion
    |
    |-- using_session(:alpha) { assert_selector "#full_screen_table_monitor_50000001" }
    |-- using_session(:beta)  { assert_no_selector "[new alpha content]" }
```

### Job Execution in System Tests

`Sidekiq::Testing.fake!` is active in test_helper (via `Sidekiq::Testing.fake!`). This means jobs are NOT executed inline by default — they are queued in memory.

For system tests, jobs must execute immediately so broadcasts happen during the test. Options:
1. Call `Sidekiq::Worker.drain_all` after each trigger to flush all jobs
2. Switch to `Sidekiq::Testing.inline!` in system test setup (executes jobs synchronously)
3. Use `perform_enqueued_jobs` from ActiveJob test helpers

Option 2 is the simplest for system tests: override in `BroadcastIsolationSystemTestCase` setup.

However, note that `async` queue adapter (not Sidekiq) is configured in `config/carambus.yml`. The `queue_adapter: async` means Rails dispatches jobs to an in-process thread pool. With `async` adapter, jobs execute without Sidekiq in the test process. This avoids the Sidekiq drain problem entirely.

Confirm at test time whether jobs execute synchronously or asynchronously with the `async` adapter and add a `sleep`/`wait` if needed.

---

## Build Order

Dependencies drive the order: infrastructure must exist before tests, and the local_server? fix must come before any browser session can subscribe to the channel.

### Step 1: Unblock the channel and job (configuration)

**What:** Enable `local_server?` in test environment and switch cable adapter to `async`.
**Files:**
- `config/carambus.yml` — add `carambus_api_url: "http://localhost:3000"` to test section
- `config/cable.yml` — change test adapter from `test` to `async`

**Why first:** Nothing works until the channel accepts subscriptions and the job executes.

**Risk:** LOW. Existing channel unit tests (`ActionCable::Channel::TestCase`) use their own test adapter internally. Existing characterization tests use explicit stubs. Verify no test currently depends on `local_server?` returning false by default.

### Step 2: Build ApplicationSystemTestCase extensions

**What:** Create `test/support/system/broadcast_helpers.rb` with `wait_for_cable_connection`, session helpers, and trigger utilities. Include in `ApplicationSystemTestCase`.
**Files:**
- `test/support/system/broadcast_helpers.rb` (new)
- `test/application_system_test_case.rb` (add one `Dir.glob` include line)

**Why second:** Shared helpers used by all subsequent test files.

**Risk:** LOW. Adding files to `test/support/system/` is already handled by the existing `Dir[...support/system/**/*.rb]` line in `application_system_test_case.rb`.

### Step 3: Smoke test the infrastructure

**What:** Write a single minimal system test that visits a scoreboard page and asserts the WebSocket connects. No broadcast assertion yet.
**File:** `test/system/broadcast_isolation_test.rb` (initial version, single test)

**Why third:** Confirms the infrastructure works before investing in multi-session test complexity.

**Risk:** LOW. If this fails, Step 1 configuration is the culprit.

### Step 4: Add fixture support for scoreboard routes

**What:** Ensure `table_monitors.yml` has fixtures suitable for scoreboard rendering (associated `table`, `location`, valid `data` hash). The scoreboard view requires `options`, which requires `get_options!(locale)`, which requires `table.location`.
**Files:**
- `test/fixtures/table_monitors.yml` (verify/extend)
- `test/fixtures/tables.yml` (verify)
- `test/fixtures/locations.yml` (verify)

**Why fourth:** Without valid fixture data, the scoreboard partial will raise errors during rendering in tests.

**Risk:** MEDIUM. The `options` computation via `get_options!` touches `table.location.table_kinds` and potentially other associations. May require stubbing or additional fixtures.

### Step 5: Build two-session isolation tests

**What:** Add multi-session tests to `broadcast_isolation_test.rb`. Cover: full scoreboard update, score:update event, teaser update.
**File:** `test/system/broadcast_isolation_test.rb` (extend)

**Why fifth:** Core milestone requirement. Depends on all prior steps.

**Risk:** HIGH. Timing issues with async broadcasts, job execution order, and WebSocket connection establishment require careful use of Capybara's `assert_selector` with `wait:` parameter.

### Step 6: Add concurrent/load scenarios

**What:** Tests that trigger state changes on multiple table monitors simultaneously and verify isolation holds under concurrent broadcasts.
**File:** `test/system/broadcast_isolation_test.rb` (extend) or `test/system/broadcast_load_test.rb` (separate)

**Why last:** Requires working isolation tests as a baseline. Concurrent tests are the most flaky and require the most tuning.

**Risk:** HIGH. Race conditions in tests are hard to diagnose. Use generous `wait:` values and deterministic DOM markers.

---

## Integration Points with Existing Architecture

### Integration Point 1: TableMonitorChannel subscription guard

**Location:** `app/channels/table_monitor_channel.rb:5`
**Current behavior:** Rejects subscriptions when `!ApplicationRecord.local_server?`
**Test requirement:** `local_server?` must return `true` when system tests run
**Solution:** `config/carambus.yml` test section with `carambus_api_url` set
**No code change required** to the channel itself

### Integration Point 2: TableMonitorJob execution guard

**Location:** `app/jobs/table_monitor_job.rb:8`
**Current behavior:** Returns early when `!ApplicationRecord.local_server?`
**Test requirement:** Same as above — same config change unblocks both
**No code change required** to the job itself

### Integration Point 3: Client-side filtering in table_monitor_channel.js

**Location:** `app/javascript/channels/table_monitor_channel.js:107–196`
**What tests verify:** `shouldAcceptOperation` correctly rejects operations for a different `tableMonitorId`
**How tests observe this:** DOM assertion (TM B scoreboard content unchanged) + console.warn capture
**No code change required** — tests observe existing behavior

### Integration Point 4: DOM structure for context detection

**Location:** `app/views/table_monitors/_scoreboard.html.erb:34–35`
**Structure:** `data-table-monitor-root="scoreboard" data-table-monitor-id="{id}"`
**Required by:** `getPageContext()` in `table_monitor_channel.js`
**Test dependency:** System tests must navigate to the actual scoreboard view (not a stub) so this DOM structure is present
**No code change required**

### Integration Point 5: CableReady broadcast channel name

**Key fact:** `TableMonitorJob` always broadcasts to `"table-monitor-stream"` (shared stream). The selector in the broadcast payload encodes which table monitor the operation targets: `"#full_screen_table_monitor_{id}"`.
**Test implication:** Tests verify isolation at the selector level, not at the stream level. Both sessions are on the same stream; isolation is purely in JS.

### Integration Point 6: score:update dispatch_event path

**Location:** `table_monitor_job.rb:159` + `table_monitor_channel.js:480–498`
**Structure:** CableReady `dispatch_event` with `name: "score:update"` and `detail: { tableMonitorId: ... }`
**Client filtering:** `document.addEventListener('score:update', ...)` checks `currentTableMonitorId !== tableMonitorId`
**Test requirement:** Separate test for this path — it uses a different filtering mechanism than the DOM selector path

---

## Anti-Patterns

### Anti-Pattern 1: Stubbing local_server? per-test in system tests

**What people do:** Add `ApplicationRecord.stub(:local_server?, true)` inside system test blocks.
**Why it's wrong:** `stub` is per-process. The Selenium browser makes HTTP requests to the Rails Puma server, which is in the same process for Capybara. However, the stub is set in the test thread, while ActionCable callbacks fire in the Puma thread. Thread-local stubs do not cross thread boundaries reliably.
**Do this instead:** Set `carambus_api_url` in `config/carambus.yml` test section so `local_server?` is globally true in the test process.

### Anti-Pattern 2: Using adapter: test for system tests

**What people do:** Leave `cable.yml` test adapter as `test`.
**Why it's wrong:** The `test` adapter does not forward broadcasts to real WebSocket connections opened by Selenium. Broadcasts will appear to happen (no error) but the browser never receives them.
**Do this instead:** Use `adapter: async` for system tests. The `async` adapter routes broadcasts to real WebSocket connections in the same process.

### Anti-Pattern 3: Asserting on the absence of all content after a rejected broadcast

**What people do:** `assert_no_text "Playing"` on TM B after TM A transitions to "playing".
**Why it's wrong:** TM B may legitimately show "Playing" if its own state is "playing". The test is asserting isolation, not absence of a word.
**Do this instead:** Assert TM B shows its specific original content (fixture state), and that the HTML rendered for TM A's scoreboard content has not appeared in TM B's DOM.

### Anti-Pattern 4: Multi-session tests without waiting for WebSocket connections

**What people do:** Open two sessions, immediately trigger a broadcast, assert.
**Why it's wrong:** WebSocket connections take time to establish (ActionCable handshake + subscription confirmation). If the broadcast fires before a session subscribes, that session never receives it.
**Do this instead:** Use `wait_for_cable_connection` (polling `consumer.connection.getState()` via JS) in both sessions before triggering any broadcasts.

### Anti-Pattern 5: Using perform_enqueued_jobs to flush TableMonitorJob

**What people do:** Call `perform_enqueued_jobs` from ActiveJob test helpers.
**Why it's wrong:** `perform_enqueued_jobs` is designed for the `:test` queue adapter, not `async`. When the `async` adapter is active, jobs execute in background threads — `perform_enqueued_jobs` may not catch them.
**Do this instead:** With the `async` adapter, add a short `assert_selector`-with-`wait:` after the trigger. Capybara's built-in wait loop will retry until the DOM updates or the wait times out.

---

## Scaling Considerations

Not applicable to this milestone — this is a test infrastructure build, not production scaling. The broadcast architecture (single shared stream with client-side filtering) is an intentional design choice from the existing codebase and is not being changed.

---

## Sources

All findings from direct inspection of production code and test infrastructure:

- `app/channels/table_monitor_channel.rb` — subscription guard, stream name
- `app/jobs/table_monitor_job.rb` — execution guard, selector naming, operation types
- `app/javascript/channels/table_monitor_channel.js` — client-side filtering logic (shouldAcceptOperation, getPageContext, score:update listener)
- `app/views/table_monitors/_scoreboard.html.erb` — data-table-monitor-id DOM attribute
- `config/cable.yml` — test adapter: test (current, needs change)
- `config/carambus.yml` — local_server? configuration (test section has blank carambus_api_url)
- `test/test_helper.rb` — Sidekiq.fake!, WebMock config, LocalProtector/ApiProtector overrides
- `test/application_system_test_case.rb` — Capybara/Selenium driver config, TrixSystemTestHelper
- `test/characterization/table_monitor_char_test.rb` — local_server? stub pattern
- `test/channels/tournament_channel_test.rb` — existing ActionCable::Channel::TestCase pattern
- `test/system/party_monitors_test.rb` — existing system test pattern (no ActionCable)
- `.planning/codebase/TESTING.md` — test infrastructure inventory

Confidence: HIGH — all conclusions from reading actual production code and test files. The cable adapter switching recommendation is MEDIUM confidence pending verification that ActionCable::Channel::TestCase is adapter-independent in Rails 7.2.

---

*Architecture research for: ActionCable broadcast isolation end-to-end testing (v3.0)*
*Researched: 2026-04-11*
