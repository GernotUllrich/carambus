# Phase 19: Concurrent Scenarios & Gap Documentation — Research

**Researched:** 2026-04-11
**Domain:** Capybara/Selenium multi-session concurrency testing + planning documentation
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Three requirements: CONC-01 (rapid-fire AASM transitions with 2 sessions), CONC-02 (3+ simultaneous sessions on different tables), DOC-01 (gap report).
- **D-02:** Tests build on Phase 18 isolation test patterns. Reuse the same `table_monitor_isolation_test.rb` file or create a separate concurrent test file — Claude's discretion.
- **D-03:** Reuse all Phase 17 helpers: `in_session`, `visit_scoreboard`, `wait_for_actioncable_connection`, `TableMonitorJob.perform_now`.
- **D-04:** Two TM fixture pairs already exist (`:one` and `:two`). CONC-02 needs a third — Claude decides fixture vs inline creation.
- **D-05:** `.planning/BROADCAST-GAP-REPORT.md` is the final deliverable. Documents all isolation test results from Phases 18-19, any failures found (with reproduction steps), and references FIX-01/FIX-02 as deferred fixes.

### Claude's Discretion

- Rapid-fire simulation approach (sequential loop, alternating TMs, or other)
- Number of transitions per test (5-10 suggested but flexible)
- Third TM fixture approach (fixture file vs inline creation)
- Test file organization (extend existing file or separate concurrent test file)
- Gap report content and structure (clean report vs include known architectural risks)
- Whether to include timing/latency metrics in gap report

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CONC-01 | Rapid-fire AASM state transitions with multiple simultaneous sessions verifying no broadcast bleed | Sequential loop of `force_ready!` / `update_columns(state:)` + `TableMonitorJob.perform_now` in alternating TM pattern, two sessions open, DOM markers track bleed |
| CONC-02 | Three+ simultaneous browser sessions on different tables under concurrent state changes | Three `in_session` blocks, third TM created inline (no fixture needed), sequential broadcast loop, all three sessions assert correct isolated DOM |
| DOC-01 | Gap report documenting any broadcast isolation failures found during testing (fix deferred) | `.planning/BROADCAST-GAP-REPORT.md` covers Phases 17-19, references FIX-01/FIX-02, documents architectural risk even on clean pass |
</phase_requirements>

---

## Summary

Phase 19 extends the Phase 18 two-session isolation test suite into concurrent/load scenarios and produces a written gap report. The technical domain is already fully established: Capybara multi-session (`Capybara.using_session`), WebSocket synchronization via DOM marker (`html[data-cable-connected="true"]`), synchronous job execution (`TableMonitorJob.perform_now`), and the `window._mixupPreventedCount` DOM counter for verifying JS filter execution.

CONC-01 simulates "rapid-fire AASM transitions" — the condition where the original production bug was observed. Within the constraints of `perform_now` (synchronous, no real parallel threads), rapid-fire is best modeled as a tight loop that alternates broadcasts between two TMs while two sessions are open. After N iterations (5-10), each session asserts its DOM is correct and the `_mixupPreventedCount` counter confirms the filter ran on every cross-table broadcast.

CONC-02 extends to three simultaneous sessions. The third `TableMonitor` record does not need a fixture entry — `find_or_create_by!(id: 50_000_003)` inline follows the established pattern from Phase 18's `@game_a`/`@game_b` setup. Three sessions open in parallel via `in_session`, then each receives a broadcast while the other two check isolation.

The gap report is a project-level planning document, not a test file. It summarizes all Phase 17-19 findings, classifies whether isolation held, and explicitly references FIX-01/FIX-02 as deferred v2 work. Even on a full clean pass, the report must document the architectural risk (server-side global broadcast requiring client-side filtering) so future maintainers understand the known gap.

**Primary recommendation:** Extend `table_monitor_isolation_test.rb` with two new test methods (CONC-01, CONC-02), use inline TM/Game creation for the third session, and write `BROADCAST-GAP-REPORT.md` after verifying both tests pass.

---

## Standard Stack

### Core (already installed — no new gems)
| Library | Version | Purpose | Notes |
|---------|---------|---------|-------|
| capybara | 3.39+ | Multi-session browser control | `Capybara.using_session` proven in Phase 18 |
| selenium-webdriver | 4.20.1+ | Headless Chrome driver | Already configured in `ApplicationSystemTestCase` |
| minitest | built-in | Test framework | Phase 18 patterns apply directly |

