# Stack Research: Broadcast Isolation System Tests (v3.0)

**Domain:** Rails 7.2 end-to-end system tests for ActionCable broadcast isolation
**Researched:** 2026-04-11
**Confidence:** HIGH (codebase read directly; key libraries verified from official docs and Rails source)

---

## Decision Summary

The milestone goal is browser-level end-to-end proof that a scoreboard showing TableMonitor A never receives DOM updates intended for TableMonitor B. The isolation logic is client-side JavaScript in `table_monitor_channel.js` — not server-side per-table channels. System tests must run real browsers and observe real DOM changes through real WebSocket connections.

**All required infrastructure is already in the Gemfile.** No new gems are needed. The work is configuration and test-writing only.

The three constraints that drive every decision below:

1. **ActionCable adapter must be `async` (or `test`) for system tests** — the browser connects to the same Puma process as the test runner. The async adapter works within a single OS process, which is exactly the system test topology. Switching to Redis for tests is unnecessary overhead.
2. **`use_transactional_tests` must stay `true` in system tests** — Rails 5.1+ makes the test thread and Puma server share the same database connection, so fixture data is visible to the browser without truncation or `database_cleaner`. The existing `ApplicationSystemTestCase` inherits this default.
3. **Multi-session is `Capybara.using_session`** — standard Capybara API, no additional gems. Each named session is a separate browser context (independent cookies, separate WebSocket connection) driven by the same Selenium Chrome process.

---

## Recommended Stack

### Core Technologies (all already installed)

| Technology | Version in Gemfile.lock | Purpose | Status |
|------------|------------------------|---------|--------|
| Capybara | 3.40.0 | Browser session management, multi-session via `using_session`, DOM assertions | Already in Gemfile |
| selenium-webdriver | 4.38.0 | Chrome automation driver | Already in Gemfile |
| Minitest | Rails built-in | Test runner; system tests inherit `ActionDispatch::SystemTestCase` | Already in use |
| ActionCable (async adapter) | Rails 7.2 built-in | Pub/sub within the same Puma process during tests | Already configured in `cable.yml` |
| Rails fixtures | Rails built-in | TableMonitor + tournament test data | Already used project-wide |

### Supporting Patterns (no new code required)

| Pattern | Purpose | Integration Point |
|---------|---------|-------------------|
| `Capybara.using_session("name") { ... }` | Open a second browser session on a different URL | Inside `ApplicationSystemTestCase` test methods |
| `ApplicationRecord.stub(:local_server?, true)` | Enable TableMonitorChannel subscription (channel rejects on API server) | `setup` block in broadcast isolation tests |
| `Capybara.default_max_wait_time = 10` | Wait for async DOM updates from ActionCable | Already set in `application_system_test_case.rb` line 29 |
| `assert_no_text` / `assert_text` | Verify that DOM element did or did not change | Standard Capybara assertions |
| `WebMock.disable_net_connect!(allow_localhost: true)` | Allow Puma local server connections; already configured | Already in `test_helper.rb` line 110 |

---

## Architecture of the Test

Understanding the broadcast topology is required to write the right tests:

**Single shared channel stream.** `TableMonitorChannel` uses `stream_from "table-monitor-stream"` — all clients subscribe to the same stream regardless of which table they are watching. There are no per-table channels.

**Client-side isolation via `shouldAcceptOperation`.** The JavaScript in `table_monitor_channel.js` reads the current page context (scoreboard DOM element `[data-table-monitor-root="scoreboard"]` or meta tag `scoreboard-table-monitor-id`) and rejects CableReady operations whose selector targets a different `full_screen_table_monitor_N` element.

**What system tests must verify:** Session A watching TableMonitor 1 does not show a DOM change when a broadcast for TableMonitor 2 fires. This requires two live browser sessions, each visiting a different scoreboard page, with a server-side state change on one table.

**What the test does NOT need:** A second Redis process, multiple Puma workers, or a separate server. All sessions share the same single Puma thread pool and async ActionCable event loop within the test process.

---

## Configuration Changes Required

### 1. `config/cable.yml` — add async for test environment

The current `cable.yml` uses `adapter: test` for the test environment. The test adapter stores broadcasts in memory for assertion (used in unit tests via `ActionCable::TestHelper`) but does **not** deliver them to real WebSocket connections in system tests.

Change test environment to `async`:

```yaml
# config/cable.yml
development:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/2" } %>

test:
  adapter: async          # ← changed from "test" to "async" for system tests

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/2" } %>
  channel_prefix: carambus_bcw_development
```

**Important:** Existing `ActionCable::Channel::TestCase` tests that use `assert_broadcasts` / `assert_broadcast_on` (via `ActionCable::TestHelper`) rely on the `test` adapter's in-memory store. These will break if `cable.yml` globally switches to `async`.

**Solution:** Keep `adapter: test` as the default for the test environment and override to `async` only inside system test files:

