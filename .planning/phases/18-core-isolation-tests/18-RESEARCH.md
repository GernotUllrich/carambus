# Phase 18: Core Isolation Tests - Research

**Researched:** 2026-04-11
**Domain:** Two-session Capybara/Selenium system tests for ActionCable broadcast isolation
**Confidence:** HIGH — all findings from direct codebase inspection; no external sources needed

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Four requirements (ISOL-01 through ISOL-04). ISOL-01 covers the morph path (`#full_screen_table_monitor_{id}` via CableReady `inner_html`). ISOL-02 covers the `score:update` dispatch event path (JSON payload with `tableMonitorId` filtering). ISOL-03 covers the `table_scores` overview page context. ISOL-04 covers `console.warn("SCOREBOARD MIX-UP PREVENTED")` capture proving the filter actually ran.
- **D-02:** Each test needs two TableMonitor instances on different tables, both with complete fixture chains (TableMonitor → Table → Location → Game). Reuse the smoke test pattern from Phase 17.
- **D-03:** Reuse `in_session(name, &block)`, `visit_scoreboard(table_monitor)`, and `wait_for_actioncable_connection` helpers from `ApplicationSystemTestCase`.
- **D-04:** Use `TableMonitorJob.perform_now(tm.id)` to trigger broadcasts synchronously.
- **D-05:** Use Capybara's built-in wait/retry for positive assertions (`assert_selector`).
- **D-06:** `shouldAcceptOperation` has four page contexts: scoreboard (rejects mismatches with console.warn), table_scores, tournament_scores, unknown.
- **D-07:** Phase 18 tests paths 1 (ISOL-01), 1+dispatch_event (ISOL-02), and 2 (ISOL-03). Path 3 (tournament_scores) can be deferred.

### Claude's Discretion

- Test file organization (single file vs per-path)
- Paired positive/negative assertion strategy
- `score:update` dispatch event verification approach (DOM side-effect, console log capture, or combination)
- `console.warn` capture mechanism for ISOL-04 (Selenium logs API, DOM marker, or other)
- Which AASM transitions to trigger for morph vs score:update
- Fixture setup sharing strategy across test methods
- Whether to test `tournament_scores` context (path 3) or defer

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ISOL-01 | Two-session morph path isolation test — scoreboard A unchanged when table B state changes (paired positive/negative) | Full scoreboard broadcast uses `TableMonitorJob.perform_now(id)` with no `operation_type` (default `else` branch) → `inner_html` to `#full_screen_table_monitor_{id}`. Trigger: `@table_monitor.ready!` → `perform_now`. Verified by `assert_selector` (positive) and `refute_selector`/timestamp marker (negative + console.warn capture for ISOL-04). |
| ISOL-02 | Two-session `score:update` dispatch event path isolation test (separate JS code path, paired positive/negative) | `score_data` branch in `TableMonitorJob` dispatches a CableReady `dispatch_event` with name `"score:update"` and payload `{tableMonitorId, playerKey, score, inning}`. The event listener in `table_monitor_channel.js` (line 10) filters by comparing `currentTableMonitorId` to `event.detail.tableMonitorId`. Triggering requires manipulating `@collected_data_changes` so `ultra_fast_score_update?` returns true, OR calling `TableMonitorJob.perform_now(id, "score_data", player: "playera")` directly. |
| ISOL-03 | `table_scores` overview page context isolation test | `table_scores` page renders `<turbo-frame id="table_scores">`. The JS `getPageContext()` detects this via `document.querySelector('#table_scores')` and returns `{type: 'table_scores'}`. `shouldAcceptOperation` for this context rejects all `#full_screen_table_monitor_N` selectors. The overview page URL is accessed via `scoreboard_location_path(location.md5, sb_state: "table_scores")`. |
| ISOL-04 | `console.warn` capture verifying JS filter actually runs on rejected broadcasts | `shouldAcceptOperation` in scoreboard context calls `console.warn("🚫 SCOREBOARD MIX-UP PREVENTED: ...")` when `selectorTableMonitorId !== pageContext.tableMonitorId`. Captured via Selenium browser logs API: `page.driver.browser.logs.get(:browser)`. |
</phase_requirements>

---

## Summary

Phase 18 writes two-session Capybara/Selenium system tests that verify the client-side broadcast isolation filter works correctly for each of the two delivery paths (morph and dispatch_event) and the `table_scores` page context. Phase 17 delivered all necessary infrastructure: the async cable adapter, `local_server?` override, `in_session`/`visit_scoreboard`/`wait_for_actioncable_connection` helpers, and a passing smoke test. Phase 18 builds directly on that foundation.

