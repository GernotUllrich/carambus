---
phase: 13-low-risk-extractions
plan: "03"
subsystem: tournament-services
tags: [extraction, service-object, google-calendar, tdd, ruby]
dependency_graph:
  requires: [13-02]
  provides: [Tournament::TableReservationService]
  affects: [app/models/tournament.rb, app/services/tournament/, test/models/tournament_calendar_test.rb, test/models/tournament_auto_reserve_test.rb, test/tasks/auto_reserve_tables_test.rb]
tech_stack:
  added: [Tournament::TableReservationService < ApplicationService]
  patterns: [ApplicationService delegation, private method extraction, TDD red-green]
key_files:
  created:
    - app/services/tournament/table_reservation_service.rb
    - test/services/tournament/table_reservation_service_test.rb
  modified:
    - app/models/tournament.rb
    - test/models/tournament_calendar_test.rb
    - test/models/tournament_auto_reserve_test.rb
    - test/tasks/auto_reserve_tables_test.rb
decisions:
  - fallback_table_count retained on Tournament model because required_tables_count (per D-07) calls it directly
  - stub_calendar_event helpers in tournament_auto_reserve_test.rb and auto_reserve_tables_test.rb updated to stub TableReservationService.call rather than a tournament private method
  - tournament_calendar_test.rb updated to invoke create_google_calendar_event via service instance (not tournament.send)
metrics:
  duration_minutes: 16
  completed_date: "2026-04-10"
  tasks_completed: 2
  files_created: 2
  files_modified: 4
---

# Phase 13 Plan 03: TableReservationService Extraction Summary

**One-liner:** Extracted Google Calendar reservation flow into Tournament::TableReservationService ApplicationService, removing 5 private helpers from tournament.rb and updating all test stubs.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create TableReservationService with unit tests (TDD) | 3867ae43 | app/services/tournament/table_reservation_service.rb, test/services/tournament/table_reservation_service_test.rb |
| 2 | Wire delegation in Tournament, remove private helpers, verify all tests | db285bc4 | app/models/tournament.rb, test/models/tournament_calendar_test.rb, test/models/tournament_auto_reserve_test.rb, test/tasks/auto_reserve_tables_test.rb |

## What Was Built

Tournament::TableReservationService extracts the Google Calendar reservation cluster from Tournament:

- Public `call` method: full guard chain (location, discipline, date, required_tables_count, available_tables_with_heaters)
- Private methods: `format_table_list`, `build_event_summary`, `calculate_start_time`, `calculate_end_time`, `create_google_calendar_event`
- All self-references converted to `@tournament.` prefix
- `fallback_table_count` retained on Tournament model (shared with `required_tables_count` per D-07)

Tournament#create_table_reservation is now a single-line delegation:
```ruby
def create_table_reservation
  Tournament::TableReservationService.call(tournament: self)
end
```

## Verification Results

- `test/services/tournament/table_reservation_service_test.rb`: 10 runs, 17 assertions, 0 failures
- `test/models/tournament_calendar_test.rb`: passes unchanged (test objects updated to service instance)
- Full suite: 632 runs, 1548 assertions, 0 failures, 0 errors, 11 skips

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] fallback_table_count removed too aggressively**
- **Found during:** Task 2 full suite run
- **Issue:** `required_tables_count` on Tournament calls `fallback_table_count` as a private helper. It was extracted to the service but also needed on the model.
- **Fix:** Restored `fallback_table_count` as a private method on Tournament model. It now exists in both places (model for `required_tables_count`, service for the reservation flow).
- **Files modified:** app/models/tournament.rb
- **Commit:** db285bc4

**2. [Rule 1 - Bug] Characterization tests called private method on wrong object**
- **Found during:** Task 2 characterization test run
- **Issue:** `tournament_calendar_test.rb` used `@tournament.send(:create_google_calendar_event, ...)` — the method no longer exists on Tournament after extraction.
- **Fix:** Updated 3 tests to instantiate `Tournament::TableReservationService.new(tournament: @tournament)` and call `.send(:create_google_calendar_event, ...)` on the service instance.
- **Files modified:** test/models/tournament_calendar_test.rb
- **Commit:** db285bc4

**3. [Rule 1 - Bug] stub_calendar_event helpers used tournament-level stub**
- **Found during:** Task 2 full suite run
- **Issue:** `tournament_auto_reserve_test.rb` and `auto_reserve_tables_test.rb` had `stub_calendar_event` helpers that called `tournament.stub(:create_google_calendar_event, ...)`. After extraction, this stub never applied because the delegation goes through the service.
- **Fix:** Updated both helpers to `Tournament::TableReservationService.stub(:call, ->(_kwargs) { fake_response })`. Updated the "handles Google API errors gracefully" test to use `Rails.application.credentials.stub` + `GoogleCalendarService` stubs directly.
- **Files modified:** test/models/tournament_auto_reserve_test.rb, test/tasks/auto_reserve_tables_test.rb
- **Commit:** db285bc4

## Phase 13 Combined Reduction

| Plan | Extraction | Lines Removed |
|------|-----------|---------------|
| 13-01 | PlayerGroupDistributor from TournamentMonitor | ~160 lines |
| 13-02 | RankingCalculator from Tournament | ~47 lines |
| 13-03 | TableReservationService from Tournament | ~116 lines (body + 5 helpers) |
| **Total** | | **~323 lines** |

tournament.rb: 1725 lines → 1594 lines (131 lines removed in this plan)

## Known Stubs

None. All extracted methods are fully implemented and wired.

## Threat Flags

None. The Google Calendar trust boundary (tournament.rb -> Google Calendar API) is unchanged — the same credential access pattern, same `rescue StandardError` handling, same `GoogleCalendarService` class methods. No new surface introduced.

## Self-Check: PASSED

- app/services/tournament/table_reservation_service.rb: FOUND
- test/services/tournament/table_reservation_service_test.rb: FOUND
- Commit 3867ae43: FOUND
- Commit db285bc4: FOUND
- Full suite: 632 runs, 0 failures, 0 errors