```ruby
# test/application_system_test_case.rb  (or a subclass for broadcast tests)
class BroadcastIsolationSystemTestCase < ApplicationSystemTestCase
  setup do
    # Override adapter to async so broadcasts reach the browser WebSocket
    ActionCable.server.config.cable = { "adapter" => "async" }
    ActionCable.server.restart
  end

  teardown do
    # Restore test adapter for channel unit tests
    ActionCable.server.config.cable = { "adapter" => "test" }
    ActionCable.server.restart
  end
end
```

Confidence: MEDIUM — the `ActionCable.server.restart` approach is the community workaround pattern. Verified as the mechanism in the `action-cable-testing` gem's RSpec feature integration. The exact API is not in official Rails docs but is consistent with ActionCable's runtime reconfigurability.

### 2. `test/application_system_test_case.rb` — local_server? override

`TableMonitorChannel#subscribed` calls `reject` when `ApplicationRecord.local_server?` is false (API server mode). System tests run in API server mode by default. The stub must be active for the duration of the test.

Use `Carambus.config` to set the flag if possible, or stub at the class level:

```ruby
class BroadcastIsolationSystemTestCase < ApplicationSystemTestCase
  setup do
    # Allow TableMonitorChannel to accept subscriptions
    ApplicationRecord.stubs(:local_server?).returns(true)
    # (or: use mocha, or set Carambus.config.carambus_api_url = nil)
  end
end
```

**Verify the mechanism** by reading `ApplicationRecord.local_server?` implementation — if it reads from `Carambus.config`, set the config key directly (no mock needed, avoids Mocha dependency).

---

## Multi-Session Test Pattern

```ruby
# test/system/broadcast_isolation_test.rb
require "application_system_test_case"

class BroadcastIsolationTest < BroadcastIsolationSystemTestCase
  setup do
    @tm1 = table_monitors(:one)   # fixture for table 1
    @tm2 = table_monitors(:two)   # fixture for table 2
    sign_in users(:valid)
  end

  test "scoreboard A does not update when table B changes state" do
    # Session A: scoreboard for table 1
    visit table_monitor_scoreboard_path(@tm1, locale: :de)
    assert_selector "[data-table-monitor-root='scoreboard']"

    # Session B: scoreboard for table 2 (separate browser context)
    using_session("scoreboard_b") do
      visit table_monitor_scoreboard_path(@tm2, locale: :de)
      assert_selector "[data-table-monitor-root='scoreboard']"
    end

    # Trigger a state change on table 2 from a third context (admin/API)
    using_session("trigger") do
      # POST to trigger AASM transition on @tm2
      # e.g.: post table_monitor_transition_path(@tm2), params: { event: "start_game" }
    end

    # Session A must NOT show table 2's broadcast
    assert_no_selector "#full_screen_table_monitor_#{@tm2.id}"
    # Session A's own content is unchanged
    assert_selector "#full_screen_table_monitor_#{@tm1.id}"
  end
end
```

**Key mechanics:**
- `using_session("name")` creates an isolated Selenium session (separate cookies, separate WebSocket). Returns to original session when block exits.
- The `sign_in` helper from `Warden::Test::Helpers` signs in within the current session. Each `using_session` block needs its own sign-in.
- `Capybara.default_max_wait_time = 10` (already configured) provides retry window for async DOM updates.

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `database_cleaner` gem | Rails 5.1+ system tests share the DB connection via `use_transactional_tests = true`, so fixtures are visible to the browser without truncation. Adding database_cleaner adds complexity and slows tests by orders of magnitude. | Rails built-in transactional test isolation |
| Redis adapter in test environment | The async adapter works within a single Puma process (system test topology). Redis adds a dependency on a live Redis instance, increases test fragility, and provides no benefit here since there is only one Rails server process under test. | `adapter: async` in system test setup |
| `cuprite` / Playwright / `ferrum` | These are alternatives to Selenium+Chrome. Selenium is already configured and proven working in this app. Switching drivers is a scope change, not a testing improvement. | Existing Selenium headless Chrome configuration |
| `action-cable-testing` gem | Was absorbed into Rails 6+. `ActionCable::Channel::TestCase` and `ActionCable::TestHelper` are built-in since Rails 6. Adding this gem is redundant. | Rails built-in `ActionCable::Channel::TestCase` |
| FactoryBot for TableMonitor fixtures | Project is strictly fixtures-first; FactoryBot is in the Gemfile but zero factories are defined. Creating factories for this milestone contradicts the established convention. | Add fixture rows to `test/fixtures/table_monitors.yml` |
| Parallel test execution | `parallelize(workers: :number_of_processors)` is commented out in `test_helper.rb` ("Disabled to avoid database issues with fixtures"). System tests with shared ActionCable state would make parallelism even more problematic. | Sequential test execution |
| JavaScript `console.log` assertions via CDP | The JS in `table_monitor_channel.js` logs `"SCOREBOARD MIX-UP PREVENTED"` to the console when it rejects an operation. Asserting on browser console output requires Chrome DevTools Protocol integration and fragile log scraping. | Assert on the DOM outcome (element absent / unchanged), not the log message |

