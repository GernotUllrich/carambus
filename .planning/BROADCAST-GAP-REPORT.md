# Broadcast Isolation Gap Report

**Generated:** 2026-04-11
**Milestone:** v3.0 — Broadcast Isolation Testing
**Author:** Phase 17-19 Execution (Claude Sonnet 4.6)
**Status:** Final — all 11 v1 requirements verified

---

## 1. Executive Summary

All 11 v1 broadcast isolation requirements (INFRA-01 through DOC-01) passed across Phases 17-19 of the v3.0 milestone. The `TableMonitorChannel` correctly filters CableReady operations client-side so that scoreboard sessions never display state changes from a different `TableMonitor`. This was verified under single-session, two-session, and three-session concurrent scenarios including 6-iteration rapid-fire alternating broadcasts. However, a structural architectural risk remains: the server broadcasts every AASM state change to a single global `table-monitor-stream`, and ALL connected clients receive ALL broadcasts. Isolation is enforced entirely by client-side JavaScript in `shouldAcceptOperation` and the `score:update` DOM event listener inside `table_monitor_channel.js`. A JavaScript bug, unhandled selector pattern, or new operation type introduced without updating the filter logic would immediately cause broadcast bleed across unrelated scoreboards. This risk is acceptable for the current production use case and is documented as FIX-01/FIX-02 for a future v2 milestone — the v3.0 scope was verification only, not remediation.

---

## 2. Scope

The following 11 v1 requirements were verified across Phases 17, 18, and 19:

### Infrastructure (Phase 17)

- **INFRA-01** — System test cable adapter configured so ActionCable broadcasts reach real browser WebSocket connections
- **INFRA-02** — `local_server?` returns true in system test environment so channel subscriptions are accepted
- **INFRA-03** — `ApplicationSystemTestCase` base class with multi-session Capybara helpers, AR connection pool config, and suppress_broadcast reset
- **INFRA-04** — Single-session smoke test proving end-to-end broadcast delivery (state change → job → ActionCable → DOM update)

### Isolation (Phase 18)

- **ISOL-01** — Two-session morph path isolation test — scoreboard A unchanged when table B state changes (paired positive/negative)
- **ISOL-02** — Two-session `score:update` dispatch event path isolation test (separate JS code path, paired positive/negative)
- **ISOL-03** — `table_scores` overview page context isolation test
- **ISOL-04** — `console.warn` capture verifying JS filter actually runs on rejected broadcasts (prevents vacuous assertions)

### Concurrency (Phase 19)

- **CONC-01** — Rapid-fire AASM state transitions with multiple simultaneous sessions verifying no broadcast bleed
- **CONC-02** — Three+ simultaneous browser sessions on different tables under concurrent state changes

### Documentation (Phase 19)

- **DOC-01** — Gap report documenting any broadcast isolation failures found during testing (fix deferred)

---

## 3. Test Results Table

| Requirement | Phase | Test / Artifact | Result | Notes |
|-------------|-------|-----------------|--------|-------|
| INFRA-01 | 17 | `config/cable.yml` — async adapter for test env | PASS | Switched from `test` to `async` adapter; broadcasts reach real WebSocket connections |
| INFRA-02 | 17 | `ApplicationSystemTestCase` setup/teardown — `Carambus.config.carambus_api_url` override | PASS | `local_server?` returns true during system tests; channel subscriptions accepted |
| INFRA-03 | 17 | `test/application_system_test_case.rb` — `in_session`, `visit_scoreboard`, `wait_for_actioncable_connection` helpers | PASS | Multi-session Capybara helpers established; AR pool increased to 10 |
| INFRA-04 | 17 | `test/system/table_monitor_broadcast_smoke_test.rb` | PASS | Full chain: `ready!` → `TableMonitorJob.perform_now` → CableReady `inner_html` → "Frei" in browser DOM; 1 run, 3 assertions |
| ISOL-01 | 18 | `test_ISOL-01...morph path` in `table_monitor_isolation_test.rb` | PASS | Scoreboard A DOM unchanged after TM-B broadcast; `_mixupPreventedCount > 0` proves JS filter ran |
| ISOL-02 | 18 | `test_ISOL-02...score:update` in `table_monitor_isolation_test.rb` | PASS | JS filter replication confirms `score:update` event correctly identified as cross-table; structural `refute_selector` as primary DOM proof |
| ISOL-03 | 18 | `test_ISOL-03...table_scores` in `table_monitor_isolation_test.rb` | PASS | `table_scores` page rejects `full_screen` broadcasts and accepts `#table_scores` updates |
| ISOL-04 | 18 | `window._mixupPreventedCount` DOM marker counter (part of ISOL-01 test) | PASS | `console.warn("SCOREBOARD MIX-UP PREVENTED")` intercepted and counted; proves filter runs on rejected broadcasts (not a vacuous assertion) |
| CONC-01 | 19 | `test_CONC-01...rapid-fire` in `table_monitor_isolation_test.rb` | PASS | 6-iteration alternating loop; Session A filter counter >= 3 (one per TM-B broadcast); no DOM bleed |
| CONC-02 | 19 | `test_CONC-02...three sessions` in `table_monitor_isolation_test.rb` | PASS | All six cross-table directions (A→B, A→C, B→A, B→C, C→A, C→B) verified isolated with three simultaneous browser sessions |
| DOC-01 | 19 | `.planning/BROADCAST-GAP-REPORT.md` (this document) | PASS | All Phase 17-19 results, architectural risk, Phase 18 findings, and FIX-01/FIX-02 deferred fix references documented |

