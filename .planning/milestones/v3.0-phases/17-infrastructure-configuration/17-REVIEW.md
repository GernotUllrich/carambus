---
phase: 17-infrastructure-configuration
reviewed: 2026-04-11T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - config/cable.yml
  - test/application_system_test_case.rb
  - test/system/table_monitor_broadcast_smoke_test.rb
  - test/support/system/trix.rb
  - app/javascript/channels/consumer.js
  - app/javascript/channels/table_monitor_channel.js
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
status: issues_found
---

# Phase 17: Code Review Report

**Reviewed:** 2026-04-11T00:00:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

This phase introduces ActionCable infrastructure for TableMonitor broadcasts, system test scaffolding for WebSocket smoke testing, and a substantial client-side channel subscriber. The overall structure is sound: the async adapter for tests is correct, the `wait_for_actioncable_connection` polling pattern is the right approach to avoid races, and the context-aware operation filtering in `table_monitor_channel.js` is well-designed.

Issues found are spread across three areas:

1. **Config**: A hardcoded production `channel_prefix` names a specific deployment (`carambus_bcw_development`), which will cause namespace collisions when other deployments share the same Redis instance.
2. **JavaScript**: A null-dereference crash in the `scoreboard_message` fallback handler, a module-level `localStorage` access that throws on server-side rendering or restricted contexts, verbose `console.log` calls that fire on every page load unconditionally, and a driver/default mismatch in the system test setup.
3. **Test**: A test route appended to `Rails.application.routes` at file-load time that has no guard and leaks into environments beyond tests.

---

## Critical Issues

### CR-01: Null dereference crash when CSRF meta tag is absent

**File:** `app/javascript/channels/table_monitor_channel.js:451`
**Issue:** The fallback handler for `scoreboard_message` reads `.content` directly on the result of `document.querySelector('[name="csrf-token"]')` without a null check. If the CSRF meta tag is absent (e.g., an error page, a Turbo frame partial, or a page served without the Rails layout), this line throws `TypeError: Cannot read properties of null (reading 'content')`, crashes the `onclick` handler, and silently prevents the acknowledgement fetch from firing.

**Fix:**
```javascript
const csrfToken = document.querySelector('[name="csrf-token"]')?.content ?? ''
fetch(`/scoreboard_messages/${data.message_id}/acknowledge`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-CSRF-Token': csrfToken
  }
})
```

---

## Warnings

### WR-01: Hardcoded tenant-specific channel_prefix in production cable config

**File:** `config/cable.yml:11`
**Issue:** The production `channel_prefix` is set to `carambus_bcw_development`. This value names a specific deployment scenario (`bcw`) and includes the word `development`, which is misleading in a production context. If multiple deployments (e.g., `carambus_phat`, `carambus_api`) share the same Redis instance and the prefix is accidentally copied or left at this value, all clients on different deployments will receive each other's broadcasts. The prefix is the only namespace separator between tenants on a shared Redis.

**Fix:** Drive the prefix from an environment variable or Rails credentials so each deployment gets a distinct, environment-appropriate prefix:
```yaml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/2" } %>
  channel_prefix: <%= ENV.fetch("ACTION_CABLE_PREFIX", Rails.application.class.module_parent_name.underscore) %>_<%= Rails.env %>
```

### WR-02: Module-level localStorage access throws in non-browser contexts

**File:** `app/javascript/channels/table_monitor_channel.js:5-6`
**Issue:** `localStorage.getItem(...)` is called at module evaluation time (top-level `const`), before any DOM or storage availability check. In Safari's private mode, certain WebViews, and server-side JS contexts, `localStorage` is either unavailable or throws a `SecurityError`. A crash at module evaluation time means the entire channel file fails to load and no subscription is ever created — a silent total failure.

**Fix:**
```javascript
function getLocalStorageItem(key) {
  try {
    return localStorage.getItem(key)
  } catch {
    return null
  }
}

const PERF_LOGGING = getLocalStorageItem('debug_cable_performance') === 'true'
const NO_LOGGING = getLocalStorageItem('cable_no_logging') === 'true'
```

### WR-03: Unconditional console.log calls on every page load