---

## Version Compatibility

| Package | Version | Compatibility Notes |
|---------|---------|---------------------|
| Capybara 3.40.0 | selenium-webdriver 4.38.0 | Compatible. Capybara 3.39+ with selenium-webdriver 4.20.1+ is the documented requirement in the Gemfile. |
| selenium-webdriver 4.38.0 | Chrome/Chromium | Requires matching ChromeDriver. Selenium 4.6+ manages ChromeDriver automatically via Selenium Manager — no manual chromedriver install needed. |
| Rails 7.2.2 | ActionCable async adapter | `adapter: async` is built into Rails and is the default in development. Fully supported in 7.2. |
| Capybara `using_session` | Minitest / ActionDispatch::SystemTestCase | `using_session` is a Capybara::DSL method, available in any Capybara-backed test including `ActionDispatch::SystemTestCase`. No compatibility issues. |
| Warden::Test::Helpers | Devise + Capybara multi-session | Each `using_session` block has its own cookie jar, so `sign_in` must be called within each session. `login_as` (Warden's helper) works across sessions from outside `using_session` blocks — use the right helper depending on context. |

---

## Installation

No new gems required. Zero Gemfile changes needed.

If the ActionCable adapter-per-test-class override pattern proves unstable, the only gem addition worth considering is:

```ruby
# Gemfile — group :test (only if needed)
# NOT recommended — use built-in ActionCable::Channel::TestCase instead
# gem "action-cable-testing"  # merged into Rails 6+, redundant
```

The correct install action is to add fixture rows:

```yaml
# test/fixtures/table_monitors.yml — add a second fixture if only one exists
two:
  name: "Table 2"
  state: pointer_mode
  panel_state: pointer_mode
  current_element: pointer_mode
  # ... other required columns
```

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| Capybara `using_session` multi-session pattern | HIGH | Capybara 3.x official API. Confirmed in community tutorials and official docs. |
| Async adapter working in system tests (same process) | HIGH | The "async only works in same process" property is exactly the system test topology — Puma and tests share the OS process. Documented in Rails ActionCable overview. |
| `adapter: test` breaking real WebSocket delivery | HIGH | Test adapter stores in-memory only; does not route to WebSocket connections. Confirmed via Rails API docs. |
| Per-test-class ActionCable adapter override | MEDIUM | `ActionCable.server.restart` pattern is community-verified but not in official Rails docs. Needs validation against Rails 7.2 server internals. |
| `use_transactional_tests = true` fixture visibility | HIGH | Rails 5.1+ PR #28083 explicitly solved the shared-connection problem for system tests. Confirmed in Rails guides. |
| Broadcast isolation being client-side JS only | HIGH | Read directly from `table_monitor_channel.js` and `app/channels/table_monitor_channel.rb` — single stream, client filters by DOM element id. |

---

## Open Questions

1. **`ApplicationRecord.local_server?` implementation** — needs to be read to determine whether `Carambus.config` is the toggle (cleaner) or `stub` is required. The channel reject path must be bypassed for system tests.
2. **Scoreboard URL** — what is the actual route for the per-table scoreboard page? The `table_monitor_channel.js` context detection reads `[data-table-monitor-root="scoreboard"]`. Confirm which view renders this attribute and which route serves it.
3. **Fixture completeness** — `test/fixtures/table_monitors.yml` must have at least two rows with valid `state`, `panel_state`, and `current_element` columns. Check before writing tests.
4. **ActionCable adapter restart stability** — if `ActionCable.server.restart` causes test isolation issues, the alternative is a dedicated test environment (`RAILS_ENV=system_test`) with its own `cable.yml` section that uses `async`.

---

## Sources

- `app/javascript/channels/table_monitor_channel.js` — client-side isolation logic (`shouldAcceptOperation`, `getPageContext`)
- `app/channels/table_monitor_channel.rb` — `stream_from "table-monitor-stream"` (single shared stream)
- `test/application_system_test_case.rb` — existing driver config, `Capybara.default_max_wait_time = 10`
- `config/cable.yml` — current adapter configuration (`adapter: test` for test environment)
- `test/test_helper.rb` — `WebMock.disable_net_connect!(allow_localhost: true)` confirmed
- Rails API: ActionCable::SubscriptionAdapter::Test — https://edgeapi.rubyonrails.org/classes/ActionCable/SubscriptionAdapter/Test.html (in-memory only, no WebSocket delivery)
- Rails PR #28083 — shared DB connection for system tests (transactional fixture visibility)
- Capybara `using_session` — https://rubydoc.info/gems/capybara/Capybara/Session (multi-session API)
- Boring Rails: Testing multiple sessions — https://boringrails.com/tips/capybara-multiple-user-sessions (pattern confirmed)
- Action Cable Overview — https://guides.rubyonrails.org/action_cable_overview.html (async adapter same-process constraint)

---

*Stack research for: ActionCable broadcast isolation system tests (v3.0)*
*Researched: 2026-04-11*