**Final test suite result after Phase 19:** 6 runs (5 isolation + 1 smoke), 49 assertions, 0 failures, 0 errors.

---

## 4. Known Architectural Gap

### The Structural Risk

The `TableMonitorChannel` subscribes all connected clients to a single shared ActionCable stream:

```ruby
# app/channels/table_monitor_channel.rb
stream_from "table-monitor-stream"
```

When any `TableMonitor` fires an AASM state transition, `TableMonitorJob` broadcasts a CableReady operation to this global `table-monitor-stream`. Every connected browser — regardless of which table it is displaying — receives the broadcast payload.

### Where Filtering Happens

Isolation is enforced entirely client-side in two places within `app/javascript/channels/table_monitor_channel.js`:

1. **`shouldAcceptOperation` function (lines 107-196):** Inspects the incoming operation's `selector` (e.g., `#full_screen_table_monitor_50000002`) and compares it against the current page's `tableMonitorId` detected via `[data-table-monitor-root="scoreboard"]` data attribute or meta tag. Returns `false` for foreign table monitor IDs, causing the operation to be filtered from `CableReady.perform`.

2. **`score:update` DOM event listener (lines 10-40):** The `CableReady.perform` call for `dispatch_event` operations fires the event on `document` before any per-session filtering can occur. The listener then reads `currentTableMonitorId` from the DOM and returns early if it does not match `tableMonitorId` from the event detail.

### Risk Profile

A JavaScript bug, unhandled `selector` pattern, or new CableReady operation type introduced without updating `shouldAcceptOperation` would immediately allow broadcasts to bleed into unrelated scoreboard sessions. Specific failure modes:

- A new operation type (e.g., `morph`, `append`) sent to a selector that does not match the `#full_screen_table_monitor_N` pattern falls through to the `document.querySelector(selector)` existence check — if an element with that selector exists on another scoreboard page, the operation is accepted.
- The `unknown` page context (when neither `[data-table-monitor-root="scoreboard"]`, `#table_scores`, nor `turbo-frame#teasers` is detected) conservatively rejects `full_screen` operations but may accept other selectors via element existence check.
- Adding a new broadcast path (e.g., from a new Job or Channel method) without updating `shouldAcceptOperation` bypasses all filtering.

### Current Risk Assessment

This architecture is correct for the current production use case: a small number of tableMonitor displays (typically 1-8 per location) connecting to a single shared stream. The client-side filter has been verified correct across all tested scenarios. The risk is inherent and documented, not a defect.

---

## 5. Known Limitations of Testing Approach

### 1. Synchronous `perform_now` Cannot Simulate True Parallel Race Conditions

`TableMonitorJob.perform_now(@tm.id)` executes the job synchronously in the test thread. All CableReady operations complete before the next line of test code runs. Real production load involves multiple Puma worker threads handling AASM events from concurrent HTTP requests simultaneously — broadcasts from different tables may be enqueued, processed, and delivered to the ActionCable server in any interleaved order. The CONC-01 rapid-fire test demonstrates sequential delivery of N broadcasts, not concurrent thread-level race conditions.

### 2. `sleep 2` Is a Timing Assumption

