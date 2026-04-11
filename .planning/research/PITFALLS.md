# Pitfalls Research

**Domain:** ActionCable broadcast isolation system tests — Rails 7.2 + CableReady + StimulusReflex
**Researched:** 2026-04-11
**Confidence:** HIGH (verified against Rails guides, Evil Martians engineering blog, Hotwire discussion board, Rails GitHub issues, and direct codebase inspection)

---

## Critical Pitfalls

### Pitfall 1: Using `adapter: test` for Browser-Facing System Tests

**What goes wrong:**
`config/cable.yml` already has `adapter: test` for the test environment. The test adapter is designed for unit-level `ActionCable::Channel::TestCase` assertions — it captures broadcasts in-memory for `assert_broadcasts` helpers. It does **not** deliver messages through a real WebSocket pipeline to a Selenium browser. System tests using `Capybara.using_session` open real Chrome processes that connect to the Puma test server via WebSocket. Those WebSocket clients never receive broadcasts because the test adapter's in-memory queue never routes messages over the WebSocket transport.

**Why it happens:**
Developers assume "test adapter is best for testing." It is — for channel unit tests. System tests are full-stack end-to-end: the browser opens a real WebSocket, and only an in-process transport (async adapter) or an external transport (Redis) can deliver across that boundary. The test adapter docs say it "extends the async adapter," which is misleading — it overrides message delivery to use an in-memory queue only, not the async in-process PubSub that actually delivers to WebSocket connections.

**How to avoid:**
Switch the `config/cable.yml` test environment to `adapter: async` for system tests. Since system tests run in the same OS process as Puma, the async adapter's in-process pub/sub delivers to WebSocket subscribers. Do not use Redis — it introduces an external dependency and the async adapter is sufficient when tests share a process with the server.

The safest approach: override cable adapter only for system tests using an env var, preserving the `test` adapter for all unit and channel tests:

```yaml
# config/cable.yml
test:
  adapter: <%= ENV.fetch("CABLE_ADAPTER", "test") %>
```

Run system tests with `CABLE_ADAPTER=async bin/rails test test/system/`.

The existing `TournamentChannelTest` and `TournamentMonitorChannelTest` depend on `adapter: test` and its `assert_broadcasts` / `assert_has_stream` helpers. Do not break them.

**Warning signs:**
- Both browser sessions subscribe successfully (Selenium logs show `connected`) but score changes are never reflected in the DOM of the observer session.
- `assert_selector` on broadcast-updated DOM elements times out even with generous `wait:` values.
- Removing the `using_session` block and testing only one browser works fine.
- `assert_broadcasts` unit tests pass but system tests always fail.

**Phase to address:**
Phase 1 — Infrastructure setup. Must be resolved before any multi-session test can work.

---

### Pitfall 2: `local_server?` Returns False in Test Environment — Channel Rejects All Subscriptions

**What goes wrong:**
`TableMonitorChannel#subscribed` calls `ApplicationRecord.local_server?` and calls `reject` if it returns false. In the test environment, `local_server?` reads from `Carambus.config.carambus_api_url.present?`. If the test process is configured like an API server (no `carambus_api_url`), all subscriptions are silently rejected. System tests appear to run: Selenium connects, Chrome loads the scoreboard, state transitions happen — but no broadcast ever arrives because the channel rejected the subscription before it was established. Tests can pass vacuously with zero observations.

**Why it happens:**
The test environment shares config with whatever the developer has configured. CI environments typically do not have `carambus_api_url` set, making every server look like an API server. The channel's "subscription rejected" message goes to the Rails logger, not the browser — it is invisible unless you check Selenium browser logs.

**How to avoid:**
In `ApplicationSystemTestCase`, configure `Carambus.config` so `local_server?` returns `true` before any test runs:

```ruby
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  setup do
    # Ensure TableMonitorChannel does not reject subscriptions
    # local_server? returns true when carambus_api_url is nil
    Carambus.config.carambus_api_url = nil
  end
end
```

Verify which config state makes `local_server?` return `true` against the actual implementation before writing any tests.