No new dependencies required. [VERIFIED: existing Gemfile.lock patterns from Phases 17-18]

---

## Architecture Patterns

### Rapid-Fire Simulation (CONC-01)

The original production bug was race conditions under heavier AASM load. Synchronous `perform_now` cannot produce real threading races, but it can verify that the JS filter handles N consecutive cross-table broadcasts without leaking any into the wrong session.

**Pattern:**

```ruby
# Sessions open on TM-A and TM-B
in_session(:scoreboard_a) { visit_scoreboard(@tm_a); wait_for_actioncable_connection }
in_session(:scoreboard_b) { visit_scoreboard(@tm_b); wait_for_actioncable_connection }

# Install mix-up counter on Session A
in_session(:scoreboard_a) do
  page.execute_script(<<~JS)
    window._mixupPreventedCount = 0;
    const _orig = console.warn;
    console.warn = function(...args) {
      if (args[0] && String(args[0]).includes("SCOREBOARD MIX-UP PREVENTED")) {
        window._mixupPreventedCount++;
      }
      _orig.apply(console, args);
    };
  JS
end

# Rapid-fire: alternate broadcasts between TM-A and TM-B
TRANSITION_COUNT = 5
TRANSITION_COUNT.times do |i|
  if i.even?
    @tm_a.update_columns(state: "ready")
    TableMonitorJob.perform_now(@tm_a.id)
  else
    @tm_b.update_columns(state: "ready")
    TableMonitorJob.perform_now(@tm_b.id)
  end
end
```

**Why `update_columns` not AASM events:** `ready!` only transitions from `new` or `ready_for_new_match`. For repeated rapid-fire transitions, `update_columns(state: "ready")` resets state before each `TableMonitorJob.perform_now` call, allowing N broadcast cycles without AASM whiny transition errors. [VERIFIED: AASM definition in `app/models/table_monitor.rb` lines 386-388]

**Alternative:** Use `force_ready!` which transitions from any state (line 389-391). This is cleaner as it goes through the real AASM machine. However, `force_ready!` saves the record and triggers `after_commit` callbacks which enqueue additional jobs — in the test environment with `:async` adapter these run immediately but don't block. `update_columns` is safer for rapid-fire loop control.

**Assertions after loop:**

```ruby
# Session A: filter must have run for every TM-B broadcast (ceil of N/2 times)
in_session(:scoreboard_a) do
  sleep 2  # absence assertion — no poll target for rejected broadcasts
  count = page.evaluate_script("window._mixupPreventedCount")
  expected_b_broadcasts = TRANSITION_COUNT / 2  # integer division
  assert count.to_i >= expected_b_broadcasts,
    "Expected >= #{expected_b_broadcasts} mix-up preventions (one per TM-B broadcast), got #{count}"
  refute_selector "#full_screen_table_monitor_#{@tm_b.id}"
end

# Session B: positive assertion — last TM-B broadcast updated DOM
in_session(:scoreboard_b) do
  assert_selector "#full_screen_table_monitor_#{@tm_b.id}", text: /Frei/i, wait: 10
end
```

[ASSUMED] The `sleep 2` duration used in Phase 18 is sufficient for rapid-fire scenarios because `perform_now` is synchronous — all broadcasts complete before sleep begins. The 2-second window lets async WebSocket delivery reach the browser. Risk: flaky on very slow CI. Mitigable by increasing sleep if needed.

### Three-Session Pattern (CONC-02)

`Capybara.using_session` accepts any string name — three sessions work exactly like two. [VERIFIED: `in_session` helper in `test/application_system_test_case.rb` is a thin wrapper around `Capybara.using_session`]

**Third TM — inline creation over fixture:** The Phase 18 pattern creates Game records inline via `find_or_create_by!(id: 50_000_100/101)`. The same approach works for a third TM:

