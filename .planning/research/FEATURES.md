# Feature Research

**Domain:** ActionCable broadcast isolation testing (v3.0 milestone)
**Researched:** 2026-04-11
**Confidence:** HIGH — direct codebase analysis, no external sources needed

---

## What This Document Maps

This is a **test work-item map**, not a product feature map. "Table stakes" means test scenarios that must exist for the milestone to succeed. "Differentiators" means test scenarios that make the suite meaningfully stronger. "Anti-features" means tempting test shapes that should be explicitly rejected.

---

## Isolation Architecture Context

Understanding the existing system is essential before mapping test scenarios. Two facts drive every test decision:

**Fact 1 — The channel is global, not per-table.** `TableMonitorChannel` streams from a single broadcast key `"table-monitor-stream"`. Every connected client receives every broadcast regardless of which table they are watching. There is no server-side routing by table ID.

**Fact 2 — All isolation is client-side JavaScript.** `table_monitor_channel.js` calls `shouldAcceptOperation(operation, pageContext)` to filter incoming CableReady operations before passing them to `CableReady.perform`. The filter reads the current page's `tableMonitorId` from the DOM (`[data-table-monitor-root="scoreboard"]` data attribute, then a `<meta>` tag fallback, then a DOM ID fallback). Operations targeting the wrong `#full_screen_table_monitor_N` selector are silently dropped.

**Consequence for tests:** Isolation can only be verified in a real browser session. `ActionCable::Channel::TestCase` unit tests verify subscription mechanics but cannot test whether the JavaScript filter correctly drops operations for the wrong table. System tests with two browser sessions are the only way to verify the isolation property end-to-end.

---

## Feature Landscape

### Table Stakes (Must Have for Milestone)

These tests are the direct deliverables of v3.0. Without them the milestone is not complete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Capybara multi-session infrastructure | Two simultaneous browser sessions cannot be tested without `Capybara.using_session` — Rails' single-session system test default is not enough | MEDIUM | Capybara supports multi-session via `using_session(:name) { ... }` blocks. Selenium headless already in Gemfile. The `ApplicationSystemTestCase` needs a helper that opens a second session and yields both. |
| Two scoreboards, independent state: scoreboard A update does not appear on scoreboard B | Core isolation invariant — if a broadcast for table 1 mutates DOM in a browser watching table 2, the feature is broken | HIGH | Requires two concurrent browser sessions on different scoreboard URLs, a server-side AASM transition on table 1, then asserting the DOM of session B did not change. The `#full_screen_table_monitor_N` selector differentiates them. |
| AASM state transition broadcasts reach the correct scoreboard | Positive case: a broadcast for table N must appear on the scoreboard watching table N | MEDIUM | Paired with the negative case above. If only the negative case exists, a bug that drops all broadcasts would pass. Both directions must be tested. |
| `score:update` dispatch event filtered by `tableMonitorId` | The ultra-fast score path uses `dispatch_event` rather than `morph` — the event listener filters by `currentTableMonitorId`. This path is separate from the morph filter and must be verified independently | HIGH | The `score:update` DOM event handler in `table_monitor_channel.js` reads `scoreboardRoot?.dataset?.tableMonitorId` and compares to `event.detail.tableMonitorId`. This will not be caught by the morph filter tests. |
| Page context detection on scoreboard pages (`type: 'scoreboard'`) | `getPageContext()` has three detection strategies (data-attribute, meta-tag, dom-id). If detection returns `type: 'unknown'` on a valid scoreboard page, all `full_screen_table_monitor_N` updates are silently dropped | MEDIUM | Test that both detection strategies produce the correct `tableMonitorId` — verify the scoreboard actually renders after a broadcast, not just that no wrong-table update appears. |
| table_scores overview page: does NOT render full-screen scoreboard updates | `table_scores` page context rejects all `#full_screen_table_monitor_N` operations. This is a separate filter path that must be independently tested | MEDIUM | Visit the `table_scores` URL (not a scoreboard URL), trigger a TableMonitor state change, assert the overview teasers updated but no full-screen scoreboard HTML appeared in the DOM. |

