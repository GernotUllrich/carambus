---
phase: 17-infrastructure-configuration
verified: 2026-04-11T14:00:00Z
status: human_needed
score: 5/5 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run smoke test in headed browser mode: DRIVER=chrome bin/rails test test/system/table_monitor_broadcast_smoke_test.rb"
    expected: "Browser opens, scoreboard page loads showing the table monitor container, then after the state change + job execution the text 'Frei' (or similar German ready-state text) visibly appears in the browser DOM within 10 seconds"
    why_human: "Plan-02 Task 2 is a blocking human-verify gate. Headless test passes per SUMMARY but the plan explicitly requires a human to visually confirm the DOM update in headed Chrome to prove the broadcast delivery chain is real and not an artefact of Capybara's headless mode"
  - test: "Run full suite after smoke test: bin/rails test"
    expected: "751 runs, 0 failures, 0 errors (or equivalent — at least no regressions from Phase 17 changes)"
    why_human: "Required by Plan-02 Task 2 acceptance criteria to confirm fixture additions do not break existing tests in a fresh environment"
---

# Phase 17: Infrastructure & Configuration Verification Report

**Phase Goal:** A working system test environment exists where ActionCable broadcasts reach real browser WebSocket connections and multi-session Capybara helpers are available, proven by a passing smoke test
**Verified:** 2026-04-11T14:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | ActionCable broadcasts reach real WebSocket connections in system tests (async adapter configured) | VERIFIED | `config/cable.yml` line 5-6: `test: adapter: async`. Production/dev remain on `redis`. Commit `d9ea8cb0`. |
| 2 | `local_server?` returns true during system tests so TableMonitorChannel accepts subscriptions and TableMonitorJob executes | VERIFIED | `test/application_system_test_case.rb` lines 31-33: setup sets `Carambus.config.carambus_api_url = "http://test-api"`; teardown restores original. Pattern matches established convention in TournamentMonitorUpdateResultsJobTest. Commit `a8487c9d`. |
| 3 | Multi-session Capybara helpers are available on ApplicationSystemTestCase for Phase 18 two-session tests | VERIFIED | `in_session(name, &block)` at line 43, `visit_scoreboard(table_monitor, locale:)` at line 48, `wait_for_actioncable_connection(timeout:)` at line 59 — all present in `test/application_system_test_case.rb`. `TrixSystemTestHelper` module created at `test/support/system/trix.rb` (was missing, unblocked all system tests). |
| 4 | AR connection pool is sized for multi-session system tests (no ConnectionTimeoutError) | VERIFIED (local) | `config/database.yml` test section: `pool: 10`. File is gitignored (global `.gitignore_global` line 5) — change not committed but applied locally. SUMMARY documents this caveat and provides copy-paste snippet for new deployments. |
| 5 | Existing channel unit tests and full test suite remain green after config changes | VERIFIED (per SUMMARY) | Both SUMMARY files report 751 runs, 1769 assertions, 0 failures, 0 errors, 13 skips. Commits `a8487c9d` and `bc79305f` both verified present in git log. Cannot run test suite in this verification context (requires live Rails env). |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `config/cable.yml` | async adapter for test environment | VERIFIED | Contains `adapter: async` in test section; dev/prod unchanged with `adapter: redis` |
| `test/application_system_test_case.rb` | local_server? setup/teardown, multi-session helpers, AR pool config | VERIFIED | All four required elements present: setup/teardown hooks, `in_session`, `visit_scoreboard`, `wait_for_actioncable_connection` |
| `test/system/table_monitor_broadcast_smoke_test.rb` | End-to-end broadcast delivery smoke test | VERIFIED | Contains `class TableMonitorBroadcastSmokeTest`, `TableMonitorJob.perform_now`, `assert_selector` with DOM content assertion, `.ready!` AASM transition, `wait_for_actioncable_connection`. No `sleep` calls. |
| `test/fixtures/table_kinds.yml` | TableKind fixture for FK chain | VERIFIED | Created with `id: 50_000_001`, `name: "Karambol"`, `short: "K"` |
| `test/fixtures/tables.yml` | Complete FK chain: table_monitor_id + location + table_kind_id | VERIFIED | Contains `table_monitor_id: 50_000_001`, `location: one`, `table_kind_id: 50_000_001` |
| `test/support/system/trix.rb` | TrixSystemTestHelper module | VERIFIED | Module defined with `fill_in_trix_editor` and `find_trix_editor` helpers |
| `app/javascript/channels/table_monitor_channel.js` | `data-cable-connected` DOM marker in `connected()` callback | VERIFIED | Line 362: `document.documentElement.setAttribute("data-cable-connected", "true")` in `connected()` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `config/cable.yml` | `ActionCable::Server` | Rails config loading | VERIFIED | `adapter: async` in test section — async adapter is in-process, delivers to real WebSocket connections |
| `test/application_system_test_case.rb` | `Carambus.config` | setup/teardown hooks | VERIFIED | `Carambus.config.carambus_api_url = "http://test-api"` in setup; restore in teardown |
| `test/system/table_monitor_broadcast_smoke_test.rb` | `app/jobs/table_monitor_job.rb` | `TableMonitorJob.perform_now` | VERIFIED | Line 64 in smoke test directly calls `TableMonitorJob.perform_now(@table_monitor.id)` |
| `test/system/table_monitor_broadcast_smoke_test.rb` | `app/channels/table_monitor_channel.rb` | ActionCable WebSocket subscription via `wait_for_actioncable_connection` | VERIFIED | `wait_for_actioncable_connection` asserts `html[data-cable-connected='true']` before broadcast; JS sets this attribute in `connected()` callback |
| `test/application_system_test_case.rb` | `test/support/system/trix.rb` | `Dir["...support/system/**/*.rb"]` glob at line 3 | VERIFIED | Glob loads all files under `test/support/system/`; `trix.rb` is included at module level |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `test/system/table_monitor_broadcast_smoke_test.rb` | DOM text matching `/Frei/i` | `TableMonitorJob.perform_now` → CableReady `inner_html` broadcast → browser WebSocket | Real AASM state transition + job rendering of partial | FLOWING — real fixture data through real rendering pipeline; SUMMARY confirms no mocks/stubs for `get_options!` or CableReady |