```ruby
# In setup (after @tm_a and @tm_b setup)
@tm_c = TableMonitor.find_or_create_by!(id: 50_000_003) do |tm|
  tm.state = "new"
  tm.data = {}
  tm.ip_address = "192.168.1.3"
  tm.panel_state = "pointer_mode"
  tm.current_element = "pointer_mode"
end
# Requires a Table linked to @tm_c for visit_scoreboard to resolve table_monitor_url
@table_c = Table.find_or_create_by!(id: 50_000_003) do |t|
  t.name = "Table Three"
  t.table_monitor_id = 50_000_003
  t.location_id = @tm_a.table.location.id  # reuse same location
  t.table_kind_id = 50_000_001
end
@game_c = Game.find_or_create_by!(id: 50_000_102)
@tm_c.update_columns(game_id: @game_c.id, state: "new")
```

**Alternative: Add `:three` fixture.** Simpler teardown (fixtures auto-reset), but adds schema coupling. Inline is preferred for self-contained phase scope. [ASSUMED: Inline creation follows same pattern as Phase 18 Game creation; same teardown requirements apply]

**Three-session broadcast pattern:**

```ruby
[:scoreboard_a, :scoreboard_b, :scoreboard_c].zip([@tm_a, @tm_b, @tm_c]).each do |session, tm|
  in_session(session) do
    visit_scoreboard(tm)
    wait_for_actioncable_connection
  end
end

# Fire TM-A state change → only Session A should update
@tm_a.update_columns(state: "ready")
TableMonitorJob.perform_now(@tm_a.id)

# Positive: Session A sees update
in_session(:scoreboard_a) do
  assert_selector "#full_screen_table_monitor_#{@tm_a.id}", text: /Frei/i, wait: 10
end

# Negative: Sessions B and C see no TM-A content
[:scoreboard_b, :scoreboard_c].each do |session|
  in_session(session) do
    sleep 2
    refute_selector "#full_screen_table_monitor_#{@tm_a.id}"
  end
end
```

Repeat for TM-B and TM-C broadcasts to prove all three directions are isolated. [VERIFIED: `refute_selector` pattern confirmed working from Phase 18-02-SUMMARY.md]

### Gap Report Structure

The gap report is a Markdown planning document at `.planning/BROADCAST-GAP-REPORT.md`. It is not a test file. Content should cover:

1. **Scope** — Which requirements were verified (INFRA-01 through DOC-01)
2. **Results table** — Per-requirement pass/fail
3. **Architectural risk statement** — The known gap (global `table-monitor-stream`, client-side filtering) even if all tests pass
4. **Known limitations** — `perform_now` cannot simulate true parallel race conditions
5. **Deferred fixes** — FIX-01/FIX-02 verbatim from REQUIREMENTS.md
6. **Phase 18 findings** — Failures discovered during development (score:update event dispatched to all sessions before filter runs; User.scoreboard nil in test DB; etc.)

[VERIFIED: FIX-01/FIX-02 definitions from `.planning/REQUIREMENTS.md` lines 38-41]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| WebSocket synchronization | `sleep N` before every broadcast | `wait_for_actioncable_connection` (DOM marker, Capybara retry) |
| Three-session management | Custom session pool | Three `in_session` calls (Phase 18 pattern scales directly) |
| Console.warn capture | Selenium logs API | `window._mixupPreventedCount` DOM counter (Phase 18 Pitfall 5) |

---

## Common Pitfalls

### Pitfall 1: AASM whiny transitions in rapid-fire loop
**What goes wrong:** `@tm.ready!` raises `AASM::InvalidTransition` after the first call because `ready` only transitions from `new` or `ready_for_new_match`, not from `ready`. Subsequent loop iterations fail.
**Why it happens:** AASM `whiny_transitions: true` (line 333 of `table_monitor.rb`). After the first `ready!`, state is `"ready"` — the event no longer applies.
**How to avoid:** Use `update_columns(state: "new")` before each `ready!` call, or use `force_ready!` (transitions from any state), or use `update_columns(state: "ready")` directly and call `TableMonitorJob.perform_now` without an AASM event.
**Warning signs:** `AASM::InvalidTransition` in test output on second loop iteration.