### Differentiators (Make the Suite Meaningfully Stronger)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Three concurrent sessions (two scoreboards + one table_scores overview) | Exercises all three `getPageContext()` branches simultaneously in one test run; catches cross-contamination that only manifests under concurrent load | HIGH | Three `Capybara.using_session` blocks in one test. The table_scores session must receive teaser updates; neither scoreboard session should see the other's full-screen update. |
| Rapid-fire AASM transitions (ready → warmup → playing sequence) | Tests that intermediate state transitions do not produce stale operations that arrive out of order or bleed across sessions | HIGH | Fire `start_new_match` then `finish_shootout` in quick succession while two browser sessions are open. Each session must see only its own state progression. |
| Context detection fallback path (meta-tag, then dom-id) | The primary detection path (`[data-table-monitor-root="scoreboard"]` data attribute) may not be present during a Turbo page transition. The meta-tag and dom-id fallback paths are untested | MEDIUM | Simulate scoreboard page without the data attribute; verify meta-tag fallback still produces the correct filter. Alternatively assert that missing the data attribute triggers the `SCOREBOARD CONTEXT DETECTION FAILED` console error log as a warning signal. |
| Connection health monitor does not trigger false reconnects under test | `ConnectionHealthMonitor` polls every 5 minutes and reloads on message timeout. Under test, artificial timing could trigger a reload and invalidate the test | LOW | Set `localStorage.setItem('cable_no_logging', 'true')` in test setup; ensure health monitor interval does not fire during test (5-minute interval is long enough for short tests). Document this as a fragility. |
| Heartbeat round-trip does not disrupt isolation filter | `heartbeat_ack` messages arrive on the same channel. The `received` handler short-circuits on `data.type === "heartbeat_ack"` before filtering. Verify that a heartbeat during a test does not reset `lastReceived` state in a way that masks a broadcast | LOW | Send a heartbeat, then immediately trigger a state-change broadcast, assert the state-change was filtered correctly. |

### Anti-Features (Explicitly Out of Scope)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Unit testing `shouldAcceptOperation` in isolation (Jest/QUnit) | The filter function is pure JavaScript, could be extracted and unit-tested without a browser | Adds a second test framework to a Ruby-native project; the function behavior is already covered by the system tests; JavaScript unit tests need their own build setup and fixture HTML | System tests cover the function behavior end-to-end; if logic becomes complex enough, extract to a dedicated JS module with existing esbuild pipeline |
| Testing that isolation failures are corrected | If a broadcast bleed is found, fixing it is tempting | PROJECT.md explicitly states "gap documentation for any isolation failures found (fix deferred)"; a fix belongs in a future milestone | Document failures as gap entries in `.planning/` when found |
| Load testing with hundreds of concurrent sessions | Simulating production-scale load | Three concurrent browser sessions already stress-tests the concurrent path; beyond that is a performance test concern, not an isolation correctness concern | Three sessions is the practical ceiling for in-process Capybara tests |
| Testing `TournamentChannel` or `TournamentMonitorChannel` broadcast isolation | Both are separate channels with different stream patterns; `TournamentChannel` uses per-tournament streams (`tournament-stream-#{id}`) so server-side isolation already exists | v3.0 scope is `TableMonitorChannel` only; `TournamentChannel` uses a different isolation model that is already correct by construction | Document for future milestone if needed |
| Testing CableReady `morph` vs `inner_html` operation differences | There are subtle DOM update differences between operation types | The isolation filter works at the operation level, not the operation type level; the `shouldAcceptOperation` function does not branch on operation type for the core isolation logic | Not relevant for isolation verification |
| ActionCable unit tests for subscription mechanics | `ActionCable::Channel::TestCase` subscription tests already exist for `TournamentMonitorChannel` | The existing channel unit tests cover rejection on API server and stream name assignment; no new unit tests are needed | These are already in `test/channels/` and are complete for v3.0 purposes |
| Verifying Redis pub/sub message delivery | Testing Redis message routing | Redis reliability is infrastructure; correctness of the consumer filter is the milestone's concern | Assume Redis works; test the JavaScript filter |

---

## Feature Dependencies

```
Capybara multi-session infrastructure
    └── required for ──> Two-scoreboard isolation test (negative)
    └── required for ──> Two-scoreboard correct delivery test (positive)
    └── required for ──> score:update dispatch event filter test
    └── required for ──> Three-concurrent-session test

Two-scoreboard isolation test (negative)
    └── paired with ──> Two-scoreboard correct delivery test (positive)
    (both must exist — negative alone allows a "drop all broadcasts" bug to pass)

score:update dispatch event test
    └── independent from ──> morph operation tests
    (different code path in received() handler — must be separately verified)

table_scores page context test
    └── independent from ──> scoreboard page tests
    (different branch in shouldAcceptOperation — getPageContext() returns 'table_scores' not 'scoreboard')

Three-concurrent-session test
    └── enhances ──> Two-scoreboard isolation test
    └── requires ──> Capybara multi-session infrastructure
```

### Dependency Notes

- **Multi-session infrastructure must be built first.** All meaningful tests for this milestone depend on it. Write a reusable `using_two_scoreboards` or `with_sessions` helper in `test/support/system/` to avoid repeating `Capybara.using_session` boilerplate in every test.
- **Positive and negative tests must be paired.** Every negative isolation test ("scoreboard B does not show table A's update") needs a corresponding positive test ("scoreboard A does show table A's update"). Without the positive test, a bug that drops all broadcasts passes all isolation tests with false confidence.
- **`score:update` is a distinct code path.** The morph/inner_html filter path and the `dispatch_event` path are handled separately in `received()`. The `score:update` event listener (`document.addEventListener('score:update', ...)`) does its own DOM-based filtering. These two paths must be verified by separate test cases.