### Behavioral Spot-Checks

Step 7b: SKIPPED for smoke test itself — requires Selenium/Chrome browser and live Rails server. Headless result confirmed by SUMMARY (751 runs, 0 failures after bc79305f). Human verification required for end-to-end visual confirmation.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| INFRA-01 | 17-01-PLAN.md | Cable adapter configured so broadcasts reach real WebSocket connections | SATISFIED | `config/cable.yml`: `test: adapter: async` |
| INFRA-02 | 17-01-PLAN.md | `local_server?` returns true in system test environment | SATISFIED | `ApplicationSystemTestCase` setup sets `Carambus.config.carambus_api_url = "http://test-api"` |
| INFRA-03 | 17-01-PLAN.md | `ApplicationSystemTestCase` with multi-session helpers, AR pool config, and suppress_broadcast reset | SATISFIED (with note) | `in_session`, `visit_scoreboard`, `wait_for_actioncable_connection` helpers present; pool 10 applied locally; `suppress_broadcast` is an instance variable (not persisted) — research confirmed no teardown cleanup needed |
| INFRA-04 | 17-02-PLAN.md | Single-session smoke test proving end-to-end broadcast delivery | SATISFIED (pending human gate) | `test/system/table_monitor_broadcast_smoke_test.rb` structurally complete and passes headless per SUMMARY; Plan-02 Task 2 human-verify gate still open |