The architecture is a global ActionCable stream (`"table-monitor-stream"`) where every connected client receives every broadcast. All isolation is client-side JavaScript in `table_monitor_channel.js`. This means only browser-level system tests can verify the isolation — Ruby-only tests cannot exercise the JS filter. Two-session Capybara tests (Session A watching table monitor TM-A, Session B watching TM-B) trigger a broadcast for TM-B and verify Session A's DOM is unchanged while Session B's DOM updates correctly.

The critical design risk is vacuous assertions: if Session A's page does not contain `#full_screen_table_monitor_B`, then CableReady finding no matching element and the JS filter rejecting the operation are indistinguishable. ISOL-04 (console.warn capture) is the solution — it proves the filter code path was actually reached rather than the operation simply finding no DOM target.

**Primary recommendation:** Write one isolation test file with two test classes (morph + score:update), both using shared fixture setup from a `setup` helper. Use `page.driver.browser.logs.get(:browser)` for console.warn capture. For the `score_data` path, call `TableMonitorJob.perform_now(id, "score_data", player: "playera")` directly rather than engineering a data change that triggers `ultra_fast_score_update?`.

---

## Project Constraints (from CLAUDE.md)

- Minitest (not RSpec) — use `test "..." do`, `assert_*`, `refute_*`
- `frozen_string_literal: true` at top of all Ruby files
- `bin/rails test test/system/` to run system tests
- Tests must not break existing suite — 751 runs, 0 failures baseline from Phase 17
- No transactional tests in system tests (`use_transactional_tests = false` implied by smoke test teardown pattern)
- Manual teardown required: `@game.destroy`, `update_columns` resets (system tests do not auto-roll back)
- German business logic comments in code, English for technical terms

---

## Standard Stack

### What Phase 17 Delivered (Available Now)

| Artifact | Location | Confirmed Status |
|----------|----------|-----------------|
| `adapter: async` for test | `config/cable.yml` line 5-6 | VERIFIED in 17-VERIFICATION.md |
| `local_server?` override | `ApplicationSystemTestCase` setup/teardown | VERIFIED in 17-VERIFICATION.md |
| `in_session(name, &block)` | `test/application_system_test_case.rb` line 43 | VERIFIED |
| `visit_scoreboard(tm, locale:)` | `test/application_system_test_case.rb` line 48 | VERIFIED |
| `wait_for_actioncable_connection(timeout:)` | `test/application_system_test_case.rb` line 59 | VERIFIED |
| `data-cable-connected="true"` DOM marker | `table_monitor_channel.js` line 362 (`connected()` callback) | VERIFIED |
| Smoke test (single-session baseline) | `test/system/table_monitor_broadcast_smoke_test.rb` | VERIFIED passing headless |
| Fixture: `table_monitors(:one)` | id: 50_000_001, state: "new" | VERIFIED |
| Fixture: `tables(:one)` | id: 50_000_001, linked to location:one + table_kind_id: 50_000_001 | VERIFIED |

### What Phase 18 Needs to Add

| Item | Why | How |
|------|-----|-----|
| Second TableMonitor fixture | Two-session tests require two distinct TM records | Add `two:` entry to `test/fixtures/table_monitors.yml` with id: 50_000_002 |
| Second Table fixture | TM-two needs a table FK chain | Add `two:` entry to `test/fixtures/tables.yml` with id: 50_000_002, different `name`, linked to same location:one and table_kind_id: 50_000_001 |
| Second Game (created in test setup) | TM-two's scoreboard must render (show action redirects if no game) | `Game.find_or_create_by!(id: 50_000_101)` in test setup (same pattern as smoke test's 50_000_100) |
| New test file(s) | ISOL-01 through ISOL-04 | `test/system/table_monitor_isolation_test.rb` |

**Installation:** No new gems required — all dependencies (Capybara, Selenium, CableReady) are already in `Gemfile.lock`.

---

## Architecture Patterns

### Recommended Project Structure

```
test/
├── system/
│   ├── table_monitor_broadcast_smoke_test.rb   (Phase 17 — do not modify)
│   └── table_monitor_isolation_test.rb          (Phase 18 — new)
└── fixtures/
    ├── table_monitors.yml                        (add :two entry)
    └── tables.yml                                (add :two entry)
```

### Pattern 1: Two-Session Morph Isolation Test (ISOL-01 + ISOL-04)

**What:** Open Session A on TM-A scoreboard, Session B on TM-B scoreboard. Trigger broadcast for TM-B. Assert Session B updates, Session A does not. Capture console.warn from Session A to prove filter ran.

