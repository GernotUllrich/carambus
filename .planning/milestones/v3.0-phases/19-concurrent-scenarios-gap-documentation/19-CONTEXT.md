# Phase 19: Concurrent Scenarios & Gap Documentation - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Stress-test broadcast isolation under concurrent load: rapid-fire AASM state transitions with multiple simultaneous browser sessions. Verify no broadcast bleed occurs. Create a gap report documenting all findings (failures or clean pass) with deferred fix references.

</domain>

<decisions>
## Implementation Decisions

### Test Scope
- **D-01:** Three requirements: CONC-01 (rapid-fire AASM transitions with 2 sessions), CONC-02 (3+ simultaneous sessions on different tables), DOC-01 (gap report).
- **D-02:** Tests build on Phase 18 isolation test patterns. Reuse the same `table_monitor_isolation_test.rb` file or create a separate concurrent test file — Claude's discretion.

### Infrastructure (from Phases 17-18)
- **D-03:** Reuse all Phase 17 helpers: `in_session`, `visit_scoreboard`, `wait_for_actioncable_connection`, `TableMonitorJob.perform_now`.
- **D-04:** Two TM fixture pairs already exist (`:one` and `:two`). CONC-02 needs a third — Claude decides fixture vs inline creation.

### Gap Report
- **D-05:** `.planning/BROADCAST-GAP-REPORT.md` is the final deliverable. Documents all isolation test results from Phases 18-19, any failures found (with reproduction steps), and references FIX-01/FIX-02 as deferred fixes.

### Claude's Discretion
- Rapid-fire simulation approach (sequential loop, alternating TMs, or other)
- Number of transitions per test (5-10 suggested but flexible)
- Third TM fixture approach (fixture file vs inline creation)
- Test file organization (extend existing file or separate concurrent test file)
- Gap report content and structure (clean report vs include known architectural risks)
- Whether to include timing/latency metrics in gap report

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 18 Tests (foundation to build on)
- `test/system/table_monitor_isolation_test.rb` — Existing isolation tests (morph, score:update, table_scores). Extend or complement with concurrent tests.
- `.planning/phases/18-core-isolation-tests/18-01-SUMMARY.md` — What was built, patterns used
- `.planning/phases/18-core-isolation-tests/18-02-SUMMARY.md` — score:update and table_scores patterns

### Phase 17 Infrastructure
- `test/application_system_test_case.rb` — `in_session`, `visit_scoreboard`, `wait_for_actioncable_connection` helpers
- `test/system/table_monitor_broadcast_smoke_test.rb` — Smoke test fixture chain pattern

### JS Filtering (what we're stress-testing)
- `app/javascript/channels/table_monitor_channel.js` — `shouldAcceptOperation`, `console.warn("SCOREBOARD MIX-UP PREVENTED")`
- `app/jobs/table_monitor_job.rb` — Operation types, broadcast trigger

### Fixtures
- `test/fixtures/table_monitors.yml` — `:one` (50_000_001) and `:two` (50_000_002) exist
- `test/fixtures/tables.yml` — `:one` and `:two` linked to TMs

### Requirements
- `.planning/REQUIREMENTS.md` — CONC-01, CONC-02, DOC-01 definitions; FIX-01/FIX-02 as deferred v2 requirements

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `in_session(name, &block)` — proven for two sessions, should work for three
- `visit_scoreboard(table_monitor, locale: :de)` — per-TM scoreboard visit
- `wait_for_actioncable_connection(timeout: 5)` — WebSocket readiness gate
- `window._mixupPreventedCount` — DOM marker for console.warn capture (from Phase 18)
- Fixture chain pattern: TM → Table → Location → Game

### Established Patterns
- `TableMonitorJob.perform_now(tm.id)` for synchronous broadcast
- `@tm.ready!` for AASM transition producing visible DOM update
- `assert_selector "#full_screen_table_monitor_#{id}", text: "Frei"` for positive assertion
- `refute_selector` + `_mixupPreventedCount` for negative assertion with filter proof

### Integration Points
- Concurrent tests add to or complement `test/system/table_monitor_isolation_test.rb`
- Gap report goes to `.planning/BROADCAST-GAP-REPORT.md` (project-level, not phase-level)
- Gap report references FIX-01/FIX-02 from REQUIREMENTS.md v2 section

</code_context>

<specifics>
## Specific Ideas

- The original problem was observed under heavier load with AASM state transitions — race conditions. The concurrent tests should simulate this scenario as closely as possible within the constraints of synchronous `perform_now`.
- Gap report should be useful for future planning of the server-side broadcast targeting fix (FIX-01/FIX-02).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 19-concurrent-scenarios-gap-documentation*
*Context gathered: 2026-04-11*