---

## MVP Definition

### Phase 1: Infrastructure (blocks all other tests)

- [ ] Multi-session helper in `test/support/system/` — wraps `Capybara.using_session` for two or three browser sessions; sets up scoreboard URLs with correct `tableMonitorId` in DOM
- [ ] Fixtures for two distinct `TableMonitor` records in usable `ready` state — existing fixtures may be sufficient; verify before creating new ones
- [ ] Confirm `ApplicationRecord.local_server?` returns `true` in system test context so `TableMonitorChannel` accepts subscriptions (it rejects on API server)

### Phase 2: Core Isolation Tests (the milestone's main deliverables)

- [ ] Negative isolation: scoreboard watching table A does not render broadcast from table B state change
- [ ] Positive delivery: scoreboard watching table A does render broadcast from table A state change
- [ ] table_scores overview: teasers update on state change, no full-screen scoreboard DOM appears
- [ ] `score:update` dispatch event: reaches the correct scoreboard, does not fire on a second scoreboard

### Phase 3: Concurrent Load Scenarios

- [ ] Three concurrent sessions (two scoreboards + one table_scores) with simultaneous state transitions on both tables
- [ ] Rapid-fire AASM transitions on one table while two sessions are open — verify no stale operations arrive on wrong session

### Future Consideration (if isolation failures found)

- [ ] Gap documentation entries for any detected bleed — do not fix in v3.0; record selector, operation type, page context, and AASM event that produced the failure

---

## Feature Prioritization Matrix

| Work Item | Correctness Value | Implementation Cost | Priority |
|-----------|-------------------|---------------------|----------|
| Multi-session Capybara infrastructure | HIGH — blocks everything | MEDIUM | P1 |
| Negative isolation test (table A update not on table B scoreboard) | HIGH — core invariant | HIGH | P1 |
| Positive delivery test (table A update on table A scoreboard) | HIGH — must pair with negative | HIGH | P1 |
| `score:update` dispatch event path test | HIGH — separate code path, separate test required | HIGH | P1 |
| table_scores page context test | MEDIUM — separate filter branch | MEDIUM | P2 |
| Three-concurrent-session test | MEDIUM — stress tests concurrent filtering | HIGH | P2 |
| Rapid-fire AASM transition test | MEDIUM — race-condition exposure | HIGH | P2 |
| Context detection fallback path test | LOW — secondary detection strategy | MEDIUM | P3 |
| Heartbeat round-trip non-interference test | LOW — defensive | LOW | P3 |

**Priority key:**
- P1: Required for milestone completion
- P2: Significantly strengthens isolation confidence; include if test run time allows
- P3: Defensive edge cases; include only if P1/P2 are green and time permits

---

## Key Constraints From Existing Infrastructure

**`local_server?` check in `TableMonitorChannel#subscribed`:** The channel calls `reject` unless `ApplicationRecord.local_server?` returns true. In system tests the application runs as a real server process. `local_server?` returns true when `Carambus.config.carambus_api_url` is set, which is the local-server identity marker. The system test environment configuration must have this set, or subscriptions will be rejected. Verify `config/carambus.yml` test defaults before writing any test.

**`suppress_broadcast` flag:** `TableMonitor#after_update_commit` skips all `TableMonitorJob` enqueues when `suppress_broadcast` is true. System tests must not accidentally set this flag, or no broadcasts will fire and all tests will produce false positives.

**`WebMock.disable_net_connect!` with `allow_localhost: true`:** `test_helper.rb` allows localhost connections, which is required for Selenium WebDriver to communicate with the Rails server and for ActionCable's WebSocket to connect. This is already correctly configured.

**No parallelization:** Tests run serially (`parallelize` is commented out in `test_helper.rb`). This simplifies multi-session tests — no risk of cross-process fixture collision — but means test suite runtime will increase with each system test added.

---

## Sources

- Direct analysis of `app/javascript/channels/table_monitor_channel.js` (666 lines)
- Direct analysis of `app/channels/table_monitor_channel.rb`
- Direct analysis of `app/models/table_monitor.rb` (AASM states and after_update_commit broadcast logic)
- Direct analysis of `test/application_system_test_case.rb` and `test/test_helper.rb`
- Direct analysis of existing system tests in `test/system/`
- Direct analysis of existing channel tests in `test/channels/`
- `.planning/PROJECT.md` for milestone scope and constraints

---

*Feature research for: ActionCable broadcast isolation testing (v3.0)*
*Researched: 2026-04-11*
