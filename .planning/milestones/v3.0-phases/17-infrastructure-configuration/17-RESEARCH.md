# Phase 17: Infrastructure & Configuration — Research

**Researched:** 2026-04-11
**Domain:** ActionCable system test infrastructure — async adapter, local_server? override, multi-session Capybara, smoke test
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Switch `config/cable.yml` test adapter from `test` to `async`. The `test` adapter stores broadcasts in memory only and never delivers to real WebSocket connections opened by Selenium. The `async` adapter runs in-process and works with the same-process Puma topology used by system tests.
- **D-02:** After the adapter change, run `bin/rails test test/channels/` to verify the 2 existing channel unit tests (`TournamentChannelTest`, `TournamentMonitorChannelTest`) still pass. If they break, fall back to an env-var approach.
- **D-03:** Add a `test:` section to `config/carambus.yml` with `carambus_api_url: "http://test-api"` (or similar dummy value). This makes `ApplicationRecord.local_server?` return `true` in the test environment, so `TableMonitorChannel` accepts subscriptions and `TableMonitorJob` executes broadcasts.
- **D-04:** After the config change, run the full test suite to verify no existing tests depend on `local_server?` being `false`.
- **D-05:** Use Capybara's built-in wait/retry mechanism (`assert_selector` with default wait time) for asserting broadcast-driven DOM updates. No custom polling helper or cable-status indicator needed for Phase 17.
- **D-06:** Claude picks the simplest AASM state change that produces a visible DOM update on the scoreboard page for the smoke test trigger.

### Claude's Discretion

- Exact AASM transition for smoke test (pick the simplest one that produces a visible scoreboard DOM change)
- Multi-session Capybara helper API design (method names, parameter patterns)
- AR connection pool configuration for multi-session tests
- suppress_broadcast reset in test teardown (if needed)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INFRA-01 | System test cable adapter configured so ActionCable broadcasts reach real browser WebSocket connections | D-01: change cable.yml test adapter to `async`; verified that channel unit tests use a temporary test-adapter swap via ActionCable::TestHelper — not affected by cable.yml |
| INFRA-02 | `local_server?` returns true in system test environment so channel subscriptions are accepted | D-03: add `test:` section to carambus.yml with non-blank `carambus_api_url`; CRITICAL risk: 50+ existing tests set/stub carambus_api_url at runtime — D-03's global config approach conflicts with these |
| INFRA-03 | `ApplicationSystemTestCase` base class with multi-session Capybara helpers, AR connection pool config, and suppress_broadcast reset | Capybara 3.40.0 `using_session` API; AR pool needs to accommodate 2 Puma server threads + 1 test thread per browser session |
| INFRA-04 | Single-session smoke test proving end-to-end broadcast delivery (state change → job → ActionCable → DOM update) | Recommended transition: `new -> ready` via `ready!` AASM event; DOM target: `#game_state` div inside `#full_screen_table_monitor_{id}` |
</phase_requirements>

---

## Summary

Phase 17 sets up the test infrastructure needed to verify ActionCable broadcast isolation in browser sessions. The goal is a system test environment where triggering a TableMonitor AASM state change causes a visible DOM update in a subscribed Selenium browser session.

Three code-change sites drive this phase: `config/cable.yml` (adapter), `config/carambus.yml` (local_server? gate), and `test/application_system_test_case.rb` (multi-session helpers). The smoke test lives in a new file under `test/system/`.

**Critical discovery:** D-03 (global `carambus_api_url` in `config/carambus.yml` test section) conflicts with the large corpus of existing unit/controller/job tests that explicitly set `Carambus.config.carambus_api_url` to `nil` or `"http://local.test"` inline. These tests will break if the default becomes non-blank. The plan must address this with a per-test setup/teardown pattern instead of a global config section, OR the global config approach requires verifying the exact blast radius with D-04 first.

