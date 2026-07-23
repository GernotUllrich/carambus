# Phase 18: Core Isolation Tests - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Two-session Capybara/Selenium system tests verifying both broadcast delivery paths (morph and score:update dispatch) are isolated per-table. Each test opens two browser sessions on different table scoreboards, triggers a state change on one table, and verifies the other table's scoreboard is unaffected. JS filter execution confirmed via console.warn capture. The `table_scores` overview page is also tested for per-table correctness.

</domain>

<decisions>
## Implementation Decisions

### Test Scope
- **D-01:** Four requirements (ISOL-01 through ISOL-04) need coverage. ISOL-01 covers the morph path (full scoreboard `#full_screen_table_monitor_{id}` updates via CableReady `inner_html`). ISOL-02 covers the `score:update` dispatch event path (JSON payload with `tableMonitorId` filtering). ISOL-03 covers the `table_scores` overview page context. ISOL-04 covers `console.warn("SCOREBOARD MIX-UP PREVENTED")` capture proving the filter actually ran.
- **D-02:** Each test needs two TableMonitor instances on different tables, both with complete fixture chains (TableMonitor → Table → Location → Game). The smoke test from Phase 17 already builds one chain — reuse that pattern.

### Test Infrastructure (from Phase 17)
- **D-03:** Reuse `in_session(name, &block)`, `visit_scoreboard(table_monitor)`, and `wait_for_actioncable_connection` helpers from `ApplicationSystemTestCase`. These are proven by the Phase 17 smoke test.
- **D-04:** Use `TableMonitorJob.perform_now(tm.id)` to trigger broadcasts synchronously (proven in Phase 17 — `:test` queue adapter doesn't auto-execute jobs).
- **D-05:** Use Capybara's built-in wait/retry for positive assertions (`assert_selector`). Carried forward from Phase 17 D-05.

### Four Distinct JS Filter Paths
- **D-06:** `shouldAcceptOperation` in `table_monitor_channel.js` has four page contexts detected by `getPageContext()`:
  1. **Scoreboard** — accepts only `#full_screen_table_monitor_{id}` matching own ID; rejects mismatches with `console.warn`
  2. **table_scores** — accepts `#table_scores` and `#teaser_*`; rejects `#full_screen_*`
  3. **tournament_scores** — accepts `#teaser_*` only
  4. **unknown** — rejects `#full_screen_*`; checks element existence for others
- **D-07:** Phase 18 tests paths 1 (ISOL-01), 1+dispatch_event (ISOL-02), and 2 (ISOL-03). Path 3 (tournament_scores) is lower priority and can be deferred if not in scope.

### Claude's Discretion
- Test file organization (single file vs per-path — Claude picks best structure)
- Paired positive/negative assertion strategy (DOM unchanged check, console.warn + DOM, or combination)
- score:update dispatch event verification approach (DOM side-effect check, console log capture, or combination)
- console.warn capture mechanism for ISOL-04 (Selenium logs API, DOM marker, or other)
- Which AASM transitions to use for triggering different operation types (morph vs score:update)
- Fixture setup sharing strategy across test methods
- Whether to test `tournament_scores` context (path 3) or defer

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### ActionCable Channel & JS Filtering (PRIMARY — this is what we're testing)
- `app/javascript/channels/table_monitor_channel.js` — `shouldAcceptOperation()` (line ~100), `getPageContext()` (line ~60), `console.warn("SCOREBOARD MIX-UP PREVENTED")` on rejection, `score:update` event listener with `tableMonitorId` check
- `app/channels/table_monitor_channel.rb` — Subscription guard, stream name `"table-monitor-stream"`

### Job & Operation Types
- `app/jobs/table_monitor_job.rb` — Operation types: `"teaser"` (line 90), `"table_scores"` (line 117), `"score_data"` / dispatch_event (line 136), `"player_score_panel"` (line 169), default full scoreboard (line 229)

### Phase 17 Infrastructure (reuse)
- `test/application_system_test_case.rb` — `in_session`, `visit_scoreboard`, `wait_for_actioncable_connection` helpers
- `test/system/table_monitor_broadcast_smoke_test.rb` — Pattern for fixture chain setup, `perform_now`, and broadcast assertion

### Scoreboard Views & DOM Structure
- `app/views/table_monitors/_show.html.erb` — Scoreboard partial, `#full_screen_table_monitor_{id}` container
- `app/views/table_monitors/_table_scores.html.erb` — Table scores with `#table_scores` and `turbo-frame#teaser_{id}`

### Research
- `.planning/research/FEATURES.md` — Four filter paths, paired positive/negative test design
- `.planning/research/PITFALLS.md` — Vacuous assertion risk (tests pass with filter deleted), subscription timing race

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `in_session(name, &block)` — wraps `Capybara.using_session`, ready for two-session tests
- `visit_scoreboard(table_monitor, locale: :de)` — visits scoreboard URL with locale
- `wait_for_actioncable_connection(timeout: 5)` — polls for `data-cable-connected="true"` on `<html>` element
- Smoke test fixture chain pattern: TableMonitor → Table (with location_id, table_kind_id) → Game (local ID range)

### Established Patterns
- `TableMonitorJob.perform_now(tm.id)` for synchronous broadcast triggering (bypasses queue adapter)
- `@table_monitor.ready!` for AASM state change that produces visible DOM update
- `assert_selector "#full_screen_table_monitor_#{id}", text: "Frei"` for broadcast arrival assertion
- Teardown: `Game.where("id >= 50_000_000").delete_all` to prevent fixture pollution

### Integration Points
- New isolation tests will live in `test/system/` alongside the smoke test
- Tests use the same `ApplicationSystemTestCase` base class with Phase 17 helpers
- Two-session tests need `in_session(:scoreboard_a)` and `in_session(:scoreboard_b)` blocks visiting different TableMonitor scoreboards
- `score_data` operation type requires triggering a score update (not just AASM transition) — may need `after_update_commit` path or direct job invocation with specific `table_monitor.collected_data_changes`

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. User deferred all implementation choices to Claude's discretion.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 18-core-isolation-tests*
*Context gathered: 2026-04-11*