**Trigger mechanism:** `@tm_b.ready!` + `TableMonitorJob.perform_now(@tm_b.id)` — the `else` branch (no `operation_type`) renders `_show.html.erb` and broadcasts `inner_html` to `#full_screen_table_monitor_B`.

**Positive assertion (Session B):** `assert_selector "#full_screen_table_monitor_#{@tm_b.id}", text: /Frei/i`

**Negative assertion options (Session A):**

Option A — DOM timestamp marker (proves no DOM change):
```ruby
# Before broadcast: stamp current content
before_text = within("#full_screen_table_monitor_#{@tm_a.id}") { page.text }
# After broadcast wait: content unchanged
assert_equal before_text, within("#full_screen_table_monitor_#{@tm_a.id}") { page.text }
```

Option B — assert_no_text (simpler, checks specific content did not bleed):
```ruby
# TM-B transitions to "ready" → renders "Frei"
# Session A must NOT show "Frei" (it has no game or shows its own state)
# But this is fragile if both TMs could independently show "Frei"
```

Option C — console.warn capture (ISOL-04, most reliable):
```ruby
# Switch to Session A context, check browser logs
in_session(:scoreboard_a) do
  logs = page.driver.browser.logs.get(:browser)
  warn_logs = logs.select { |l| l.message.include?("SCOREBOARD MIX-UP PREVENTED") }
  assert warn_logs.any?, "Expected JS filter to emit console.warn for rejected broadcast but found none"
end
```

**Recommended:** Use console.warn capture (Option C) as primary negative assertion — it directly verifies the filter ran. Supplement with a quick DOM text check (Option A) as belt-and-suspenders.

**Example test skeleton:**
```ruby
# Source: test/system/table_monitor_broadcast_smoke_test.rb (established pattern)
test "ISOL-01: scoreboard A DOM unchanged when table B state changes (paired)" do
  # Session A: watch TM-A
  in_session(:scoreboard_a) do
    visit_scoreboard(@tm_a)
    assert_selector "#full_screen_table_monitor_#{@tm_a.id}"
    wait_for_actioncable_connection
  end
  # Session B: watch TM-B
  in_session(:scoreboard_b) do
    visit_scoreboard(@tm_b)
    assert_selector "#full_screen_table_monitor_#{@tm_b.id}"
    wait_for_actioncable_connection
  end

  # Trigger broadcast for TM-B only
  @tm_b.reload
  @tm_b.ready!
  TableMonitorJob.perform_now(@tm_b.id)

  # POSITIVE: Session B receives and applies update
  in_session(:scoreboard_b) do
    assert_selector "#full_screen_table_monitor_#{@tm_b.id}", text: /Frei/i, wait: 10
  end

  # NEGATIVE: Session A DOM unchanged + JS filter ran (ISOL-04)
  in_session(:scoreboard_a) do
    logs = page.driver.browser.logs.get(:browser)
    warn_logs = logs.select { |l| l.message.include?("SCOREBOARD MIX-UP PREVENTED") }
    assert warn_logs.any?, "Expected JS filter to emit MIX-UP warning for rejected broadcast"
    # Belt-and-suspenders: Session A shows its own state text, not TM-B's "Frei"
    # (This is valid if TM-A is in "new" state which renders no "Frei" text)
    refute_selector "#full_screen_table_monitor_#{@tm_b.id}"
  end
end
```

### Pattern 2: score:update Dispatch Event Isolation Test (ISOL-02)

**What:** The `score_data` operation type in `TableMonitorJob` broadcasts a CableReady `dispatch_event` with name `"score:update"`. The event listener at the top of `table_monitor_channel.js` (line 10-40) filters by `currentTableMonitorId !== tableMonitorId`. This is a completely separate code path from the morph/`shouldAcceptOperation` filter.

**Trigger mechanism:** Call `TableMonitorJob.perform_now(@tm_b.id, "score_data", player: "playera")` directly. This bypasses the `after_update_commit` logic entirely — the job's `score_data` branch executes unconditionally given the right `operation_type`. No AASM transition required.

**Important:** The `score_data` branch requires `table_monitor.get_options!` to succeed, which means `table_monitor.data` must have minimal valid structure and the table must have a game attached. Both conditions are satisfied by the same setup pattern as the smoke test (set `game_id`, initialize `data: {}`).

**Score values:** The job reads `table_monitor.data["playera"]["innings_redo_list"]` and `table_monitor.options[:player_a][:result]`. With `data: {}`, `get_options!` will set defaults. The score broadcast fires regardless of whether the values are meaningful — the test only needs to verify isolation, not score accuracy.

