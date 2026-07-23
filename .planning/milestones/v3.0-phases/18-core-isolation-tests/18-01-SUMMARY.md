---
phase: 18-core-isolation-tests
plan: "01"
subsystem: system-tests
tags: [system-test, actioncable, cable-ready, broadcast-isolation, capybara, selenium]
dependency_graph:
  requires:
    - 17-02-SUMMARY.md  # ApplicationSystemTestCase helpers (in_session, visit_scoreboard, wait_for_actioncable_connection)
  provides:
    - table_monitors(:two) and tables(:two) fixtures for Plan 02 concurrent tests
    - ISOL-01 morph path isolation proof (two-session, positive + negative assertions)
    - ISOL-04 JS filter execution proof (console.warn DOM marker counter)
  affects:
    - test/fixtures/table_monitors.yml
    - test/fixtures/tables.yml
    - test/system/table_monitor_isolation_test.rb
tech_stack:
  added: []
  patterns:
    - DOM marker counter for console.warn capture (window._mixupPreventedCount)
    - in_session(:name) two-session Capybara pattern for isolation testing
    - sleep 2 for absence assertions (no poll target — acceptable for negative DOM check)
key_files:
  created:
    - test/system/table_monitor_isolation_test.rb
  modified:
    - test/fixtures/table_monitors.yml
    - test/fixtures/tables.yml
decisions:
  - DOM marker counter approach chosen over Selenium logs API (Research Pitfall 5: logs API may be unavailable)
  - sleep 2 accepted for negative assertion — asserting absence requires waiting, no poll target
  - find_or_create_by! for @game_b (id: 50_000_101) — system tests non-transactional, idempotent cleanup needed
metrics:
  duration: ~15min
  completed: "2026-04-11T12:26:01Z"
  tasks_completed: 2
  files_changed: 3
  test_results: "1 run, 7 assertions, 0 failures, 0 errors"
---

# Phase 18 Plan 01: Second Fixtures and Morph Path Isolation Test Summary

**One-liner:** Two-session Capybara test proves scoreboard A DOM is unchanged when TM-B fires state changes, with console.warn DOM marker proving the JS filter actively rejected the foreign broadcast (not a vacuous assertion).

## What Was Built

### Task 1 — Second TableMonitor and Table Fixtures (commit b7976ccb)

Added a second fixture pair for two-session isolation tests (per D-02):

- `table_monitors(:two)` — id: 50_000_002, ip: 192.168.1.2, state: "new"
- `tables(:two)` — id: 50_000_002, linked to TM two, same location one (distinct DOM IDs by design)

Both use `location: one` so both tables appear in the same location context. The distinct IDs ensure `#full_screen_table_monitor_50000001` and `#full_screen_table_monitor_50000002` are never confused. Existing smoke test passes unchanged (backward-compatible).

### Task 2 — Morph Path Isolation Test (commit 24ebc546)

Created `test/system/table_monitor_isolation_test.rb` (106 lines, 7 assertions):

**Test: ISOL-01 + ISOL-04**

Flow:
1. Session A opens TM-A scoreboard, confirms ActionCable connected, installs `window._mixupPreventedCount` console.warn interceptor
2. Session B opens TM-B scoreboard, confirms ActionCable connected
3. `@tm_b.ready! + TableMonitorJob.perform_now(@tm_b.id)` — fires inner_html broadcast to shared `table-monitor-stream` with selector `#full_screen_table_monitor_50000002`
4. **POSITIVE (Session B):** `assert_selector "#full_screen_table_monitor_#{@tm_b.id}", text: /Frei/i, wait: 10` — proves broadcast arrived and DOM updated
5. **NEGATIVE + ISOL-04 (Session A):** `sleep 2` then `evaluate_script("window._mixupPreventedCount")` > 0 — proves JS filter ran and emitted `console.warn("SCOREBOARD MIX-UP PREVENTED")`. Then `refute_selector "#full_screen_table_monitor_#{@tm_b.id}"` — proves DOM unchanged.

## Verification Results

```
1 runs, 7 assertions, 0 failures, 0 errors, 0 skips
```

Both the isolation test and the existing smoke test pass.

## Commits

| Task | Description | Hash | Files |
|------|-------------|------|-------|
| 1 | Add second TableMonitor + Table fixtures | b7976ccb | test/fixtures/table_monitors.yml, test/fixtures/tables.yml |
| 2 | Implement ISOL-01 + ISOL-04 isolation test | 24ebc546 | test/system/table_monitor_isolation_test.rb |

## Deviations from Plan

None — plan executed exactly as written.

The console.warn DOM marker approach (window._mixupPreventedCount) was specified in the plan (Research Pitfall 5) and implemented as designed. The sleep 2 for negative assertion is intentional and documented inline.

## Known Stubs

None — all data sources are wired to real fixtures and real AASM state transitions.

## Threat Flags

None — no new network endpoints, auth paths, or schema changes introduced. Test-only changes.

## Self-Check

Files created/modified:
- test/fixtures/table_monitors.yml: exists in worktree ✓
- test/fixtures/tables.yml: exists in worktree ✓
- test/system/table_monitor_isolation_test.rb: exists in worktree ✓

Commits:
- b7976ccb: verified via git log ✓
- 24ebc546: verified via git log ✓

Test execution: 1 run, 7 assertions, 0 failures — verified by running from main repo with temporary file copies ✓

## Self-Check: PASSED
