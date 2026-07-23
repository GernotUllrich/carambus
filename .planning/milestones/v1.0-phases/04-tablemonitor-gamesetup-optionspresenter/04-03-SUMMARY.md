---
phase: 04-tablemonitor-gamesetup-optionspresenter
plan: 03
subsystem: models
tags: [ruby, poro, table_monitor, options_presenter, minitest, refactoring]

# Dependency graph
requires:
  - phase: 04-tablemonitor-gamesetup-optionspresenter
    provides: ScoreEngine PORO pattern established in 04-01/04-02
provides:
  - "TableMonitor::OptionsPresenter PORO at app/models/table_monitor/options_presenter.rb"
  - "get_options! thin wrapper (~23 lines) in TableMonitor delegating to OptionsPresenter"
  - "11 unit tests for OptionsPresenter covering hash structure, player data, disambiguation, and readers"
affects:
  - 04-04-gamesetup-extraction (same pattern for GameSetup)
  - TableMonitorJob (reads options hash)
  - Scoreboard views (consume options hash keys)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "PORO extraction: build_options private method + attr_reader for side-output values"
    - "Singleton method stubbing (define_singleton_method) to stub AR associations in unit tests without full DB graph"
    - "cattr assignments stay in the AR wrapper — POROs never mutate class-level state"
    - "Disambiguation logic extracted to private method disambiguate_player_names!(options, gps, show_tournament_monitor)"

key-files:
  created:
    - app/models/table_monitor/options_presenter.rb
    - test/models/table_monitor/options_presenter_test.rb
  modified:
    - app/models/table_monitor.rb

key-decisions:
  - "Use attr_reader for gps/location/show_tournament/my_table — presenter exposes computed side-outputs so wrapper can assign cattr_accessors without re-querying"
  - "cattr assignments (self.class.options = ...) remain in the TableMonitor wrapper, not inside OptionsPresenter — keeps PORO free of model coupling"
  - "Stub table association via define_singleton_method in tests — avoids Table/Location/TableKind DB setup while still using real TableMonitor instances"
  - "Test the disambiguation-skip branch using OpenStruct mock for tournament_monitor — avoids PartyMonitor DB lifecycle complexity"

patterns-established:
  - "OptionsPresenter PORO pattern: initialize(model, locale:), call -> hash, attr_reader for side-outputs"
  - "Wrapper pattern: cache check -> presenter.call -> cattr assignments -> cache store -> return"

requirements-completed: [TMON-04]

# Metrics
duration: 18min
completed: 2026-04-10
---

# Phase 04 Plan 03: OptionsPresenter Extraction Summary

**get_options! extracted from ~193-line inline body to TableMonitor::OptionsPresenter PORO + 23-line delegation wrapper, with 11 unit tests — 121 total tests pass**

## Performance

- **Duration:** 18 min
- **Started:** 2026-04-10T10:30:00Z
- **Completed:** 2026-04-10T10:48:37Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Extracted 190 lines of get_options! body into `TableMonitor::OptionsPresenter` PORO (pure function, no AR writes)
- Player name disambiguation logic moved to private `disambiguate_player_names!` method inside OptionsPresenter
- OptionsPresenter exposes gps, location, show_tournament, my_table readers so the wrapper can assign cattr_accessors
- get_options! reduced from ~193 lines to 23-line thin wrapper with identical external interface
- 11 new unit tests added covering hash structure, player data, disambiguation, and reader values
- All 41 characterization tests pass without modification (stubs still work on the thin wrapper)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create OptionsPresenter PORO with unit tests** - `61136625` (feat)
2. **Task 2: Wire OptionsPresenter delegation in TableMonitor get_options!** - `10fed1a3` (feat)

## Files Created/Modified
- `app/models/table_monitor/options_presenter.rb` - New PORO; receives TableMonitor + locale, returns options hash; exposes gps/location/show_tournament/my_table readers
- `test/models/table_monitor/options_presenter_test.rb` - 11 unit tests using real AR records + singleton stub for table association
- `app/models/table_monitor.rb` - get_options! replaced with 23-line wrapper delegating to OptionsPresenter

## Decisions Made
- `cattr_accessors` stay in the wrapper (not OptionsPresenter): OptionsPresenter must be a pure function free of class-level state mutations — enables independent testing and reuse
- `attr_reader :gps, :location, :show_tournament, :my_table` on OptionsPresenter: the wrapper needs these values after `call` to assign catrs; reading them from the returned hash would require key lookups and is error-prone
- Test isolation via `define_singleton_method` to stub `table` association: avoids constructing the full Table -> Location -> TableKind -> ClubLocation DB graph while still testing on real TableMonitor instances
- Disambiguation-skip test uses OpenStruct mock for tournament_monitor: PartyMonitor.create! within test transaction is valid but the `is_a?(PartyMonitor)` check on an OpenStruct requires `define_singleton_method(:is_a?)` override

## Deviations from Plan

None - plan executed exactly as written. The TDD approach had tests pass on first run alongside the PORO implementation.

## Issues Encountered
- Initial disambiguation-skip test used `PartyMonitor.create!` + `update_columns` to simulate tournament_monitor, but `define_singleton_method(:is_a?)` on a real PartyMonitor wasn't needed — switched to OpenStruct mock to avoid potential `is_a?` check interference and DB complexity. All tests pass.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- OptionsPresenter pattern established; 04-04-GameSetup extraction can follow the same PORO pattern
- All 121 tests green (41 char + 11 OptionsPresenter + 69 ScoreEngine)
- TableMonitor.get_options! signature unchanged; no consumer changes needed

---
*Phase: 04-tablemonitor-gamesetup-optionspresenter*
*Completed: 2026-04-10*