**Primary recommendation:** Change `cable.yml` test adapter to `async`. Instead of a global `test:` section in `carambus.yml`, add a helper in `ApplicationSystemTestCase` that sets `Carambus.config.carambus_api_url` in `setup` and restores it in `teardown` — scoped to system tests only, consistent with the existing pattern in `tournament_monitor_update_results_job_test.rb`.

---

## Standard Stack

### Core (already in Gemfile.lock — no new installs needed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Capybara | 3.40.0 [VERIFIED: runtime check] | Multi-session browser test helpers | Built into Rails system tests |
| ActionCable async adapter | Rails 7.2.2.2 [VERIFIED: Gemfile.lock] | In-process broadcast delivery | Delivers to real WebSocket connections unlike `test` adapter |
| Selenium WebDriver | 4.20.1+ | Headless Chrome automation | Already configured in ApplicationSystemTestCase |
| ActiveJob test adapter | Rails 7.2.2.2 | Queue adapter for test environment | Currently `:test` — jobs queued but NOT auto-executed |

**Installation:** No new gems required.

### Key API: Capybara Multi-Session

```ruby
# Capybara 3.40.0 built-in multi-session API [VERIFIED: runtime check]
Capybara.using_session(:session_name) do
  visit some_path
  assert_selector "#element"
end
```

### Key API: ActiveJob in System Tests

The test environment queue adapter (`:test`) does NOT execute jobs automatically. In system tests, Puma runs the app in a separate thread. `perform_later` enqueues to the `:test` adapter queue, which is NOT shared with the Puma thread's app instance. Therefore, to trigger broadcast delivery in a system test, one of these approaches is needed:

1. **Use `perform_now` directly** in the test setup to force synchronous execution. [ASSUMED — standard pattern for this problem]
2. **Switch queue adapter to `:async`** for system tests via `config.active_job.queue_adapter = :async` in a system-test-specific setup. [ASSUMED — common approach]
3. **Use `perform_enqueued_jobs`** block from `ActiveJob::TestHelper`. [VERIFIED: Rails docs pattern]

For INFRA-04 (smoke test), the smoke test trigger should use `perform_now` or directly call the state change and then `TableMonitorJob.perform_now(id)` to guarantee execution without relying on background queue delivery.

---

## Architecture Patterns

### Recommended Project Structure

No new directories needed. Changes span:

```
config/
├── cable.yml                          # change: test adapter → async
├── carambus.yml                       # decision: add test: section OR leave alone
test/
├── application_system_test_case.rb    # add: local_server? setup/teardown, multi-session helpers
└── system/
    └── table_monitor_broadcast_smoke_test.rb  # new: INFRA-04 smoke test
```

### Pattern 1: Cable Adapter Change (D-01)

**What:** Switch `test:` section in `config/cable.yml` from `adapter: test` to `adapter: async`.

**Why:** The `test` adapter stores broadcasts in a per-thread memory array. Broadcasts sent by the Puma thread (where the app runs during system tests) are stored in THAT thread's array. The Selenium browser's WebSocket connection is handled by a different Puma thread. The two threads never share the same test adapter memory — so broadcasts are silently dropped. The `async` adapter uses an in-process EventMachine-like pub/sub that routes across threads.

**Current state:**
```yaml
# config/cable.yml — current
test:
  adapter: test
```

**After change:**
```yaml
# config/cable.yml — after D-01
test:
  adapter: async
```

**Channel unit test safety:** [VERIFIED: source code analysis]
`ActionCable::Channel::TestCase` includes `ActionCable::TestHelper` which, in `before_setup`, temporarily replaces the server's pubsub with a fresh `SubscriptionAdapter::Test` instance and restores the original in `after_teardown`. This means channel unit tests are completely insulated from `cable.yml` — they always use the test adapter regardless of the global config. D-02's verification step is belt-and-suspenders but expected to pass.

### Pattern 2: local_server? Override for System Tests (D-03 — CRITICAL RISK)

**What:** Make `ApplicationRecord.local_server?` return `true` in the system test context.

**How it works:** `local_server?` checks `Carambus.config.carambus_api_url.present?`. In `config/carambus.yml`, the `default:` and `development:` sections have `carambus_api_url:` blank (nil). The test environment has no `test:` section, so it inherits from `default:` — blank.