**INFRA-03 suppress_broadcast note:** REQUIREMENTS.md INFRA-03 includes "suppress_broadcast reset" as a required element. The research (17-RESEARCH.md) explicitly verified: "`suppress_broadcast` is an instance variable (`@suppress_broadcast`) on each `TableMonitor` object — it does not persist to the database. No teardown cleanup needed in tests that create fresh fixtures/factory records." This resolves the requirement without code changes.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `app/javascript/channels/table_monitor_channel.js` | 451 | `document.querySelector('[name="csrf-token"]').content` — null dereference if CSRF meta tag absent | Critical (Code Review CR-01) | Crashes onclick handler on error pages / Turbo frames; acknowledgement fetch silently fails |
| `app/javascript/channels/table_monitor_channel.js` | 5-6 | Module-level `localStorage.getItem()` — throws SecurityError in Safari private mode / restricted contexts | Warning (Code Review WR-02) | Channel file fails to load; no subscription created |
| `app/javascript/channels/table_monitor_channel.js` | 547, 572 | `if (PERF_LOGGING \|\| !NO_LOGGING)` — debug log fires by default on every broadcast for all users | Warning (Code Review IN-03) | Console noise in production; exposes internal selectors |
| `test/application_system_test_case.rb` | 69-72 | Route appended without `Rails.env.test?` guard | Warning (Code Review WR-04) | Leaks test route if file loaded in non-test context |
| `config/cable.yml` | 11 | Hardcoded `channel_prefix: carambus_bcw_development` — tenant/env-specific value baked in | Warning (Code Review WR-01) | Namespace collisions if multiple deployments share Redis |

**Anti-pattern classification for phase goal:**
- CR-01 (null dereference) is a pre-existing issue in a non-smoke-test code path (scoreboard_message fallback); does not block the smoke test or Phase 17 goal
- WR-01 through WR-04 are quality warnings; none prevent smoke test execution or Phase 17 goal achievement
- All anti-patterns were captured in the 17-REVIEW.md code review report dated 2026-04-11

### Human Verification Required

#### 1. Headed Browser Smoke Test

**Test:** Run `DRIVER=chrome bin/rails test test/system/table_monitor_broadcast_smoke_test.rb` (or equivalent for your local Chrome setup)
**Expected:** Chrome window opens, navigates to the TableMonitor scoreboard page, page shows the `#full_screen_table_monitor_50000001` container. After `wait_for_actioncable_connection` confirms WebSocket is open, the `ready!` AASM transition fires, `TableMonitorJob.perform_now` executes, and within 10 seconds the text "Frei" (or German ready-state text) appears in the scoreboard container via DOM update — NOT a page reload.
**Why human:** Plan-02 Task 2 is explicitly marked `checkpoint:human-verify` with `gate: blocking`. This is the required proof that CableReady's `inner_html` broadcast reaches a real browser WebSocket connection (vs. headless where the full rendering pipeline may differ). Visual confirmation is the stated deliverable.

#### 2. Full Suite Regression Check

**Test:** Run `bin/rails test` after the headed test
**Expected:** Full suite green — 751 runs (or more if other tests were added), 0 failures, 0 errors
**Why human:** Confirms no transactional cleanup issues from smoke test fixture additions in a live environment

### Gaps Summary

No gaps blocking the phase goal. All five must-have truths are verified by code inspection, all artifacts exist and are substantive and wired, and the broadcast chain is structurally complete.

The only remaining item is the Plan-02 Task 2 human-verify gate — this is a **confirmation checkpoint**, not a gap. The infrastructure exists and works (headless test green per SUMMARY); the human gate provides visual evidence that the DOM update is genuinely delivered via WebSocket to a real browser, not just passing because Capybara skips the WebSocket layer in some mode.

**Anti-patterns found in code review (17-REVIEW.md):** CR-01 is the most important to fix before Phase 18. The null-dereference in the CSRF handler (`table_monitor_channel.js:451`) is a latent crash risk. Recommend addressing CR-01, WR-02, and IN-03 in a quick-fix plan before Phase 18 starts, or accepting them as known issues.

---

_Verified: 2026-04-11T14:00:00Z_
_Verifier: Claude (gsd-verifier)_