### Pitfall 2: Third TM missing Table FK breaks scoreboard rendering
**What goes wrong:** `visit_scoreboard(@tm_c)` generates `table_monitor_url(@tm_c)` which resolves to the scoreboard show action. That action calls `@tm.table.location` — if no `Table` record links to TM `:three`, `nil.location` raises `NoMethodError`.
**Why it happens:** `table_monitor_url` routes to `table_monitor#show` which requires a full `TableMonitor → Table → Location` chain. [VERIFIED: Phase 17-02-SUMMARY.md "fixture chain pattern"]
**How to avoid:** Always create a corresponding `Table` record (with `table_monitor_id`, `location_id`, `table_kind_id`) when creating an inline TM.
**Warning signs:** 500 error on scoreboard visit; `NoMethodError: undefined method 'location' for nil`.

### Pitfall 3: Shared setup/teardown pollution between test methods
**What goes wrong:** If the CONC-01 test mutates `@tm_a` state (e.g., leaves it in `"ready"` instead of `"new"`) and teardown does not reset it, the CONC-02 test starts with unexpected state and AASM transitions may fail.
**Why it happens:** System tests don't use transactional fixtures — DB changes persist across tests in a file unless explicitly rolled back.
**How to avoid:** `teardown` block calls `update_columns(state: "new", data: {}, game_id: nil)` on all TMs and destroys inline-created records. Match the Phase 18 teardown pattern exactly.
**Warning signs:** Second test method fails with AASM error or wrong DOM state.

### Pitfall 4: `refute_selector` requires presence window — sleep necessary
**What goes wrong:** `refute_selector "#full_screen_table_monitor_#{@tm_b.id}"` passes immediately if the element was never on the page, even before the broadcast arrives — making the negative assertion vacuous.
**Why it happens:** The JS filter rejection is a non-event from Capybara's perspective. There is no DOM change to poll.
**How to avoid:** The `_mixupPreventedCount` counter confirms the broadcast actually arrived at Session A's JS filter. Only then is `refute_selector` meaningful. Use `sleep 2` (established pattern, documented in Phase 18) followed by counter check before `refute_selector`. [VERIFIED: Phase 18-01-SUMMARY.md "sleep 2 accepted for negative assertion"]

### Pitfall 5: `find_or_create_by!` for third TM requires all non-null columns
**What goes wrong:** `TableMonitor.find_or_create_by!(id: 50_000_003)` raises `ActiveRecord::NotNullViolation` if `panel_state` or `current_element` columns have NOT NULL constraints and are not set in the block.
**Why it happens:** Schema shows both columns have `default("pointer_mode"), not null` — but `find_or_create_by!` with a block only sets attributes on create, not if found. Defaults apply at DB level for new records.
**How to avoid:** Provide explicit values in the block (`tm.panel_state = "pointer_mode"`), or rely on DB defaults if using raw `create!`. Safest: follow Phase 18 pattern for `@game_a = Game.find_or_create_by!(id: 50_000_100)` — no attributes needed if DB defaults cover non-null columns.
**Warning signs:** `ActiveRecord::NotNullViolation` on TM or Table create.

### Pitfall 6: Stale precompiled assets silently serve old JS
**What goes wrong:** New test expects JS behavior (e.g., a new DOM marker) that doesn't execute because `public/assets/application-XXX.js` is stale.
**Why it happens:** Documented in Phase 17-02-SUMMARY.md: Sprockets serves `public/assets/` if present; fresh esbuild in `app/assets/builds/` is ignored.
**How to avoid:** Phase 19 adds no new JS code — this pitfall only applies if JS is changed. Documented here for completeness; the plan should include a note to run `yarn build` before system tests if any JS changes are made.
**Warning signs:** Browser behavior doesn't match expectation despite correct code.

---

## Code Examples