**Positive assertion (Session B — score update arrived):**
The event listener modifies DOM elements with class `.main-score[data-player="playera"]`, `.score-display[data-player="playera"]`, `.inning-score[data-player="playera"]`. But these elements only exist on a rendered scoreboard with player data. A safer DOM side-effect check:

```ruby
# Alternative: inject a test-only marker via evaluate_script
in_session(:scoreboard_b) do
  # Listen for score:update event and record it fired
  page.execute_script(<<~JS)
    window._scoreUpdateReceived = false;
    document.addEventListener('score:update', function(e) {
      if (parseInt(e.detail.tableMonitorId) === #{@tm_b.id}) {
        window._scoreUpdateReceived = true;
      }
    }, { once: true });
  JS
end

TableMonitorJob.perform_now(@tm_b.id, "score_data", player: "playera")

in_session(:scoreboard_b) do
  assert page.evaluate_script("window._scoreUpdateReceived === true"),
         "Expected score:update event for TM-B to be received on Session B"
end
```

**Negative assertion (Session A — filter blocked it):**
```ruby
in_session(:scoreboard_a) do
  page.execute_script(<<~JS)
    window._wrongScoreUpdateReceived = false;
    document.addEventListener('score:update', function(e) {
      if (parseInt(e.detail.tableMonitorId) === #{@tm_b.id}) {
        window._wrongScoreUpdateReceived = true;
      }
    }, { once: true });
  JS
end

TableMonitorJob.perform_now(@tm_b.id, "score_data", player: "playera")

# Give Session A time to process (if the event fires, it would be captured quickly)
sleep 1  # Acceptable here: we're asserting absence, not presence

in_session(:scoreboard_a) do
  refute page.evaluate_script("window._wrongScoreUpdateReceived === true"),
         "Expected score:update for TM-B to be blocked on Session A"
end
```

Note: The JS filter for `score:update` in `table_monitor_channel.js` lines 486-504 checks `firstOp.name === 'score:update' && pageContext.type === 'scoreboard'` and routes it through, then the event listener itself at line 16-19 does `parseInt(currentTableMonitorId) !== parseInt(tableMonitorId) → return`. So Session A (watching TM-A) will receive the CableReady `dispatchEvent` call but the event listener silently returns without DOM mutation. No `console.warn` is emitted for the dispatch_event path — the JS `window._wrongScoreUpdateReceived` marker approach is the reliable verification method.

### Pattern 3: table_scores Overview Page Context (ISOL-03)

**What:** The `table_scores` page renders `<turbo-frame id="table_scores">`. When `getPageContext()` returns `{type: 'table_scores'}`, `shouldAcceptOperation` rejects all `#full_screen_table_monitor_N` selectors and accepts only `#table_scores` and `#teaser_N` selectors.

**URL to visit:** `scoreboard_location_path(@location.md5, sb_state: "table_scores")` — but this requires a session cookie. The `LocationsController#scoreboard` action sets `session[:sb_state]` and renders `scoreboard_table_scores.html.erb`. For system tests the `visit` call handles the HTTP session automatically.

**Important:** The location must have tables that have active games for `_table_scores.html.erb` to render teasers (the partial filters via `table.table_monitor.andand.game.present?`). Both test TableMonitors must have a game assigned.

**Trigger:** `TableMonitorJob.perform_now(@tm_a.id)` (full scoreboard broadcast) — this broadcasts `#full_screen_table_monitor_A`. The `table_scores` page should NOT update a `#full_screen_*` element (none exists) and SHOULD accept `#table_scores` and `#teaser_A` updates.

**Negative assertion:** `#full_screen_table_monitor_A` must not exist on the table_scores page (it doesn't by design — the view doesn't render it). Use `refute_selector "#full_screen_table_monitor_#{@tm_a.id}"` as a structural check, but supplement with console log inspection if `table_scores` emits any warnings.

**Positive assertion:** After triggering a `table_scores` job (`TableMonitorJob.perform_now(@tm_a.id, "table_scores")`), the `#table_scores` container should update.

### Anti-Patterns to Avoid