Add a mandatory smoke test as the first system test: subscribe to `TableMonitorChannel` and assert that the subscription is confirmed (not rejected) by checking that the browser JS receives the `connected()` callback.

**Warning signs:**
- Browser console (via Selenium log capture) shows "Subscription rejected (API Server - no scoreboards)".
- The JS `connected()` callback in `table_monitor_channel.js` never fires.
- Score update triggers in the test produce no DOM changes in either session.
- Tests pass immediately without any `wait:` because assertions on absent updates are trivially true.

**Phase to address:**
Phase 1 — Infrastructure setup. This is the most likely blocker: nothing works until subscriptions are accepted.

---

### Pitfall 3: Fixture Data Not Visible to Browser Threads Under Transactional Tests

**What goes wrong:**
Rails wraps each test in a database transaction that is rolled back at the end. System tests spin up a browser that connects to the Puma server through separate threads. ActionCable's worker pool opens additional connections that operate outside the open test transaction — each worker thread gets its own AR connection from the pool. The browser-facing Rails code (including the channel `subscribed` callback and any query the scoreboard view makes) runs on those non-transactional connections and sees the database state as it was before the test transaction started. Fixtures appear empty.

**Why it happens:**
Rails 5.1+ introduced connection sharing between the test thread and the Puma request thread, but this sharing does not extend to ActionCable worker threads, which each acquire their own pool connection. This is documented in Rails GitHub issue #23778.

**How to avoid:**
Set `self.use_transactional_tests = false` in `ApplicationSystemTestCase`. Load fixtures once at the start of the test run using `bin/rails db:fixtures:load` against the test database (or rely on the test database being pre-seeded with fixtures via `bin/rails db:test:prepare`). System tests then read committed fixture data that is visible to all threads.

Add DatabaseCleaner with truncation strategy if test data must be created inside tests (not just read from fixtures):

```ruby
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  self.use_transactional_tests = false
  
  teardown do
    # Keep fixtures; only clean data created by individual tests
    # DatabaseCleaner.clean if using DatabaseCleaner
  end
end
```

**Warning signs:**
- Browser navigates to a scoreboard URL backed by a fixture record and gets 404 or a blank page.
- Test passes locally (fixture data previously committed to test DB) but fails in CI (fresh test DB without committed fixtures).
- `TableMonitor.find(fixture_id)` succeeds in the test thread but the browser's channel subscription triggers a `RecordNotFound`.

**Phase to address:**
Phase 1 — Infrastructure setup.

---

### Pitfall 4: Race Between AASM State Transition and WebSocket Subscription Establishment

**What goes wrong:**
The test fires a TableMonitor state transition before the second browser session's WebSocket subscription is fully established. The broadcast fires into the async adapter before the subscriber map has registered the second client. The client misses the message entirely — it was never buffered. The test assertion waits, times out, and reports a false negative: the isolation logic appears broken when the subscription was simply late.