### CONC-01 Loop Pattern (verified via Phase 18 patterns)
```ruby
# Source: Established in Phase 18 — ISOL-01 test method pattern
RAPID_FIRE_COUNT = 6  # even number so both TMs fire equally

in_session(:scoreboard_a) do
  visit_scoreboard(@tm_a, locale: :de)
  assert_selector "#full_screen_table_monitor_#{@tm_a.id}"
  wait_for_actioncable_connection
  page.execute_script(<<~JS)
    window._mixupPreventedCount = 0;
    const _orig = console.warn;
    console.warn = function(...args) {
      if (args[0] && String(args[0]).includes("SCOREBOARD MIX-UP PREVENTED")) {
        window._mixupPreventedCount++;
      }
      _orig.apply(console, args);
    };
  JS
end

in_session(:scoreboard_b) do
  visit_scoreboard(@tm_b, locale: :de)
  assert_selector "#full_screen_table_monitor_#{@tm_b.id}"
  wait_for_actioncable_connection
end

RAPID_FIRE_COUNT.times do |i|
  if i.even?
    @tm_a.update_columns(state: "ready")
    TableMonitorJob.perform_now(@tm_a.id)
  else
    @tm_b.update_columns(state: "ready")
    TableMonitorJob.perform_now(@tm_b.id)
  end
end

in_session(:scoreboard_b) do
  assert_selector "#full_screen_table_monitor_#{@tm_b.id}", text: /Frei/i, wait: 10
end

in_session(:scoreboard_a) do
  sleep 2
  count = page.evaluate_script("window._mixupPreventedCount")
  expected = RAPID_FIRE_COUNT / 2  # TM-B broadcasts Session A should have filtered
  assert count.to_i >= expected,
    "Expected >= #{expected} filter events, got #{count}. Rapid-fire isolation failed."
  refute_selector "#full_screen_table_monitor_#{@tm_b.id}"
end
```

### CONC-02 Inline Third TM Setup
```ruby
# Source: Phase 18 inline Game creation pattern adapted for TableMonitor
def setup_third_tm
  @tm_c = TableMonitor.find_or_create_by!(id: 50_000_003)
  @tm_c.update_columns(state: "new", data: {}, panel_state: "pointer_mode", current_element: "pointer_mode")
  @table_c = Table.find_or_create_by!(id: 50_000_003) do |t|
    t.name = "Table Three"
    t.table_monitor_id = 50_000_003
    t.location_id = @tm_a.table.location.id
    t.table_kind_id = 50_000_001
  end
  @game_c = Game.find_or_create_by!(id: 50_000_102)
  @tm_c.update_columns(game_id: @game_c.id)
end

def teardown_third_tm
  @tm_c.update_columns(game_id: nil, state: "new", data: {})
  @table_c&.destroy
  @game_c&.destroy
end
```

### Gap Report Skeleton