- **Asserting absent DOM elements for isolation:** `refute_selector "#full_screen_table_monitor_B"` on scoreboard A passes even if the filter is deleted entirely, because the element never existed on that page. Always pair with console.warn capture.
- **Using `sleep` for subscription timing:** The `wait_for_actioncable_connection` helper already provides deterministic synchronization. Add it to both sessions before triggering any broadcast.
- **Triggering broadcasts before both sessions are connected:** Always `wait_for_actioncable_connection` in both sessions before `perform_now`. Out-of-order subscription means the broadcast fires before the subscriber map registers the second client — the client misses it and the test gives a false result.
- **Using `perform_later` (async queue):** The test queue adapter does not auto-execute jobs. Always use `perform_now`.
- **Forgetting teardown for system tests:** System tests have no transactional rollback. All Games and state changes created in setup must be destroyed/reset in teardown.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Browser log capture | Custom JS injected log sink | `page.driver.browser.logs.get(:browser)` | Selenium's native log API works in headless Chrome; captures all console.warn calls made before the call |
| Waiting for JS event | `sleep N` | `page.evaluate_script("window._flag")` polled via Capybara's `assert_selector`-driven loop or a short loop | Deterministic without arbitrary delays |
| Subscription timing | `sleep 2` after `visit` | `wait_for_actioncable_connection` (already in Phase 17 helpers) | DOM-polling, no arbitrary delay |
| Session isolation | Managing cookies manually | `Capybara.using_session` (wrapped by `in_session`) | Built-in per-session cookie jar |

---

## Common Pitfalls

### Pitfall 1: Vacuous Isolation Assertions

**What goes wrong:** `refute_selector "#full_screen_table_monitor_B"` on scoreboard A always passes because that element is never present on A's page. The filter logic is never verified.