Negative DOM assertions (proving a broadcast did NOT update the wrong session) use `sleep 2` before asserting absence. This is an explicit decision documented in Phase 18-01-SUMMARY.md: there is no DOM change to poll when a broadcast is correctly rejected — Capybara cannot retry on a non-event. The 2-second window assumes all synchronous `perform_now` calls and async WebSocket delivery complete within 2 seconds. On very slow CI hosts this assumption may not hold, causing a flaky false-negative (the rejection assertion passes but the broadcast had not yet arrived). The `_mixupPreventedCount` counter mitigates this by confirming the broadcast actually reached the JS filter.

### 3. System Tests Use a Single-Threaded Puma Server

System tests start Puma in single-threaded mode (1 worker, 1 thread by default in `test` environment). Concurrent HTTP requests from multiple Capybara sessions are serialized. This means the "three simultaneous sessions" scenario in CONC-02 involves three browsers connected over WebSocket simultaneously, but any triggered HTTP request (e.g., `perform_now` via a controller action) would be serialized. The CONC tests call `perform_now` directly from the test thread, bypassing HTTP — this is both the strength (no Puma serialization) and the limitation (no real concurrent thread dispatching).

### 4. Headless Chrome Browser Count

Tests used Selenium with headless Chrome. The maximum number of simultaneous browser sessions tested was three (CONC-02). Production scoreboards can have many more simultaneous connections per location. Beyond three sessions, the same client-side filter logic applies linearly — but memory pressure and WebSocket concurrency at scale were not tested.

---

## 6. Phase 18 Development Findings

Four bugs were discovered and auto-fixed during Phase 18 implementation. These are documented here as gap findings — they reveal nuances in the broadcast architecture that are not obvious from reading the production code.

### Finding 1: `update_columns` With a Serialized JSON Column Still Invokes the Rails Serializer

**Phase:** 18 Plan 02, Task 1
**Discovered during:** Setting up TM-B test data for the `score:update` dispatch event isolation test

Rails `update_columns` is documented to skip validations and callbacks, but for columns declared with `serialize` or with a custom ActiveRecord type (such as a JSON column), the serializer is still invoked. Calling `update_columns(data: {"key" => "value"}.to_json)` on a column typed as a Hash raised `ActiveRecord::SerializationTypeMismatch` because the serializer rejected a String.

**Resolution:** Used raw SQL to write the JSON string directly to the `data` column:
```ruby
TableMonitor.connection.execute(
  "UPDATE table_monitors SET data = '#{json_string}' WHERE id = #{@tm_b.id}"
)
```

**Implication:** Test code that attempts to set serialized columns via `update_columns` with pre-serialized strings will silently fail or raise. Always use raw SQL or ActiveRecord-typed values when bypassing callbacks on serialized columns.

### Finding 2: `score:update` DOM Event Is Dispatched to ALL Scoreboard Sessions Before the Channel Listener Can Filter It

**Phase:** 18 Plan 02, Task 1
**Discovered during:** Writing the negative assertion for the ISOL-02 test

The `dispatch_event` CableReady operation path (lines 486-504 of `table_monitor_channel.js`) calls `CableReady.perform(data.operations)` immediately for any `score:update` event on a scoreboard page, without pre-filtering by `tableMonitorId`. `CableReady.perform` fires the `score:update` custom DOM event on `document`. The `document.addEventListener('score:update', ...)` listener in lines 10-40 then receives the event for every scoreboard session, regardless of which table it is displaying, and returns early only after checking `currentTableMonitorId !== tableMonitorId`.

This means a raw "event not received" assertion (`window._wrongScoreUpdateReceived` flag) always evaluates to `true` on the wrong session — the event IS received everywhere; only its DOM effects are blocked.

**Resolution:** The ISOL-02 test replicates the filter condition (`currentTableMonitorId !== eventTableMonitorId`) in an injected JS listener and asserts that the filter correctly identified the broadcast as cross-table. Structural `refute_selector` on the TM-B DOM container is the primary DOM-level proof.

**Implication:** The `score:update` path has weaker isolation than the `inner_html` morph path: the DOM event fires globally first, then the listener filters. Any listener added to `document` for `score:update` (e.g., by a third-party library, browser extension, or new Stimulus controller) would receive cross-table events.

### Finding 3: `User.scoreboard` Does Not Exist in the Fixture Database

**Phase:** 18 Plan 02, Task 2
**Discovered during:** Setting up the ISOL-03 `table_scores` page context test

`User.scoreboard` is a class method that looks up the user with email `scoreboard@carambus.de`. This user does not exist in the Minitest fixture database. When the `table_scores` page was visited without signing in, `LocationsController#set_location` attempted `@user&.valid?` with `@user = User.scoreboard` returning `nil`, then called `nil.errors.full_messages`, raising `NoMethodError` and returning a 500 response.

