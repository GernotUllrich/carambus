---
phase: 04-tablemonitor-gamesetup-optionspresenter
plan: 01
subsystem: services
tags: [table-monitor, game-setup, application-service, extraction, ruby, rails]

requires: []
provides:
  - "TableMonitor::GameSetup ApplicationService with .call(table_monitor:, options:) and .assign(table_monitor:, game_participation:) entry points"
  - "Extracted start_game logic: Game/GameParticipation creation, result hash builder, initialize_game call, single job enqueue"
  - "ensure block guarantees skip_update_callbacks reset even on exception"
  - "10 unit tests covering both game-creation branches, shootout, ensure cleanup, job enqueue"
affects:
  - "04-02-PLAN (wiring: TableMonitor#start_game delegates to GameSetup)"
  - "04-03-PLAN (OptionsPresenter depends on same options hash)"

tech-stack:
  added: []
  patterns:
    - "ApplicationService subclass with keyword-arg initialize: def initialize(kwargs = {}) destructuring"
    - "Two-entry-point service: .call for main flow, .assign for assign_game flow"
    - "ensure block for resource cleanup (suppress_broadcast = false guarantee)"
    - "Private method decomposition: setup_existing_party_game, create_new_game, build_result_hash"

key-files:
  created:
    - app/services/table_monitor/game_setup.rb
    - test/services/table_monitor/game_setup_test.rb

key-decisions:
  - "Used skip_update_callbacks (existing accessor) per plan note; Plan 02 will rename to suppress_broadcast"
  - "perform_assign made public (not protected) to allow .assign class method to call it via new instance"
  - "Game parameter in assign branch is a Game object (not GameParticipation) — existing assign_game naming is misleading"
  - "set_player_sequence extracted as private method of GameSetup (references @tm.a..@tm.d internals)"

patterns-established:
  - "GameSetup pattern: suppress_broadcast wraps entire call in ensure"
  - "Single job enqueue at end of batch saves (not during intermediate saves)"

requirements-completed: [TMON-02]

duration: 25min
completed: 2026-04-10
---

# Phase 04 Plan 01: GameSetup ApplicationService Summary

**TableMonitor::GameSetup extracts start_game/assign_game from the 3900-line model into a testable ApplicationService with dual entry points, ensure-guaranteed broadcast cleanup, and single job enqueue**

## Performance

- **Duration:** 25 min
- **Started:** 2026-04-10T10:46:00Z
- **Completed:** 2026-04-10T11:11:00Z
- **Tasks:** 1 (TDD)
- **Files modified:** 2

## Accomplishments
- Created `TableMonitor::GameSetup < ApplicationService` with `.call(table_monitor:, options:)` interface
- Extracted full start_game logic: two branches (existing party game vs new game creation), result hash builder, initialize_game, deep_merge_data!, single TableMonitorJob at end
- Second class entry point `.assign(table_monitor:, game_participation:)` for assign_game logic
- ensure block guarantees `skip_update_callbacks = false` even on exception (T-04-02 mitigation)
- Options coerced to `HashWithIndifferentAccess` (T-04-01 mitigation)
- 10 unit tests passing: Game creation, GameParticipation creation, party game preservation, unlinking, result hash, broadcast flag, job enqueue count, shootout, ensure cleanup, assign branch

## Task Commits

1. **Task 1: Create GameSetup ApplicationService with unit tests** - `8272b806` (feat)

## Files Created/Modified
- `app/services/table_monitor/game_setup.rb` - GameSetup service encapsulating start_game and assign_game logic
- `test/services/table_monitor/game_setup_test.rb` - 10 unit tests covering both branches and edge cases

## Decisions Made
- Used `skip_update_callbacks` (existing accessor on TableMonitor) per plan spec; Plan 02 renames to `suppress_broadcast`
- Made `perform_assign` public (not protected) so `.assign` class method can call it on a new instance — protected methods cannot be called externally even via self
- The `game_participation:` parameter in `.assign` is actually a Game object (the original `assign_game(game_p)` naming was misleading — `game_p` = party game)
- `set_player_sequence` references `@tm.a..@tm.d` which are instance-level methods; kept as private method of GameSetup but marked for review in Plan 02

## Deviations from Plan

None - plan executed exactly as written.

Minor tactical adjustments (not deviations):
- Worktree lacked `database.yml` and `carambus.yml` (symlinked files) — copied from main repo to unblock tests (Rule 3: auto-fix blocking issue)
- Player fixture used `firstname`/`lastname` (not `name`) per actual schema — test corrected
- `table_monitor_id` on Game does not exist (Game has_one TableMonitor via game_id on table_monitors) — test assertion corrected

## Issues Encountered
- Worktree missing `config/database.yml` and `config/carambus.yml` (not tracked in git, only `.erb` templates) — resolved by copying from main repo
- Player model has no `name` attribute — uses `firstname`/`lastname`, `dbu_nr` is integer
- Game.table_monitor_id does not exist (relationship is has_one via FK on table_monitors table)
- `perform_assign` needed to be public for class method delegation to work

## Threat Surface Scan

No new network endpoints, auth paths, or schema changes introduced. GameSetup creates Game/GameParticipation records identically to existing start_game — no new data paths. Options hash coerced to HashWithIndifferentAccess (T-04-01 mitigated). Ensure block guarantees suppress_broadcast cleanup (T-04-02 mitigated).

## Known Stubs

None — GameSetup is a standalone service not yet wired into TableMonitor. The model's start_game method still exists unchanged; Plan 02 will wire GameSetup in and remove the model method.

## Next Phase Readiness
- GameSetup service complete and independently testable
- Ready for Plan 02: wire `TableMonitor#start_game` to delegate to `GameSetup.call`
- Plan 03 (OptionsPresenter) can proceed in parallel since it reads same options hash

## Self-Check: PASSED

---
*Phase: 04-tablemonitor-gamesetup-optionspresenter*
*Completed: 2026-04-10*
