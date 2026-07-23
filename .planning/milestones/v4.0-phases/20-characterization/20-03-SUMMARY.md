---
phase: 20-characterization
plan: "03"
subsystem: party_monitor
tags: [characterization, aasm, state-machine, test-coverage, party-monitor]
dependency_graph:
  requires: []
  provides: [party-monitor-aasm-characterization, party-monitor-placement-characterization]
  affects: [phase-22-party-monitor-extraction]
tech_stack:
  added: []
  patterns: [characterization-tests, test-helper-module, aasm-state-machine-testing, pessimistic-locking]
key_files:
  created:
    - test/support/party_monitor_test_helper.rb
    - test/models/party_monitor_aasm_test.rb
    - test/models/party_monitor_placement_test.rb
  modified: []
decisions:
  - "Documented accumulate_results data= persistence bug as characterization finding rather than fixing it — pre-existing behavior"
  - "Skipped reset_party_monitor callback test due to pre-existing nil.to_hash bug when party has no game_plan"
  - "Used update_column(:state) to set AASM states directly — avoids triggering callbacks that require complex setup"
metrics:
  duration: ~35min
  completed: "2026-04-11"
  tasks_completed: 2
  files_created: 3
  test_runs: 40
  assertions: 108
  failures: 0
  errors: 0
  skips: 1
---

# Phase 20 Plan 03: PartyMonitor Characterization Summary

**One-liner:** PartyMonitor AASM 9-state machine and operational paths (do_placement, report_result, round management, result pipeline) pinned with 40 characterization tests.

## What Was Built

Three test files characterizing PartyMonitor (605 lines) before Phase 22 extraction:

1. **`test/support/party_monitor_test_helper.rb`** — Shared factory module `PartyMonitorTestHelper` providing `create_party_monitor_with_party` with local IDs to avoid fixture collisions. Used by both test files.

2. **`test/models/party_monitor_aasm_test.rb`** — 19 tests (1 skip) covering all 9 AASM states and all 8 events: state inventory, happy path transitions (seeding → playing_round, playing_round → closed), individual event tests, invalid transition assertions (AASM::InvalidTransition), end_of_party from all non-closed states, party_result_reporting_mode legacy state, ApiProtectorTestOverride verification, and reset_party_monitor callback.

3. **`test/models/party_monitor_placement_test.rb`** — 21 tests covering round management (current_round, incr/decr/set), do_placement existence and signature, initialize_table_monitors with no table_ids, report_result pessimistic lock pattern, and all result pipeline methods (finalize_game_result, finalize_round, accumulate_results, update_game_participations).

## Test Results

```
40 runs, 108 assertions, 0 failures, 0 errors, 1 skip
```

## Deviations from Plan

### Auto-fixed Issues

None.

### Documented Characterization Findings

**1. [Characterization Finding] next_seqno missing on PartyMonitor**
- **Found during:** Task 2
- **Issue:** `do_placement` calls `next_seqno` (line 174) but the method is only defined on `TournamentMonitor`, not `PartyMonitor`. Calling `do_placement` with a new game that has no seqno would raise `NoMethodError`.
- **Test pin:** `test "next_seqno is NOT defined on PartyMonitor"` — refutes respond_to
- **Files:** `app/models/party_monitor.rb:174`, `app/models/tournament_monitor.rb:173`

**2. [Characterization Finding] write_game_result_data missing on PartyMonitor**
- **Found during:** Task 2
- **Issue:** `report_result` calls `write_game_result_data` (line 304) but the method is only defined on `TournamentMonitor`. Any call to `report_result` with a game present will raise `NoMethodError` (caught and re-raised as `StandardError`).
- **Test pin:** `test "write_game_result_data is NOT defined on PartyMonitor"` and `test "report_result ... propagates errors as StandardError"`
- **Files:** `app/models/party_monitor.rb:304`

**3. [Characterization Finding] accumulate_results data= persistence bug**
- **Found during:** Task 2
- **Issue:** `accumulate_results` uses `data["rankings"] = rankings` to mutate a `HashWithIndifferentAccess` wrapper, not the underlying attribute. The `data_will_change!` marks the column dirty but `save!` persists the original unmodified data. After `reload`, `data["rankings"]` is nil.
- **Test pin:** `test "accumulate_results ... does not persist rankings"` — asserts nil after reload
- **Files:** `app/models/party_monitor.rb:492-495`

**4. [Skip] reset_party_monitor nil.to_hash bug**
- **Found during:** Task 1
- **Issue:** `reset_party_monitor` raises `NoMethodError: undefined method 'to_hash' for nil:NilClass` when party has no game_plan. `self.data = data.presence || @game_plan&.data.dup` evaluates to `nil` when both are absent.
- **Resolution:** Test skipped with documented finding; after_enter callback registration verified separately.
- **Files:** `app/models/party_monitor.rb:130`

### Deviations: Setup

**Worktree config symlinks required** — The git worktree lacked `config/database.yml` and `config/carambus.yml` (untracked files). Symlinks were created pointing to the main repo copies to enable test execution within the worktree.

## Known Stubs

None — test-only plan, no production code changes.

## Threat Flags

None — test-only plan, no new attack surface.

## Self-Check

Files created:
- [x] test/support/party_monitor_test_helper.rb
- [x] test/models/party_monitor_aasm_test.rb
- [x] test/models/party_monitor_placement_test.rb

Commits:
- [x] ba14a823 — test(20-03): PartyMonitor AASM state machine characterization
- [x] 0bd0ba8c — test(20-03): PartyMonitor placement, round management, result pipeline

## Self-Check: PASSED
