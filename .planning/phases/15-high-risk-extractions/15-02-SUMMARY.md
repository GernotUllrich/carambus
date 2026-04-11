---
phase: 15-high-risk-extractions
plan: "02"
subsystem: testing
tags: [ruby, rails, tournament_monitor, table_populator, refactoring, extraction, services]

# Dependency graph
requires:
  - phase: 15-high-risk-extractions
    plan: "01"
    provides: "ResultProcessor extracted; accumulate_results delegation wrapper on TournamentMonitor"
provides:
  - "TournamentMonitor::TablePopulator service (populate_tables, initialize_table_monitors, do_placement, do_reset_tournament_monitor)"
  - "lib/tournament_monitor_support.rb removed (D-11 complete)"
  - "lib/tournament_monitor_state.rb reduced to 5 query methods only"
  - "Delegation wrappers on TournamentMonitor for do_reset_tournament_monitor, populate_tables, initialize_table_monitors"
affects:
  - "Phase 15 completion — all high-risk extractions done"
  - "Future maintainability of TournamentMonitor god-object"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "PORO service pattern with constructor injection (same as RankingResolver, ResultProcessor)"
    - "Intra-service calls (populate_tables called directly in do_reset_tournament_monitor, no model round-trip)"
    - "D-11: empty lib modules removed entirely + include removed from model"
    - "TournamentMonitor.allow_change_tables (cattr_accessor) used in service, not self."

key-files:
  created:
    - app/services/tournament_monitor/table_populator.rb
    - test/services/tournament_monitor/table_populator_test.rb
  modified:
    - app/models/tournament_monitor.rb
    - lib/tournament_monitor_state.rb
  deleted:
    - lib/tournament_monitor_support.rb

key-decisions:
  - "TablePopulator follows PORO pattern (not ApplicationService) — multiple public entry points"
  - "populate_tables called intra-service in do_reset_tournament_monitor (Pitfall C avoided)"
  - "TournamentMonitor.allow_change_tables used in service (not self.) — cattr_accessor correctness"
  - "lib/tournament_monitor_support.rb deleted entirely per D-11 (empty after extraction)"
  - "try do blocks preserved exactly — not converted to begin/rescue"

patterns-established:
  - "Pattern: AASM after_enter symbols delegate to model method which instantiates service — no AASM block changes needed"
  - "Pattern: self.method_name conversions to @tournament_monitor.method_name (D-09)"

requirements-completed: [TMEX-04]

# Metrics
duration: 75min
completed: 2026-04-11
---

# Phase 15 Plan 02: TablePopulator Extraction Summary

**500+ line table population algorithm extracted from lib modules into TournamentMonitor::TablePopulator PORO service, with lib/tournament_monitor_support.rb fully deleted and tournament_monitor_state.rb reduced to 5 query methods**

## Performance

- **Duration:** ~75 min
- **Started:** 2026-04-11T00:30:00Z
- **Completed:** 2026-04-11T01:45:00Z
- **Tasks:** 2
- **Files modified:** 4 (1 created, 1 deleted, 2 modified + 1 new test file)

## Accomplishments

- Created `TournamentMonitor::TablePopulator` PORO service with all 4 methods extracted from lib modules (populate_tables, initialize_table_monitors, do_placement private, do_reset_tournament_monitor)
- All `self.` → `@tournament_monitor.` conversions applied correctly per D-09; `TournamentMonitor.allow_change_tables` used instead of `self.allow_change_tables` per Pitfall D
- `lib/tournament_monitor_support.rb` deleted entirely (D-11 — all methods extracted); `include TournamentMonitorSupport` removed from model
- `lib/tournament_monitor_state.rb` reduced from ~410 lines to ~89 lines — retains only 5 query methods (finalize_round, group_phase_finished?, finals_finished?, all_table_monitors_finished?, table_monitors_ready?)
- 15 unit tests (table_populator_test.rb) + 62 characterization tests + 37 additional service tests all pass: 114 total, 0 failures, 0 errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Create TablePopulator service + unit tests** - `51cb9ba5` (feat)
2. **Task 2: Wire delegation wrappers + remove lib methods + cleanup** - `9d847487` (feat)