**How to avoid:** Use `page.driver.browser.logs.get(:browser)` to capture `console.warn("🚫 SCOREBOARD MIX-UP PREVENTED")`. This directly proves `shouldAcceptOperation` ran and rejected the operation. If no warn appears, the filter did not run (either the broadcast wasn't received or the filter was bypassed).

**Warning signs:** Isolation tests pass in under 1 second. No console.warn in captured logs after a foreign broadcast.

### Pitfall 2: Subscription Not Established Before Broadcast

**What goes wrong:** `TableMonitorJob.perform_now` fires before Session B's WebSocket subscription is confirmed. The broadcast hits the async adapter's PubSub before the subscriber is registered. The client misses the message and the positive assertion times out.

**How to avoid:** Call `wait_for_actioncable_connection` inside both `in_session` blocks before executing `perform_now`. The helper polls `html[data-cable-connected='true']` which is set by the JS `connected()` callback — confirmed only after the server-side subscription is active.

**Warning signs:** Positive assertion times out (Session B never sees the update). Tests are flaky: pass on second run.

### Pitfall 3: score_data Job Requires Valid options structure

**What goes wrong:** `TableMonitorJob.perform_now(@tm_b.id, "score_data", player: "playera")` calls `table_monitor.get_options!(locale)` then reads `options[:player_a][:result]` and `data["playera"]["innings_redo_list"]`. If `data` is empty hash `{}`, `data["playera"]` is nil and raises `NoMethodError`.

**How to avoid:** Initialize `data` to a minimal valid structure in test setup. Review what `get_options!` requires for the `score_data` path. Alternatively, pre-populate `data` with: `{"playera" => {"innings_redo_list" => [5]}, "playerb" => {"innings_redo_list" => [3]}}`.

**Warning signs:** `NoMethodError: undefined method [] for nil:NilClass` in test output when calling `perform_now` with `"score_data"`.

### Pitfall 4: table_scores Page Requires Location with Tables Having Active Games

**What goes wrong:** `_table_scores.html.erb` renders teasers only for `tables.select { |t| t.table_monitor.andand.game.present? }`. If no tables have games, the `#table_scores` container is empty and no `#teaser_N` elements exist. Assertions on teaser content always fail.

**How to avoid:** Ensure both test TableMonitors have `game_id` set and Games exist before visiting the `table_scores` URL. The same `Game.find_or_create_by!(id: 50_000_100)` pattern from the smoke test works — just assign it to both TMs in setup.

**Warning signs:** `table_scores` page loads successfully but `#teaser_N` elements are absent.

### Pitfall 5: Selenium Browser Logs API Not Available in Headless Chrome

**What goes wrong:** `page.driver.browser.logs.get(:browser)` raises `Selenium::WebDriver::Error::UnknownCommandError` in some Chrome/ChromeDriver versions that have deprecated the logs API.

**How to avoid:** Test log capture in the smoke test environment first. If unavailable, use the DOM marker approach: inject `window._filterRan` via `page.execute_script` and a monkey-patch to `console.warn`, then read back via `page.evaluate_script`.

```ruby
# DOM marker fallback for ISOL-04
page.execute_script(<<~JS)
  window._mixupPreventedCount = 0;
  const _origWarn = console.warn;
  console.warn = function(...args) {
    if (args[0] && String(args[0]).includes("SCOREBOARD MIX-UP PREVENTED")) {
      window._mixupPreventedCount++;
    }
    _origWarn.apply(console, args);
  };
JS
# ... trigger broadcast ...
count = page.evaluate_script("window._mixupPreventedCount")
assert count > 0, "Expected JS filter console.warn but got 0 occurrences"
```

**Warning signs:** `Selenium::WebDriver::Error::UnknownCommandError` when calling `logs.get(:browser)`.

### Pitfall 6: Two Session Contexts Sharing `page` Reference

**What goes wrong:** Capybara's `page` object refers to the currently active session. Accessing `page` outside an `in_session` block refers to the default session, not the named session. Assertions made outside `in_session` blocks evaluate against the wrong browser.

**How to avoid:** All `assert_selector`, `page.evaluate_script`, and `page.driver` calls must be inside their respective `in_session(:scoreboard_a)` or `in_session(:scoreboard_b)` blocks.

**Warning signs:** Log capture or DOM assertions on "Session A" actually reflect Session B's state.

---

## Code Examples

### Fixture Addition for Second TableMonitor

```yaml
# test/fixtures/table_monitors.yml (add to existing file)
two:
  id: 50_000_002
  state: "new"
  name: "Table Monitor 2"
  data: '{}'
  ip_address: "192.168.1.2"
  panel_state: "pointer_mode"
  current_element: "pointer_mode"
  created_at: <%= 1.year.ago %>
  updated_at: <%= 1.day.ago %>
```

```yaml
# test/fixtures/tables.yml (add to existing file)
two:
  id: 50_000_002
  name: "Table Two"
  table_monitor_id: 50_000_002
  location: one
  table_kind_id: 50_000_001
```

### Shared Setup Pattern for Isolation Tests

```ruby
# Source: established in test/system/table_monitor_broadcast_smoke_test.rb
setup do
  @tm_a = table_monitors(:one)
  @tm_b = table_monitors(:two)

  # Reset both to "new" state (bypasses callbacks and AASM guards)
  @tm_a.update_columns(state: "new", data: {})
  @tm_b.update_columns(state: "new", data: {})

  # Create Games so scoreboard show action renders rather than redirecting
  @game_a = Game.find_or_create_by!(id: 50_000_100)
  @game_b = Game.find_or_create_by!(id: 50_000_101)
  @tm_a.update_columns(game_id: @game_a.id)
  @tm_b.update_columns(game_id: @game_b.id)
end

teardown do
  @tm_a.update_columns(game_id: nil, state: "new", data: {})
  @tm_b.update_columns(game_id: nil, state: "new", data: {})
  @game_a&.destroy
  @game_b&.destroy
end
```

### Console.warn Capture (ISOL-04 primary approach)

```ruby
# Source: Selenium browser logs API — direct codebase analysis [ASSUMED for API details]
in_session(:scoreboard_a) do
  logs = page.driver.browser.logs.get(:browser)
  warn_logs = logs.select { |l| l.message.include?("SCOREBOARD MIX-UP PREVENTED") }
  assert warn_logs.any?,
    "Expected JS filter to emit SCOREBOARD MIX-UP PREVENTED console.warn for rejected broadcast on scoreboard A, but found none. " \
    "Check that: (1) Session A is subscribed before broadcast fires, (2) broadcast for TM-B actually reached the client, " \
    "(3) getPageContext() correctly identified the page as 'scoreboard' type."
end
```

### JS Event Listener Marker (ISOL-02 score:update verification)

```ruby
# Install listener before broadcast fires
in_session(:scoreboard_b) do
  page.execute_script(<<~JS)
    window._scoreUpdateForB = null;
    document.addEventListener('score:update', function(e) {
      if (parseInt(e.detail.tableMonitorId) === #{@tm_b.id}) {
        window._scoreUpdateForB = e.detail;
      }
    }, { once: true });
  JS
end
in_session(:scoreboard_a) do
  page.execute_script(<<~JS)
    window._scoreUpdateForBOnA = false;
    document.addEventListener('score:update', function(e) {
      if (parseInt(e.detail.tableMonitorId) === #{@tm_b.id}) {
        window._scoreUpdateForBOnA = true;
      }
    }, { once: true });
  JS
end

# Trigger score:update for TM-B
TableMonitorJob.perform_now(@tm_b.id, "score_data", player: "playera")

# POSITIVE: Session B received the event
in_session(:scoreboard_b) do
  received = page.evaluate_script("window._scoreUpdateForB")
  assert received, "Expected score:update event for TM-B to fire on Session B"
end

# NEGATIVE: Session A's event listener did not fire for TM-B's event
# (JS filter in table_monitor_channel.js line 497-499 blocks score:update for non-scoreboard pages,
#  and the event listener line 16-19 returns early if tableMonitorId !== currentTableMonitorId)
in_session(:scoreboard_a) do
  # Brief pause — if the event were going to fire it would have done so by now
  assert_no_selector "html[data-wrong-score-received]"  # won't exist — just a timing hook
  fired = page.evaluate_script("window._scoreUpdateForBOnA")
  refute fired, "Expected score:update for TM-B to be blocked on Session A scoreboard"
end
```

### Direct score_data Trigger with Valid Data

```ruby
# Ensure data has minimal structure for score_data path
@tm_b.update_columns(
  data: {
    "playera" => { "innings_redo_list" => [5] },
    "playerb" => { "innings_redo_list" => [3] }
  }.to_json
)
TableMonitorJob.perform_now(@tm_b.id, "score_data", player: "playera")
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Passing `TableMonitor` object to job | Always pass Integer ID to `TableMonitorJob` | Phase 17 (already enforced) | Must use `perform_now(@tm_b.id)` not `perform_now(@tm_b)` — job raises `ArgumentError` for non-Integer |
| Checking subscription via `sleep` | `wait_for_actioncable_connection` polling `html[data-cable-connected='true']` | Phase 17 | Deterministic synchronization |

---

## Critical Implementation Decisions for Planner

### Decision A: score_data Data Initialization

The `score_data` branch in `TableMonitorJob` (line 136-165) reads:
```ruby
player_option = player_key == "playera" ? table_monitor.options[:player_a] : table_monitor.options[:player_b]
innings_redo_list = table_monitor.data[player_key]["innings_redo_list"] || []
```

`table_monitor.data` is a serialized JSON text field. When set to `'{}'`, `data["playera"]` returns `nil` → `nil["innings_redo_list"]` raises `NoMethodError`. Test setup for ISOL-02 must initialize `data` with a minimal player structure before calling `perform_now(@tm_b.id, "score_data", player: "playera")`.

### Decision B: table_scores URL Construction

The `table_scores` page is served by `LocationsController#scoreboard` with session state. The test must:
1. Visit `scoreboard_location_path(@location.md5, sb_state: "table_scores")` (or equivalent named route)
2. The controller auto-logs in as the scoreboard user (`User.scoreboard`) if no current user — this works without manual authentication in system tests
3. Verify the `#table_scores` turbo-frame is present on the page before asserting

The `scoreboard_location_path` helper requires `@location.md5` — use `table_monitors(:one).table.location.md5` (fixture: `"abc123def456abc123def456abc12301"`).

### Decision C: ISOL-01 Negative Assertion Strategy

The planner must choose between:
1. **console.warn only (ISOL-04 combined):** Capture browser logs and assert SCOREBOARD MIX-UP PREVENTED appears. Directly proves filter ran.
2. **console.warn + DOM state text:** Additionally assert Session A's scoreboard container does not contain TM-B's state text ("Frei"). Belt-and-suspenders but fragile if both TMs show same text.
3. **console.warn + DOM marker injection:** Most rigorous — inject a `window._lastBroadcastReceived` counter that increments on any `CableReady.perform` call, and assert Session A's count did not increase.

Research recommendation: Option 1 (console.warn alone) is sufficient for ISOL-01 + ISOL-04 combined. Option 2 adds minimal value but costs nothing. Option 3 requires JS monkey-patching `CableReady.perform` which is fragile.

### Decision D: Test File Organization

Research recommendation: **Single file `test/system/table_monitor_isolation_test.rb`** with one class `TableMonitorIsolationTest < ApplicationSystemTestCase`. All four requirements (ISOL-01 through ISOL-04) can be covered by two test methods:

- `test "ISOL-01 + ISOL-04: morph path isolation with console.warn filter proof"` — covers ISOL-01 (paired positive/negative DOM assertions) and ISOL-04 (console.warn capture in the same negative assertion)
- `test "ISOL-02: score:update dispatch event path isolation"` — covers ISOL-02 (JS event listener marker approach)
- `test "ISOL-03: table_scores overview page context"` — covers ISOL-03 (separate visit to table_scores URL, assert structural correctness)

Three test methods in one class. Clean, no cross-file fixture duplication.

---

## Open Questions (RESOLVED)

1. **Selenium browser logs API availability**
   - What we know: Chrome/ChromeDriver supports `logs.get(:browser)` via the WebDriver protocol; Selenium gem wraps this
   - What's unclear: Whether the current ChromeDriver version in the test environment supports it (some recent ChromeDriver versions dropped the API under W3C-only mode)
   - Recommendation: Verify with a one-liner in the smoke test first. If unavailable, use the `console.warn` override via `execute_script` (DOM marker fallback documented in Pitfall 5).

2. **`scoreboard_location_path` route name**
   - What we know: `app/views/table_monitors/_show.html.erb` references `scoreboard_location_path(@location.md5, sb_state: "welcome")` so the route exists
   - What's unclear: Whether the route name is `scoreboard_location_path` or something else
   - Recommendation: Verify with `bin/rails routes | grep scoreboard` before writing ISOL-03. The route is likely a member action on `locations` resources.

3. **data structure needed for score_data branch**
   - What we know: The branch reads `data["playera"]["innings_redo_list"]` and `options[:player_a][:result]`
   - What's unclear: Whether `get_options!` initializes `player_a` and `player_b` in options from an empty `data` hash, or whether it also reads from `data`
   - Recommendation: Test `@tm_b.get_options!(:de); @tm_b.options[:player_a]` in a console session before writing the test, or initialize `data` with the minimal structure documented in Code Examples.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 18 is a pure test-writing phase. All external dependencies (Chrome, Selenium, Rails, PostgreSQL, Redis) were verified available during Phase 17. No new external tools required.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `page.driver.browser.logs.get(:browser)` works in the project's headless Chrome setup | Code Examples, Pitfall 5 | ISOL-04 needs the DOM marker fallback instead; adds one task |
| A2 | `scoreboard_location_path` is the correct route helper name for the table_scores page | Decision B | Must look up actual route name before writing ISOL-03 test |
| A3 | `get_options!` with empty `data: {}` will raise when `score_data` branch reads `data["playera"]` | Decision A, Pitfall 3 | If `get_options!` initializes defaults that make `data["playera"]` non-nil, extra data initialization is unnecessary |

---

## Sources

### Primary (HIGH confidence — direct codebase inspection)
- `app/javascript/channels/table_monitor_channel.js` — `shouldAcceptOperation` (line 107), `getPageContext` (line 43), `console.warn` (line 126-127), `score:update` listener (line 10-40), `dispatch_event` handling (line 486-504)
- `app/channels/table_monitor_channel.rb` — subscription guard, single shared stream `"table-monitor-stream"`
- `app/jobs/table_monitor_job.rb` — `score_data` branch (line 136-165), default full-scoreboard branch (line 229+), `perform` argument validation
- `app/models/table_monitor.rb` — `ultra_fast_score_update?` (line 231), `simple_score_update?` (line 255), `after_update_commit` logic (line 79-153), `@collected_data_changes` accumulation (line 461-464)
- `test/application_system_test_case.rb` — Phase 17 helpers: `in_session`, `visit_scoreboard`, `wait_for_actioncable_connection`, `local_server?` override
- `test/system/table_monitor_broadcast_smoke_test.rb` — Established patterns for fixture setup, teardown, `perform_now`, `assert_selector`
- `test/fixtures/table_monitors.yml` — Existing `:one` entry (id: 50_000_001)
- `test/fixtures/tables.yml` — Existing `:one` entry with location/table_kind chain
- `app/views/table_monitors/_scoreboard.html.erb` — `data-table-monitor-root="scoreboard"` (line 34), `data-table-monitor-id="<%= table_monitor.id %>"` (line 35)
- `app/views/layouts/application.html.erb` — `meta[name="scoreboard-table-monitor-id"]` (line 26)
- `app/views/locations/scoreboard_table_scores.html.erb` — `<turbo-frame id="table_scores">` (line 24)
- `app/views/locations/_table_scores.html.erb` — Filter: `table.table_monitor.andand.game.present?` (line 18)
- `config/cable.yml` — `adapter: async` for test (confirmed Phase 17)
- `.planning/research/FEATURES.md` — Feature dependency map, vacuous assertion anti-pattern analysis
- `.planning/research/PITFALLS.md` — Nine documented pitfalls with prevention strategies
- `.planning/phases/17-infrastructure-configuration/17-VERIFICATION.md` — Phase 17 completeness evidence

### Tertiary (LOW confidence — behavioral claim without live test run)
- Score_data branch data requirements (A3 above) — inferred from code reading; not verified by running the job

---

## Metadata

**Confidence breakdown:**
- Infrastructure status: HIGH — Phase 17 VERIFICATION.md confirms all helpers are in place
- Test trigger mechanisms: HIGH — job code read directly; both morph and score:update paths fully traced
- JS filter behavior: HIGH — direct source code analysis, not inference
- console.warn capture via Selenium logs: MEDIUM — API availability not verified in this environment (A1)
- table_scores URL route name: MEDIUM — route exists but name not confirmed (A2)

**Research date:** 2026-04-11
**Valid until:** 2026-05-11 (stable codebase — no external dependencies)