**File:** `app/javascript/channels/consumer.js:6,9`
**Issue:** Two `console.log` calls are unconditional and fire on every page load, regardless of `PERF_LOGGING` or `NO_LOGGING` flags. In production, this emits noise to every user's console. More importantly, once `consumer.js` is cached by the browser, these messages appear even when debugging is not desired. In contrast, all other logging in the codebase is gated on `PERF_LOGGING` / `!NO_LOGGING`. The stale comment `// Force HTTP WebSocket connection instead of HTTPS` on line 7 is also misleading — `createConsumer("/cable")` uses a relative URL and inherits the page's protocol; it does not force HTTP.

**Fix:** Remove the log calls and the misleading comment, or gate them behind the same flags used elsewhere:
```javascript
import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer("/cable")

// Expose consumer globally so system tests can check WebSocket connection state
window.consumer = consumer

export default consumer
```

### WR-04: System test route appended unconditionally at file load time

**File:** `test/application_system_test_case.rb:69-72`
**Issue:** The `test_switch_account` route is appended to `Rails.application.routes` and `reload_routes!` is called at the bottom of `application_system_test_case.rb`, which is `require`d at the top of every system test. There is no `if Rails.env.test?` guard. If this file is ever loaded in a non-test context (e.g., via an accidental require in a rake task or initializer), the route is permanently added to the production route table. Additionally, calling `reload_routes!` at load time adds latency to every system test run and can race with Rails autoloading during boot.

**Fix:** Wrap the route definition in an environment guard:
```ruby
if Rails.env.test?
  Rails.application.routes.append do
    get "/accounts/:id/switch", to: "accounts#switch", as: :test_switch_account
  end
  Rails.application.reload_routes!
end
```

---

## Info

### IN-01: Capybara.default_driver conflicts with driven_by declaration

**File:** `test/application_system_test_case.rb:65`
**Issue:** `Capybara.default_driver = :selenium_chrome_headless` is set after `driven_by :selenium, using: :headless_chrome` has already been configured. `driven_by` sets `Capybara.current_driver` for the test class; `default_driver` is the fallback used for tests that do not go through `ApplicationSystemTestCase`. Setting both with different driver names (`:headless_chrome` in `driven_by` vs. `:selenium_chrome_headless` in `default_driver`) can cause confusion about which driver actually runs, and the `:selenium_chrome_headless` driver name is the old Capybara alias that may be unavailable in newer Capybara versions. If the two names resolve to different registrations, non-system integration tests may use a browser driver unexpectedly.

**Fix:** Remove the `Capybara.default_driver` line — `driven_by` in the class definition is the correct and sufficient mechanism for system tests:
```ruby
# Remove this line — driven_by above is sufficient
# Capybara.default_driver = :selenium_chrome_headless
```

### IN-02: Magic ID `50_000_100` with no MIN_ID relationship comment

**File:** `test/system/table_monitor_broadcast_smoke_test.rb:32`
**Issue:** The game is created with a hardcoded id of `50_000_100`. The project convention (per CLAUDE.md and `LocalProtector`) is that `id >= 50_000_000` means a local record. The value `50_000_100` is local-safe, but there is no comment linking this choice to `MIN_ID` or `LocalProtector`. A future reader could reduce the id below `50_000_000` to "keep things small" and inadvertently create a global-scoped record that `LocalProtector` then blocks from being modified or destroyed.

**Fix:** Reference `MIN_ID` explicitly or add a comment:
```ruby
# id >= MIN_ID (50_000_000) marks this as a local test record, safe from LocalProtector.
@game = Game.find_or_create_by!(id: 50_000_100)
```

### IN-03: Extensive emoji-laden debug logging visible in default (non-NO_LOGGING) mode

**File:** `app/javascript/channels/table_monitor_channel.js:547-576`
**Issue:** At lines 547-576, the `received()` handler logs a detailed filtering summary (page context, operation count, each operation's selector) on every CableReady broadcast. The condition is `if (PERF_LOGGING || !NO_LOGGING)`, which means logging is active whenever `NO_LOGGING` is `false` — i.e., by default for every user who has not explicitly set `localStorage.cable_no_logging = true`. In production this fires on every score update, state change, and DOM refresh, cluttering the console and exposing internal selector and data structure details to anyone with DevTools open. The intended gate was likely `PERF_LOGGING && !NO_LOGGING`.

**Fix:**
```javascript
// Change || to && so debug output only fires when PERF_LOGGING is explicitly enabled
if (PERF_LOGGING && !NO_LOGGING) {
  console.log('🔍 Filtering operations:', { ... })
}
```
Apply the same fix to line 572 where the per-operation accept/reject log has the same condition.

---

_Reviewed: 2026-04-11T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