**Resolution:** Added `login_as(users(:one), scope: :user)` before visiting the `table_scores` URL. With a signed-in user, `set_location` takes the authenticated path and skips the `User.scoreboard` lookup.

**Implication:** Any system test that visits location-scoped pages without an authenticated user will hit this error. `User.scoreboard` is a production fixture that cannot exist in the test fixture database by design (it is only created via production seed or admin interface).

### Finding 4: `refute_selector` Does Not Accept a Failure Message String as the Second Argument

**Phase:** 18 Plan 02, Task 1
**Discovered during:** Initial isolation test run

Minitest's `assert` accepts a failure message as the second argument. Capybara's `refute_selector` delegates to `Capybara::Queries::SelectorQuery` and raises `ArgumentError: Unused parameters passed to Capybara::Queries::SelectorQuery` when a String is passed as the second argument.

**Resolution:** Removed the message string from `refute_selector` calls. Moved explanations to inline comments. Pattern: `refute_selector "#some_id" # comment explaining the assertion`.

---

## 7. Deferred Fixes

The following fixes are out of scope for v3.0 (verification only) and tracked in `.planning/REQUIREMENTS.md` under "v2 Requirements":

### FIX-01: Server-Side Targeted Broadcasts Scoped Per-Table (Replace Client-Side Filtering)

Instead of broadcasting all AASM state changes to the global `table-monitor-stream` and filtering client-side, the server should target each broadcast to only the clients connected to the affected table. CableReady and ActionCable both support scoped broadcasting — `stream_from "table-monitor-stream-#{table_monitor_id}"` would deliver each broadcast only to clients subscribed to that specific table.

This change would eliminate the foundational architectural risk documented in Section 4. The client-side `shouldAcceptOperation` function would become a defense-in-depth layer rather than the primary isolation mechanism.

### FIX-02: Refactor `TableMonitorChannel` to Use Per-Table Stream Names Instead of Global Stream

The channel subscription must be updated to subscribe each client to a per-table stream based on the `tableMonitorId` passed during channel setup (e.g., via subscription params or page-context detection). The channel server class would be updated from `stream_from "table-monitor-stream"` to `stream_from "table-monitor-stream-#{params[:table_monitor_id]}"`.

FIX-01 and FIX-02 are tightly coupled — per-table stream names (FIX-02) are the prerequisite for server-side targeted broadcasting (FIX-01). Both should be implemented together in a single future milestone.

---

## 8. Recommendation

### Implement FIX-01 and FIX-02 Together

Per-table stream names (FIX-02) enable server-side broadcast targeting (FIX-01). The two changes are coupled and should be planned as a single milestone. Doing only FIX-02 without FIX-01 would create per-table streams but still broadcast globally (no benefit). Doing only FIX-01 without FIX-02 is impossible — targeted broadcasting requires the stream name to be table-scoped.

### Retain Client-Side Filter Code as Defense-in-Depth

After FIX-01/FIX-02 are implemented, the `shouldAcceptOperation` function and `score:update` listener filter should be retained. If a broadcast is ever sent to the wrong stream due to a server-side bug, the client-side filter provides a second layer of protection. The `console.warn("SCOREBOARD MIX-UP PREVENTED")` logging also provides runtime observability for diagnosing unexpected cross-table events.

### Consider Load Testing After Server-Side Fix

The v3.0 tests use synchronous `perform_now` which cannot simulate true parallel race conditions (see Section 5). After FIX-01/FIX-02 are implemented, the concurrent scenarios should be retested with real Sidekiq background job processing and multiple Puma threads to validate isolation under production-like threading conditions.

### Address `score:update` Dispatch Event Architecture (Longer Term)

The `score:update` DOM event is dispatched to all scoreboard sessions before per-session filtering can occur (Finding 2 in Section 6). Even after FIX-01/FIX-02, if `dispatch_event` operations are still broadcast globally, the same pattern applies. Consider whether `score:update` should be broadcast on a per-table stream alongside the morph path operations, rather than as a global `dispatch_event`.

---

*Document covers Phases 17, 18, and 19 of the Carambus API v3.0 milestone.*
*All test files referenced are in `test/system/table_monitor_isolation_test.rb` and `test/system/table_monitor_broadcast_smoke_test.rb`.*
*FIX-01 and FIX-02 definitions are authoritative in `.planning/REQUIREMENTS.md` v2 Requirements section.*