**D-03 approach risks — VERIFIED via codebase search:**
Adding `test: carambus_api_url: "http://test-api"` to `carambus.yml` globally would make `local_server?` return `true` for ALL test runs. This breaks:
- `test/jobs/tournament_monitor_update_results_job_test.rb` — tests that expect `local_server? == false` (the "skips on API server" test)
- `test/models/tournament_scraping_test.rb` — tests that set `carambus_api_url = nil` to simulate API server behavior
- `test/controllers/tournaments_controller_test.rb` — 30+ tests that explicitly set `carambus_api_url` to `nil` or `"http://local.test"` per-test
- `test/helpers/current_helper_test.rb` — tests `local_server? returns false when carambus_api_url is blank`
- `test/characterization/table_monitor_char_test.rb` — 8+ tests that stub `local_server?` explicitly

**Recommended safer approach (Claude's discretion):** Add `local_server?` setup/teardown to `ApplicationSystemTestCase`, not to `carambus.yml`:

```ruby
# In ApplicationSystemTestCase
setup do
  @original_api_url = Carambus.config.carambus_api_url
  Carambus.config.carambus_api_url = "http://test-api"
end

teardown do
  Carambus.config.carambus_api_url = @original_api_url
end
```

This pattern is already established in `TournamentMonitorUpdateResultsJobTest` and `TournamentMonitorsControllerTest` — consistent with codebase conventions.

**Alternative if global carambus.yml approach is used:** D-04 requires running the full test suite. Given the scope of tests that depend on `local_server? == false`, expect significant breakage. The per-test pattern is lower risk.

### Pattern 3: Multi-Session Capybara Helpers (INFRA-03)

**What:** Helper method(s) on `ApplicationSystemTestCase` to open named Capybara sessions on different URLs.

**Capybara multi-session API:** [VERIFIED: Capybara 3.40.0 runtime]
```ruby
Capybara.using_session(:session_a) do
  visit scoreboard_location_path(@location, sb_state: "free_game", table_id: @table_a.id)
end

Capybara.using_session(:session_b) do
  visit scoreboard_location_path(@location, sb_state: "free_game", table_id: @table_b.id)
end
```

**AR Connection Pool concern:** Capybara multi-session tests with Selenium use the same Puma process. Each session drives a browser tab which makes HTTP requests to Puma. Puma typically uses a 5-thread pool. Rails AR connections are checked out per-thread. The test thread itself also holds an AR connection. If `pool: 5` (default) is exceeded, timeouts occur. For Phase 17 (single-session smoke test), this is not an immediate concern. For INFRA-03 (multi-session helper), the pool needs at least `n_sessions + 2` connections. [ASSUMED — standard Rails system test guidance]

**Recommended helper design (Claude's discretion):**
```ruby
# ApplicationSystemTestCase
def with_scoreboard_sessions(*table_monitors, &block)
  # Yields a hash of {session_name => table_monitor} to the block
  # Sets up Capybara sessions and tears them down
end
```

**suppress_broadcast reset:** `suppress_broadcast` is an instance variable (`@suppress_broadcast`) on each `TableMonitor` object — it does not persist to the database. No teardown cleanup needed in tests that create fresh fixtures/factory records. [VERIFIED: source code, line 73-77 of table_monitor.rb]

### Pattern 4: Smoke Test Design (INFRA-04)

**AASM transition selection (Claude's discretion — D-06):**

Recommended: `ready!` event — transitions `new -> ready`.

Rationale:
- Fixture `table_monitors(:one)` has `state: "new"` — available with no setup.
- The `ready` event has no guard conditions, no `after:` callbacks, no complex associations required.
- `state_display(:de)` for `ready` returns `"Frei"` — a short string easy to assert in `assert_selector`.
- The `after_update_commit` callback fires when state changes from `new` to `ready`.

**Broadcast chain for state change:**

1. Test calls `table_monitor.update!(state: "ready")` (or `table_monitor.ready!`)
2. `after_update_commit` fires (only if `local_server? == true`)
3. Enqueues `TableMonitorJob.perform_later(id, "table_scores")`, `TableMonitorJob.perform_later(id, "teaser")`, `TableMonitorJob.perform_later(id, "")` (full scoreboard)
4. The full scoreboard job broadcasts `inner_html` to `#full_screen_table_monitor_{id}` via `cable_ready`
5. Browser receives the CableReady operation and updates the DOM
6. `assert_selector "#game_state", text: "Frei"` passes

**Critical issue — Job execution:** The `:test` queue adapter used in test environment does NOT execute `perform_later` jobs. In the system test context, the Puma server runs the Rails app; the test process runs assertions. Job execution must be forced. Options:

**Option A (recommended):** Switch `queue_adapter` to `:async` for the test environment in `ApplicationSystemTestCase` setup, or use `config.active_job.queue_adapter = :inline` only for system test files. [ASSUMED — common system test pattern]

**Option B:** Call `TableMonitorJob.perform_now(table_monitor.id)` directly in the smoke test (bypasses the `after_update_commit` enqueue). Simpler but tests less of the real pipeline.

**Option C:** Use `perform_enqueued_jobs` from `ActiveJob::TestHelper` around the state change call. [VERIFIED: Rails docs]

**Recommended for smoke test:** Option B (`perform_now` directly) for Phase 17 since it's a smoke test. The `after_update_commit` → `perform_later` path can be proven in isolation with unit tests from Phase 16 characterization work. The smoke test's specific goal is proving the broadcast delivery chain (ActionCable → CableReady → DOM), not the full trigger pipeline.

**Scoreboard page setup:** The `table_monitors#show` action renders the scoreboard only if `game_id` is present. The smoke test needs a `TableMonitor` with a game attached. Alternatively, use the `locations#scoreboard` route with `sb_state: "free_game"` and a `table_id` param — that route loads a TableMonitor and renders `_table_monitor.html.erb` which contains `#full_screen_table_monitor_{id}`.

The simpler approach: use `table_monitors#show` but ensure fixture has a game. Or create the fixture data in test setup:

```ruby
setup do
  @game = Game.create!
  @table_monitor = TableMonitor.create!(state: "new", data: {})
  @table = Table.first  # or create one
  @table.update!(table_monitor: @table_monitor)
  @table_monitor.update!(game: @game)
end
```

Then visit `table_monitor_path(@table_monitor)` — but the show action redirects if `game_id` is blank and also if the table monitor is blank. With a game set, it renders `_show.html.erb` via `_table_monitor.html.erb`, which contains `#full_screen_table_monitor_{id}` with `#game_state` inside the `_scoreboard.html.erb` partial.

**get_options! dependency:** `TableMonitorJob` calls `table_monitor.get_options!(I18n.locale)` before rendering. `get_options!` loads from the table's location. If `table_monitor.table` is nil or `table.location` is nil, this may raise or return empty options. The smoke test setup must provide a complete `Table -> Location` chain, or stub `get_options!`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multi-session browser testing | Custom session management | `Capybara.using_session` | Built into Capybara 3.x; handles session isolation automatically |
| WebSocket broadcast verification | Custom polling loops | `assert_selector` with Capybara default wait | Capybara's retry mechanism handles async DOM updates |
| Job execution in tests | Custom job runner | `perform_enqueued_jobs` (ActiveJob::TestHelper) or `perform_now` | Already part of Rails test infrastructure |

---

## Common Pitfalls

### Pitfall 1: cable.yml adapter change breaks channel unit tests (D-02)
**What goes wrong:** Developer assumes switching to `async` adapter invalidates `assert_broadcasts` and `assert_has_stream` in `ActionCable::Channel::TestCase`.
**Why it happens:** It looks like channel tests depend on the adapter configured in cable.yml.
**How to avoid:** [VERIFIED] `ActionCable::TestHelper#before_setup` temporarily swaps in a fresh `SubscriptionAdapter::Test` instance before each test and restores the original after. Channel unit tests are insulated from `cable.yml` entirely.
**Warning signs:** None — tests will pass.

### Pitfall 2: global carambus.yml test section breaks 50+ existing tests (D-03)
**What goes wrong:** Adding `test: carambus_api_url: "http://test-api"` to `carambus.yml` makes `local_server? == true` globally in the test environment, breaking all tests that expect `local_server? == false`.
**Why it happens:** Tests in `tournament_scraping_test.rb`, `tournaments_controller_test.rb`, `tournament_monitor_update_results_job_test.rb`, `current_helper_test.rb`, `table_monitor_char_test.rb` depend on `local_server? == false` being the default.
**How to avoid:** Scope `carambus_api_url` override to `ApplicationSystemTestCase` setup/teardown, not to `carambus.yml`. This is consistent with the pattern already used in `TournamentMonitorUpdateResultsJobTest`.
**Warning signs:** D-04 full suite run will reveal failures if global approach is used.

### Pitfall 3: Jobs not executed in system tests (INFRA-04)
**What goes wrong:** `table_monitor.ready!` fires `after_update_commit`, which calls `perform_later`. The `:test` adapter enqueues jobs but does not execute them. The browser never receives a broadcast. `assert_selector` times out.
**Why it happens:** The test-environment queue adapter (`config.active_job.queue_adapter = :test`) does not auto-execute jobs. The Puma server thread runs the Rails app but uses the same `:test` adapter.
**How to avoid:** For the smoke test, call `TableMonitorJob.perform_now(table_monitor.id)` directly after triggering the state change, or switch the queue adapter to `:inline` for the smoke test's setup. Do not expect `perform_later` to trigger broadcasts automatically in system tests.
**Warning signs:** Intermittent passes, timeouts on `assert_selector`.

### Pitfall 4: get_options! raises when table/location chain is missing
**What goes wrong:** `TableMonitorJob#perform` calls `table_monitor.get_options!(I18n.locale)` before rendering the scoreboard HTML. If the `TableMonitor` has no `Table`, or the `Table` has no `Location`, `get_options!` raises (or returns nil/empty hash), causing the job to fail before broadcasting.
**Why it happens:** The smoke test creates a minimal `TableMonitor` fixture without a complete `Table -> Location -> TableKind` chain.
**How to avoid:** Either provide a complete fixture chain in smoke test setup, or stub `get_options!` to return a minimal options hash. The fixture `table_monitors(:one)` exists but has no associated Table. A more complete setup is required.
**Warning signs:** Job error in logs, no broadcast delivered.

### Pitfall 5: AR connection pool exhaustion in multi-session tests
**What goes wrong:** Two Selenium browser sessions make concurrent HTTP requests to Puma. Each Puma thread checks out an AR connection. Combined with the test thread's connection, the default pool may be exhausted.
**Why it happens:** Default AR pool size is 5. With Puma's server threads + test thread, connections can be exhausted.
**How to avoid:** Set `config.database_configuration['test']['pool']` to a higher value (e.g., 10) in a system test base class hook, OR configure per-environment in `database.yml`. For Phase 17 (single session), this is not a concern.
**Warning signs:** `ActiveRecord::ConnectionTimeoutError` in logs during multi-session tests.

### Pitfall 6: Scoreboard page does not render without game_id
**What goes wrong:** `table_monitors#show` redirects to `locations_path` if `@table_monitor.game_id.blank?` (line 33 of table_monitors_controller.rb).
**Why it happens:** The scoreboard view requires a game to show score data.
**How to avoid:** In smoke test setup, create a `Game` and assign it to the `TableMonitor` via `update!(game: @game)`, or use the fixture chain with a game already attached.
**Warning signs:** Browser redirected away from scoreboard during smoke test.

---

## Code Examples

### Cable.yml change (D-01)

```yaml
# config/cable.yml — after change
development:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/2" } %>

test:
  adapter: async    # changed from: adapter: test

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/2" } %>
  channel_prefix: carambus_bcw_development
```

### local_server? setup in ApplicationSystemTestCase (recommended pattern)

```ruby
# test/application_system_test_case.rb — addition
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # ... existing code ...

  setup do
    # Enable local_server? for system tests (TableMonitorChannel accepts subscriptions,
    # TableMonitorJob executes broadcasts)
    @original_carambus_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://test-api"
  end

  teardown do
    Carambus.config.carambus_api_url = @original_carambus_api_url
  end
end
```

### Multi-session helper (INFRA-03, Claude's discretion)

```ruby
# Example usage of Capybara multi-session in system tests
# Capybara 3.40.0 API — verified at runtime
def with_named_session(name, &block)
  Capybara.using_session(name, &block)
end
```

### Smoke test structure (INFRA-04)

```ruby
# test/system/table_monitor_broadcast_smoke_test.rb
require "test_helper"
require "application_system_test_case"

class TableMonitorBroadcastSmokeTest < ApplicationSystemTestCase
  setup do
    # Full table/location chain needed for get_options!
    @location = locations(:one)           # fixture with location data
    @table    = tables(:one)              # fixture associated with location
    @game     = Game.create!
    @tm       = @table.table_monitor || @table.build_table_monitor
    @tm.update!(state: "new", data: {})
    @tm.update!(game: @game)
    @game.game_participations.create!(player: players(:one), role: "playera")
    @game.game_participations.create!(player: players(:two), role: "playerb")
  end

  test "state change broadcasts visible DOM update to subscribed browser session" do
    visit table_monitor_url(@tm, locale: :de)

    # Confirm scoreboard page loaded with expected selector
    assert_selector "#full_screen_table_monitor_#{@tm.id}"

    # Trigger state change (ready! transitions new -> ready)
    @tm.reload
    @tm.ready!

    # Force job execution (test queue adapter does not auto-execute)
    # The job renders the scoreboard partial and broadcasts via CableReady
    # get_options! requires table/location — ensured by setup
    TableMonitorJob.perform_now(@tm.id)

    # Capybara waits up to default_max_wait_time (10s) for DOM update
    # state_display(:de) for "ready" state = "Frei"
    assert_selector "#game_state", text: "Frei"
  end
end
```

### Recommended AASM transition — `new -> ready` [VERIFIED: source code]

```ruby
# TableMonitor AASM (app/models/table_monitor.rb, line 386-388)
event :ready do
  transitions from: %i[new ready_for_new_match], to: :ready
end

# Fixture has state: "new" — transition is valid with no guards
# state_display(:de) for "ready" = "Frei" (config/locales/de.yml verified)
table_monitor.ready!  # or table_monitor.update!(state: "ready")
```

---

## Runtime State Inventory

Step 2.5 SKIPPED — this is a greenfield test infrastructure phase with no rename or migration.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Chrome/Chromium headless | Selenium system tests | To verify | — | Use DRIVER=headless_chrome (existing config) |
| Redis | async ActionCable adapter | Checked | redis 5.1+ in Gemfile.lock | `async` adapter does NOT require Redis — it's in-process |
| PostgreSQL | Test database | Running | — | None needed |

**Note on async adapter:** The `async` ActionCable adapter is fully in-process. It does NOT require Redis. This is confirmed by the Rails source — `ActionCable::SubscriptionAdapter::Async` uses a local EventEmitter-style pub/sub. Redis is only required by the `redis` adapter. [ASSUMED based on Rails adapter design]

**Missing dependencies with no fallback:** None identified.

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `adapter: test` in cable.yml | `adapter: async` for system tests | Broadcasts actually reach WebSocket connections |
| Global carambus.yml test section | Per-test setup/teardown in ApplicationSystemTestCase | No blast radius to existing 50+ tests |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `async` adapter does not require Redis (is fully in-process) | Environment Availability | If wrong, Redis must be running for system tests — it is running in dev, so low practical risk |
| A2 | Queue adapter needs explicit `perform_now` call in smoke test since test env uses `:test` adapter | Pattern 4: Smoke Test | If Puma thread uses different adapter (e.g., :async), `perform_later` might auto-execute; needs empirical confirmation during implementation |
| A3 | `get_options!` requires a complete `Table -> Location` chain | Common Pitfalls #4 | If it gracefully handles nil table, smoke test setup can be simpler |
| A4 | AR pool exhaustion is not a concern for single-session smoke test | Common Pitfalls #5 | True for INFRA-04; becomes relevant in Phases 18-19 |

---

## Open Questions (RESOLVED)

1. **Queue adapter in Puma server thread during system tests** — RESOLVED
   - What we know: Test env has `config.active_job.queue_adapter = :test`. The smoke test is driven by the test process, but the Rails app (including `after_update_commit`) runs in the Puma server thread.
   - Resolution: Use `TableMonitorJob.perform_now` explicitly in the smoke test to bypass queue adapter ambiguity. Plan 17-02 implements this.

2. **Complete fixture chain for get_options!** — RESOLVED
   - What we know: `get_options!` is called by `TableMonitorJob`. It loads from `table.location`.
   - Resolution: Executor reads fixture files (`tables.yml`, `locations.yml`) during implementation and adjusts smoke test setup accordingly. Plan 17-02 Task 1 `read_first` includes relevant fixture files.

---

## Sources

### Primary (HIGH confidence)
- `app/channels/table_monitor_channel.rb` — subscription guard logic (`local_server?` check) [VERIFIED: read]
- `app/jobs/table_monitor_job.rb` — local_server? guard, broadcast chain, get_options! dependency [VERIFIED: read]
- `app/models/application_record.rb` — `local_server?` implementation via `Carambus.config.carambus_api_url.present?` [VERIFIED: read]
- `app/models/table_monitor.rb` — AASM states/events, state_display method, suppress_broadcast flag [VERIFIED: read]
- `config/cable.yml` — current test adapter: `test` [VERIFIED: read]
- `config/carambus.yml` — current sections: default + development only; no test: section [VERIFIED: read]
- `test/application_system_test_case.rb` — existing Selenium + Devise setup [VERIFIED: read]
- `test/test_helper.rb` — LocalProtectorTestOverride, WebMock config with allow_localhost: true [VERIFIED: read]
- `test/channels/tournament_channel_test.rb` + `tournament_monitor_channel_test.rb` — existing channel tests [VERIFIED: read]
- `/Users/gullrich/.rbenv/versions/3.2.1/lib/ruby/gems/3.2.0/gems/actioncable-7.2.2.2/lib/action_cable/test_helper.rb` — ActionCable::TestHelper swaps adapter in before_setup/after_teardown [VERIFIED: read]
- `config/locales/de.yml` — state_display translations: ready="Frei", warmup="Spielbeginn" [VERIFIED: read]
- RAILS_ENV=test bin/rails runner checks — confirmed: cable adapter=test, queue adapter=:test, local_server?=false, carambus_api_url=nil [VERIFIED: runtime]
- Capybara version: 3.40.0 [VERIFIED: runtime]

### Secondary (MEDIUM confidence)
- Pattern of `Carambus.config.carambus_api_url = nil/present` per-test teardown: established in `TournamentMonitorUpdateResultsJobTest`, `TournamentMonitorsControllerTest`, and 30+ tests in `TournamentsControllerTest` [VERIFIED: grep search]

---

## Metadata

**Confidence breakdown:**
- Cable adapter change (D-01): HIGH — mechanism verified in ActionCable source
- Channel test safety (D-02): HIGH — ActionCable::TestHelper swap mechanism verified in source
- local_server? blast radius (D-03): HIGH — 50+ affected tests confirmed by codebase grep
- Smoke test AASM choice (D-06): HIGH — fixture state and transition verified
- Queue adapter behavior in system tests: MEDIUM — A2 assumption, needs empirical confirmation
- get_options! dependency chain: MEDIUM — A3 assumption, needs fixture inspection

**Research date:** 2026-04-11
**Valid until:** 2026-05-11 (stable Rails/Capybara stack)