```markdown
# Broadcast Isolation Gap Report

**Generated:** [date]
**Milestone:** v3.0 — Broadcast Isolation Testing

## Executive Summary

[one paragraph: did isolation hold? architectural risk statement]

## Test Results

| Requirement | Test | Result | Notes |
|-------------|------|--------|-------|
| INFRA-01 | Phase 17 | PASS | async cable adapter |
| ...

## Known Architectural Gap

Server broadcasts to global `table-monitor-stream`. All connected clients receive
every broadcast. Isolation is enforced entirely client-side in `shouldAcceptOperation`
and the `score:update` DOM event listener. This architecture is correct for the
current use case but carries inherent risk: a JS bug or unhandled selector pattern
could cause broadcast bleed.

## Deferred Fixes

- **FIX-01** — Server-side targeted broadcasts scoped per-table (replace client-side filtering)
- **FIX-02** — Refactor `TableMonitorChannel` to use per-table stream names

## Phase 18 Findings During Development

[document bugs found: score:update event dispatches to all sessions before filter,
User.scoreboard nil in test DB, refute_selector message arg error]
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `sleep N` for WebSocket sync | DOM marker in `connected()` + `assert_selector` | Phase 17 | No flaky sleep, Capybara polls |
| Selenium logs API for console.warn | `window._mixupPreventedCount` DOM counter | Phase 18 | Works across ChromeDriver versions |
| Two sessions for isolation | Three sessions for concurrent load | Phase 19 | Validates 3+ browser scenario |

---

## Recommendations (Claude's Discretion Decisions)

### File organization
**Recommendation: Extend `table_monitor_isolation_test.rb`** rather than creating a separate file. The new test methods share the same setup block, TM fixtures, and helper pattern. A separate file would duplicate setup/teardown and split closely related tests. The existing file will grow to approximately 400-450 lines — acceptable for a focused isolation test suite.

### Rapid-fire count
**Recommendation: 6 transitions** (3 per TM). This proves the loop works with multiple iterations while keeping test runtime under 30 seconds. With `perform_now` the synchronous broadcast overhead is ~100-200ms per call; 6 calls + sleep = ~5-7 seconds total.

### Third TM approach
**Recommendation: Inline creation** (not a new fixture). Rationale: fixtures add schema coupling to the fixture file and require the planner to coordinate with a non-test file. Inline follows the established Phase 18 `@game_a`/`@game_b` pattern and keeps all state local to the test.

### Gap report content
**Recommendation: Include architectural risk even on clean pass.** The gap report's value is documenting that the architecture has a structural risk (client-side filtering on a global stream) regardless of whether current tests pass. Also document the bugs/deviations found during Phase 18 — these are legitimate gap findings.

### Timing/latency metrics
**Recommendation: Do not include.** REQUIREMENTS.md explicitly scopes this milestone to correctness, not performance. Adding latency metrics would require additional JS instrumentation and is explicitly out of scope per the REQUIREMENTS.md "Out of Scope" table.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `sleep 2` is sufficient for rapid-fire broadcast delivery in CI | Architecture Patterns — CONC-01 | Flaky tests; fix: increase sleep or add polling |
| A2 | Inline third TM creation follows Phase 18 Game pattern without unexpected FK constraints | Architecture Patterns — CONC-02 | `ActiveRecord::InvalidForeignKey` on create; fix: add fixture or resolve FK |
| A3 | `TableMonitor.find_or_create_by!(id: 50_000_003)` will not conflict with existing data in test DB | Code Examples | Data pollution if previous test run leaked; fix: teardown must destroy |

---

## Open Questions (RESOLVED)

1. **Does `visit_scoreboard` work without a `Table` record for the TM?** — RESOLVED
   - Resolution: Plan 19-01 Task 2 creates `@table_c` via `Table.find_or_create_by!` with explicit `location_id` and `table_kind_id`. The full FK chain is satisfied.

2. **Do Phase 18 tests currently pass on the main branch without local changes?** — RESOLVED
   - Resolution: Phase 18 verification confirmed 751 runs, 0 failures. The executor should run existing isolation tests as a baseline check before adding CONC test methods.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 19 is test-code-only changes. No new external tool dependencies. All dependencies (Chrome, Selenium, Capybara) already verified working in Phases 17-18.

---

## Validation Architecture

Step 4: SKIPPED — `workflow.nyquist_validation` is explicitly `false` in `.planning/config.json`.

---

## Security Domain

Step: SKIPPED — Test-only phase. No production code changes, no new endpoints, no auth paths, no schema changes. `security_enforcement` not applicable.

---

## Sources

### Primary (HIGH confidence)
- `test/system/table_monitor_isolation_test.rb` — existing test patterns, DOM marker usage, sleep-based negative assertions
- `test/application_system_test_case.rb` — `in_session`, `visit_scoreboard`, `wait_for_actioncable_connection` implementations
- `app/models/table_monitor.rb` lines 333-391 — AASM state/event definitions (whiny_transitions, `force_ready`, `ready` event constraints)
- `app/jobs/table_monitor_job.rb` — synchronous job execution path
- `.planning/phases/18-core-isolation-tests/18-01-SUMMARY.md` — Phase 18 patterns, decisions, auto-fixed bugs
- `.planning/phases/18-core-isolation-tests/18-02-SUMMARY.md` — Phase 18 deviations, score:update behavior
- `.planning/phases/17-infrastructure-configuration/17-02-SUMMARY.md` — fixture chain requirements, DOM marker pattern
- `.planning/REQUIREMENTS.md` — FIX-01/FIX-02 definitions, out-of-scope table

### Secondary (MEDIUM confidence)
- `.planning/config.json` — confirms `nyquist_validation: false`
- `test/fixtures/table_monitors.yml`, `tables.yml` — confirmed `:one` and `:two` exist, no `:three`

---

## Metadata

**Confidence breakdown:**
- CONC-01 rapid-fire pattern: HIGH — directly extends proven Phase 18 two-session pattern
- CONC-02 three-session pattern: HIGH — `Capybara.using_session` scales linearly; inline creation follows established pattern
- DOC-01 gap report: HIGH — content is a planning document, not technical implementation
- Inline third TM FK chain: MEDIUM — not directly tested in research session; based on analogy to Phase 18 Game creation

**Research date:** 2026-04-11
**Valid until:** 2026-05-11 (stable domain — no external dependencies)