This is a documented Rails/ActionCable issue (GitHub rails/rails #52420: "A widespread but rare race condition with Turbo Stream connections"): the window between page render and WebSocket subscription establishment is a blind spot where broadcasts are lost.

**Why it happens:**
WebSocket connection establishment is asynchronous. After `visit scoreboard_url`, Capybara returns control when the HTTP response is received, but the ActionCable handshake and channel subscription occur milliseconds later over a separate TCP connection. On fast CI machines the gap is smaller; on slow or busy CI the gap is larger — this is why the same test is flaky across environments.

**How to avoid:**
After `visit` in every session, explicitly wait for confirmation that the ActionCable subscription is active before triggering any state transition:

1. Add a `data-cable-status` attribute to the scoreboard DOM that the JS `connected()` callback toggles:
   ```javascript
   connected() {
     document.documentElement.dataset.cableStatus = 'connected'
   }
   ```
   Then in the test:
   ```ruby
   assert_selector "[data-cable-status='connected']", wait: 10
   ```

2. This requires a small view/JS change but eliminates all timing flakiness. It is the only reliable approach — `sleep` is fragile and hides the problem.

**Warning signs:**
- Test passes with `sleep 1` before the state transition but fails without it.
- Pass rate correlates with machine speed (fast CI fails more than local dev).
- Flakiness pattern: always fails on first run per suite, passes on retry (subscriber map warms up on retry).

**Phase to address:**
Phase 1 (add cable-connected DOM indicator to scoreboard view) + Phase 2 (use the indicator in every multi-session test assertion).

---

### Pitfall 5: Isolation Tests Pass Vacuously Because Target DOM Element Is Absent in Observer Session

**What goes wrong:**
The test opens Session A on `/scoreboards/1` and Session B on `/scoreboards/2`, triggers a state change on table 1, and asserts Session B's DOM does not update. The test passes — but not because the JS filter in `shouldAcceptOperation` rejected the broadcast. It passes because the DOM selector `#full_screen_table_monitor_1` does not exist on Session B's page: `CableReady.perform` finds no matching element and silently skips. The filter logic is never executed on the path being tested.

This is the most insidious pitfall: tests appear to verify isolation but actually verify only that absent DOM elements are not updated. Removing the entire `shouldAcceptOperation` function from `table_monitor_channel.js` would still make these tests pass.

**Why it happens:**
CableReady operations targeting non-existent selectors are no-ops. A "no DOM update" assertion cannot distinguish between "filter rejected the update" and "selector was simply absent."

**How to avoid:**
Two complementary approaches, both should be used:

1. **Capture browser console logs.** The JS filter already calls `console.warn` with "SCOREBOARD MIX-UP PREVENTED" when a foreign broadcast is rejected (visible in `table_monitor_channel.js` line ~128). Capture this directly via Selenium:
   ```ruby
   logs = page.driver.browser.logs.get(:browser)
   assert logs.any? { |l| l.message.include?("SCOREBOARD MIX-UP PREVENTED") }
   ```
   This directly validates that the filter code path was reached and executed.

2. **Inject a broadcast-receipt marker.** Add a small test-only JS snippet (via a `content_tag` conditional on `Rails.env.test?`) that sets `document.body.dataset.lastBroadcastId` on every `CableReady.perform` call. After triggering a Session A broadcast, assert that Session B's `data-last-broadcast-id` does NOT change. This proves an operation was received but filtered, not simply absent.

**Warning signs:**
- "Isolation" tests pass in under 1 second without any `wait:` — the assertion fires before any broadcast could have arrived.
- Deleting `shouldAcceptOperation` from the JS source still makes all isolation tests pass.
- No console.warn "MIX-UP PREVENTED" lines appear in captured browser logs after triggering a foreign broadcast.

**Phase to address:**
Phase 2 — Test design. This is a test validity issue, not an infrastructure issue.

---

### Pitfall 6: Multi-Session Authentication — Devise/Warden Credentials Do Not Cross Session Boundaries

**What goes wrong:**
Authentication set up with `sign_in` (Devise) or `login_as` (Warden) in the default Capybara session is not carried into `using_session(:observer)` blocks. Each Capybara session has its own browser cookie store. System tests that visit authenticated scoreboard pages in a second session get redirected to the login page. The test either fails with a selector error (scoreboard DOM not present) or silently passes because the login page does not contain any scoreboard elements to assert against.

**Why it happens:**
`Capybara.using_session` creates a separate browser context with its own cookie jar. Warden's test helper sets cookies on the current session; it has no mechanism to replicate them across sessions.

**How to avoid:**
First, verify whether scoreboards require authentication. If scoreboards are publicly accessible (likely — scoreboard pages are typically public-facing displays), skip this issue entirely.

If authentication is required: authenticate independently inside each `using_session` block through the UI, or build a session helper that drives login for a named session:

```ruby
def authenticate_session(session_name, user)
  using_session(session_name) do
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: user.password
    click_button "Sign in"
  end
end
```

Add this to `ApplicationSystemTestCase` as a reusable helper.

**Warning signs:**
- `using_session(:observer)` visits return 302 redirects visible in Selenium network logs.
- Screenshots show Devise login form instead of scoreboard.
- `assert_selector "[data-cable-status='connected']"` times out in the observer session.

**Phase to address:**
Phase 1 — Infrastructure setup. Verify scoreboard auth requirements first; build helpers only if needed.

---

### Pitfall 7: ActionCable Worker Pool Exhausts AR Connection Pool Under Concurrent Load Tests

**What goes wrong:**
Concurrent broadcast scenarios — multiple rapid AASM state transitions firing broadcasts simultaneously — cause ActionCable's worker pool threads to each check out an AR connection. The default AR connection pool size (5) is smaller than what the worker pool needs under load. Connections time out, jobs queue, broadcasts are delayed or dropped entirely. The test observes a real (but test-infrastructure-induced) race condition rather than the production behavior it was designed to detect.

**Why it happens:**
`ActionCable::Server::Worker` uses a thread pool (default size: 4). Each worker thread may use ActiveRecord for channel callbacks. Under concurrent test load, workers queue up waiting for AR connections from a pool sized for single-threaded use. This is documented in Rails GitHub issue #23778. The default pool size of 5 is insufficient: Puma threads (2+) + ActionCable workers (4) + test thread (1) already exceeds 5.

**How to avoid:**
In `config/database.yml`, increase the connection pool for the test environment before writing any concurrent tests:

```yaml
test:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 15) %>
```

For load test phases specifically, set pool size to at least `ActionCable worker pool size (4) + Puma threads (2) + concurrent Selenium sessions (2) + test thread (1) + buffer (3) = 12 minimum`. Use 15 as a safe value.

**Warning signs:**
- `ActiveRecord::ConnectionTimeoutError` in test output during concurrent scenarios.
- Tests pass sequentially but fail when concurrent state transitions are triggered.
- Broadcasts that normally arrive in <200ms take 2-5 seconds under concurrent load.

**Phase to address:**
Phase 1 — Infrastructure setup. Set the pool size before writing any concurrent test, not after observing failures.

---

### Pitfall 8: `suppress_broadcast` Flag Left Active — Broadcasts Never Fire, Tests Pass Vacuously

**What goes wrong:**
The codebase uses a `suppress_broadcast` flag (migrated across 79 call sites in v1.0) to prevent broadcast side effects during scraping and sync operations. If a test helper, fixture setup path, or `before` hook activates this flag and teardown does not reset it, AASM state transitions run without broadcasting. The system test sees no DOM updates, waits out the timeout, and either fails (if asserting update arrived) or silently passes (if asserting no update arrived for isolation).

**Why it happens:**
The flag may be set by a service call inside test setup, a fixture hook, or a polluted class-level variable from a previous test (similar to the `cattr_accessor` pollution pattern from v2.1). If teardown is missing or incomplete, subsequent tests inherit the suppressed state.

**How to avoid:**
In `ApplicationSystemTestCase`, explicitly reset broadcast suppression in `setup`:

```ruby
setup do
  # Verify broadcasts are enabled — if suppress_broadcast is on, all isolation tests are vacuous
  # Check the actual API of suppress_broadcast (class method, instance method, or flag location)
  TableMonitor.unsuppress_broadcast if TableMonitor.respond_to?(:unsuppress_broadcast)
end
```

Add a mandatory first smoke test that verifies a broadcast fires end-to-end to a subscribed browser before any isolation test runs. If this smoke test fails, all subsequent tests are invalid.

**Warning signs:**
- Broadcast tests time out waiting for DOM updates in the triggering session (not just the observer session).
- Adding `puts TableMonitor.broadcast_suppressed?` (or equivalent) in test setup returns `true`.
- Unit tests for broadcast behavior pass but system tests never see DOM changes.

**Phase to address:**
Phase 1 — Infrastructure setup. The smoke test is the gate: no isolation tests until end-to-end broadcast delivery is confirmed.

---

### Pitfall 9: `getPageContext()` Falls Back to `unknown` — Filter Becomes Over-Restrictive and Drops All Updates

**What goes wrong:**
`table_monitor_channel.js` implements `getPageContext()` with three detection strategies (data attribute, meta tag, DOM id pattern). If all three strategies fail — which can happen if the scoreboard view is not rendered with the expected DOM structure, or if Turbo replaces the DOM before the subscription fires — `getPageContext()` returns `{ type: 'unknown' }`. The `shouldAcceptOperation` switch falls into the `default` case and rejects ALL `full_screen_table_monitor_*` updates. The test observes no DOM update even for the correct table, concludes the filter is broken, and the bug is actually a view rendering issue.

**Why it happens:**
Selenium tests navigate to scoreboard pages that may render differently in the test environment (no `carambus_api_url`, missing tournament data, or Turbo frame loading states). If the `data-table-monitor-root="scoreboard"` attribute or the `meta[name="scoreboard-table-monitor-id"]` tag is absent from the rendered HTML, context detection fails silently.

**How to avoid:**
Before writing any isolation assertion, verify that `getPageContext()` returns the correct context for test-environment-rendered scoreboard pages. Capture and log the return value in the first smoke test:

```ruby
context_json = page.evaluate_script('JSON.stringify(window.getPageContext ? getPageContext() : "function not found")')
assert_equal "scoreboard", JSON.parse(context_json)["type"], "Page context detection failed"
```

If `getPageContext` is not globally accessible, make it so for test environments (or add a debug helper that logs it on connect).

**Warning signs:**
- Browser console shows "SCOREBOARD CONTEXT DETECTION FAILED" log line (already logged by the JS on unknown context + scoreboard root presence).
- Correct-table updates are rejected alongside foreign-table updates.
- `data-table-monitor-root="scoreboard"` attribute is absent from the rendered scoreboard HTML in test environment.

**Phase to address:**
Phase 1 — Infrastructure. Verify scoreboard view renders the expected detection attributes before writing any tests.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `sleep N` for timing synchronization | Quick fix for flaky race conditions | Non-deterministic, slow, masks real timing bugs | Never in final test suite; acceptable only during initial infrastructure exploration |
| Asserting absent DOM elements are not updated | Easy to write, always passes | Vacuous — proves nothing about filter logic; survives deletion of filter code | Never for isolation verification; only for smoke tests |
| Skipping multi-session setup and using only `ActionCable::Channel::TestCase` unit tests | Fast, no infrastructure work | Does not exercise client-side JS filter at all; production broadcast bleed goes undetected | Never — the JS filter is the primary isolation mechanism |
| `adapter: test` for all test environments | Simple config | Broadcasts never delivered to real browser sessions | Acceptable only for `ActionCable::Channel::TestCase` unit tests, never for system tests |
| Hard-coding `wait: 10` everywhere without DOM synchronization | Prevents timeouts | 10x slower test suite; hides real performance issues | Acceptable during initial infrastructure phase only; replace with DOM-based cable-connected signal before Phase 2 |
| Truncation strategy for all tests | Solves fixture visibility | Dramatically slower full test suite | Only for system tests; never apply to unit/integration test suite |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| ActionCable adapter for system tests | Leaving `adapter: test` — broadcasts never reach browser WebSocket connections | Use `adapter: async` for system tests (in-process delivery works when Puma and tests share a process) |
| CableReady filter verification | Asserting absent selectors are not updated (vacuous) | Capture `console.warn "SCOREBOARD MIX-UP PREVENTED"` from browser logs, or inject a DOM broadcast-receipt marker |
| StimulusReflex in system tests | Testing reflexes via direct Ruby invocation | Drive interactions through real browser clicks; reflexes travel over WebSocket and require an active browser connection |
| `local_server?` guard | Not configuring it for test context — channel rejects all subscriptions | Set `Carambus.config.carambus_api_url = nil` in system test setup so `local_server?` returns true |
| Warden/Devise multi-session auth | Using `sign_in` once and expecting it to propagate to all sessions | Authenticate independently inside each `using_session` block; or verify scoreboards are public and skip auth entirely |
| AR connection pool | Default pool of 5 insufficient for ActionCable workers + Puma threads + test thread | Set pool to 15 in `database.yml` test section before any concurrent testing |
| `suppress_broadcast` flag | Not resetting it between tests | Explicit reset in `ApplicationSystemTestCase` setup; smoke test gates all isolation tests |
| `getPageContext()` detection | Scoreboard rendered without expected detection attributes in test env | Verify `data-table-monitor-root` and meta tag are present on test-environment scoreboard pages |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Truncation cleaner per system test | Test suite takes 10-20x longer | Load fixtures once before suite; truncation only clears test-created data, not fixtures | Immediately — even 5 system tests become unacceptably slow |
| `wait: 10` on every broadcast assertion without DOM cable-connected indicator | 10+ seconds per failing assertion | Add cable-connected DOM marker; assertions fire in <500ms when channel is confirmed ready | At 10+ system tests |
| Multiple Selenium sessions per concurrent test | Chromium memory doubles per session | Reuse sessions across tests with explicit per-test state reset rather than creating new sessions | At 4+ simultaneous sessions in same test |
| ActionCable worker pool at default size (4) under load | Broadcasts delayed or dropped | Increase AR pool and worker pool before concurrent tests | At 3+ simultaneous state transitions in a single test |
| Capturing full browser console logs for every assertion | Selenium log retrieval is slow (~100ms) | Capture logs only in dedicated filter-verification tests, not in every test | When log capture is added to more than ~20 tests |

---

## "Looks Done But Isn't" Checklist

- [ ] **Broadcast delivered to browser (not just adapter queue):** Verify with DOM change assertion in the triggering session, not just `assert_broadcasts` — which only checks the in-memory adapter queue
- [ ] **Filter logic actually executed:** Confirm `console.warn "SCOREBOARD MIX-UP PREVENTED"` appears in browser logs when a foreign broadcast is sent; absence of DOM change is not sufficient proof
- [ ] **Observer session shows a scoreboard (not a login page):** Screenshot the observer session's initial page visit; must show scoreboard DOM, not Devise login
- [ ] **Channel subscription confirmed before trigger:** `data-cable-status="connected"` (or equivalent) indicator present in DOM before any state transition; do not rely on timing alone
- [ ] **`local_server?` returns true:** Log the value at test start; if false, all channel subscriptions are rejected and tests are vacuously valid
- [ ] **`suppress_broadcast` is off:** Assert at test start that broadcasts are not suppressed by leftover state from prior tests
- [ ] **`getPageContext()` returns 'scoreboard' context:** Verify scoreboard view renders `data-table-monitor-root="scoreboard"` and `meta[name="scoreboard-table-monitor-id"]` attributes
- [ ] **Cable adapter is async (not test) for system tests:** Confirm via `ActionCable.server.pubsub.class.name` in a test helper that the in-process adapter is active
- [ ] **AR connection pool is adequate:** Run a concurrent test with 3 simultaneous state transitions; assert no `ActiveRecord::ConnectionTimeoutError` in output

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wrong cable adapter (test instead of async) | LOW | Change cable.yml or add env var override; rerun single smoke test |
| `local_server?` rejecting all subscriptions | LOW | Add config setup in ApplicationSystemTestCase; rerun |
| Fixture visibility issue (transactional tests) | MEDIUM | Set `use_transactional_tests = false` in ApplicationSystemTestCase; configure DatabaseCleaner truncation for system tests only; rerun |
| Vacuous isolation assertions (absent DOM) | HIGH | Redesign test scenarios to use console log capture and/or DOM broadcast-receipt markers; requires JS view changes; ~2 days |
| Subscription-before-trigger race conditions | MEDIUM | Add `data-cable-status` DOM indicator to scoreboard view JS and wait for it; ~half day |
| `suppress_broadcast` contamination | LOW | Add setup/teardown reset in ApplicationSystemTestCase; identify which test sets the flag |
| AR connection pool exhaustion under load | LOW | Increase pool in database.yml; rerun |
| `getPageContext()` returning unknown | MEDIUM | Audit scoreboard view template for missing detection attributes; add them; rerun |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Wrong cable adapter | Phase 1 — Infrastructure | Single-session smoke test: visit scoreboard, trigger state change, assert DOM update received |
| `local_server?` rejects subscriptions | Phase 1 — Infrastructure | Browser console shows "Subscribed" not "Subscription rejected" |
| Fixture visibility | Phase 1 — Infrastructure | Browser loads fixture-backed scoreboard URL without 404 |
| Subscription-before-trigger race | Phase 1 (add DOM indicator) + Phase 2 (use it) | Tests are deterministic across 10 consecutive runs with no sleep |
| Vacuous isolation assertions | Phase 2 — Test design | Removing `shouldAcceptOperation` from JS causes the test to fail (mutation test) |
| Multi-session auth | Phase 1 — Infrastructure | Observer session shows scoreboard page, not login form |
| AR connection pool exhaustion | Phase 1 — Infrastructure (set pool) + Phase 3 (concurrent tests) | No `ActiveRecord::ConnectionTimeoutError` under 5 simultaneous broadcasts |
| `suppress_broadcast` contamination | Phase 1 — Infrastructure | Smoke test confirms broadcast arrives in browser after state transition |
| `getPageContext()` unknown context | Phase 1 — Infrastructure | Smoke test confirms DOM updates arrive in triggering session |

---

## Sources

- [Rails Action Cable Overview — official guides](https://guides.rubyonrails.org/action_cable_overview.html) — adapter configuration, stream architecture, worker pool
- [ActionCable::SubscriptionAdapter::Test — Rails API](https://api.rubyonrails.org/classes/ActionCable/SubscriptionAdapter/Test.html) — test adapter behavior, extends async but uses in-memory queue
- [Fixing flaky system tests — Hotwire Discussion](https://discuss.hotwired.dev/t/fixing-flaky-system-tests-when-a-job-broadcasts-multiple-turbo-stream-updates/6423) — `worker_pool_stream_handler` async non-determinism, synchronous patch strategy
- [Widespread but rare race condition with Turbo Streams — rails/rails #52420](https://github.com/rails/rails/issues/52420) — subscription-before-broadcast race window, connection establishment timing
- [ActionCable depletes AR connection pool — rails/rails #23778](https://github.com/rails/rails/issues/23778) — worker pool AR connection exhaustion under concurrent load
- [System of a test — Evil Martians](https://evilmartians.com/chronicles/system-of-a-test-setting-up-end-to-end-rails-testing) — database connection sharing across threads, multi-session setup, async timing solutions
- [WebSocket Director — Evil Martians](https://evilmartians.com/chronicles/websocket-director-scenario-based-integration-tests-for-real-time-apps) — synchronization strategies, `wait_all` coordination, multi-client scenarios
- [Capybara multiple sessions — Boring Rails](https://boringrails.com/tips/capybara-multiple-user-sessions) — `using_session` patterns, cookie isolation between sessions
- [table_monitor_channel.js — carambus codebase](app/javascript/channels/table_monitor_channel.js) — `shouldAcceptOperation`, `getPageContext`, `console.warn "SCOREBOARD MIX-UP PREVENTED"` (direct codebase inspection, HIGH confidence)
- [TableMonitorChannel — carambus codebase](app/channels/table_monitor_channel.rb) — `local_server?` guard, subscription reject behavior (direct codebase inspection, HIGH confidence)
- [config/cable.yml — carambus codebase](config/cable.yml) — current `adapter: test` for test environment, Redis for dev/production (direct codebase inspection, HIGH confidence)
- [test/application_system_test_case.rb — carambus codebase](test/application_system_test_case.rb) — existing Warden helpers, Selenium driver setup, no existing system infrastructure for ActionCable (direct codebase inspection, HIGH confidence)

---
*Pitfalls research for: ActionCable broadcast isolation system tests (Rails 7.2 + CableReady + StimulusReflex + Minitest)*
*Researched: 2026-04-11*