## Files Created/Modified

- `app/services/tournament_monitor/table_populator.rb` — PORO service with populate_tables, initialize_table_monitors, do_placement (private), do_reset_tournament_monitor
- `test/services/tournament_monitor/table_populator_test.rb` — 15 unit tests covering public interface, constructor contract, intra-service call invariants, cattr_accessor usage
- `app/models/tournament_monitor.rb` — Added delegation wrappers for do_reset_tournament_monitor, populate_tables, initialize_table_monitors; removed `include TournamentMonitorSupport`
- `lib/tournament_monitor_state.rb` — Removed do_reset_tournament_monitor; now contains only 5 query methods (89 lines)
- `lib/tournament_monitor_support.rb` — DELETED (D-11)

## Decisions Made

- Used PORO pattern (not ApplicationService) for TablePopulator because it has 3+ public entry points called independently
- `populate_tables` called directly from `do_reset_tournament_monitor` (intra-service) — not via `@tournament_monitor.populate_tables` (which would round-trip through the model delegation layer, creating unnecessary indirection)
- `try do` blocks preserved exactly as extracted — not converted to begin/rescue (same gem dependency, same semantics)
- `TournamentMonitor.allow_change_tables` used in service (not `self.`) — cattr_accessor belongs to the class, not the service instance

## Deviations from Plan

### Infrastructure Fix

**1. [Rule 3 - Blocking] Worktree missing config/carambus.yml and config/database.yml**
- **Found during:** Task 1 (running tests for first time)
- **Issue:** Git worktree doesn't inherit symlinks from main repo; `carambus.yml` and `database.yml` were missing
- **Fix:** Created symlinks to main repo config files
- **Verification:** `bin/rails runner` succeeded; test suite ran correctly
- **Committed in:** N/A (infrastructure, not code changes)

---

**Total deviations:** 1 infrastructure fix (pre-existing worktree setup issue)
**Impact on plan:** No code changes required; infrastructure-only fix.

## Issues Encountered

- Worktree fixture loading failed with `ActiveRecord::Fixture::FixtureError: table "club_locations" has no columns named "club", "location"` — root cause was missing `config/carambus.yml` symlink causing Rails to boot in wrong state. Fixed by symlinking both config files.
- `File.expand_path("../../../../...", __dir__)` path calculation was off by one level — corrected to `../../../` for test files in `test/services/tournament_monitor/`.

## Known Stubs

None — all methods are fully implemented with real business logic.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced. TablePopulator calls existing model methods only.

## Next Phase Readiness

- All high-risk TournamentMonitor extractions complete (Plan 01: ResultProcessor, Plan 02: TablePopulator)
- Phase 15 is complete — both plans done, all tests green
- `lib/tournament_monitor_support.rb` fully deleted; `lib/tournament_monitor_state.rb` now contains only state query methods
- TournamentMonitor model (tournament_monitor.rb) is now 218 lines, down from its original large size

## Self-Check: PASSED

- `app/services/tournament_monitor/table_populator.rb` — EXISTS
- `test/services/tournament_monitor/table_populator_test.rb` — EXISTS
- Commit `51cb9ba5` — EXISTS (feat(15-02): create TablePopulator service)
- Commit `9d847487` — EXISTS (feat(15-02): wire TablePopulator delegation)
- `lib/tournament_monitor_support.rb` — REMOVED (confirmed via `ls` returning ENOENT)
- `grep -c "TablePopulator.new(self)" tournament_monitor.rb` — returns 3 ✓
- `grep -c "def do_reset_tournament_monitor" tournament_monitor_state.rb` — returns 0 ✓
- `grep -c "def finalize_round" tournament_monitor_state.rb` — returns 1 ✓
- All 114 tests pass (0 failures, 0 errors, 2 skips)

---
*Phase: 15-high-risk-extractions*
*Completed: 2026-04-11*
