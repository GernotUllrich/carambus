# Phase 15: High-Risk Extractions - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract ResultProcessor (DB lock + AASM event firing) and TablePopulator (500-line populate_tables algorithm) from TournamentMonitor's lib modules. These are the highest-risk extractions — they involve pessimistic locking, AASM state transitions, and complex game sequencing logic. No new features or behavior changes.

</domain>

<decisions>
## Implementation Decisions

### ResultProcessor (TMEX-03)
- **D-01:** Extract as ApplicationService in `app/services/tournament_monitor/result_processor.rb`. Receives TournamentMonitor instance. The DB lock (`game.with_lock`) stays inside the service — it's part of the result processing logic, not model infrastructure.
- **D-02:** AASM events fired from the service via `@tournament_monitor.start_playing_finals!` etc. — the service calls AASM bang methods on the model reference. After_enter callbacks fire correctly because the event is called on the model, not the service.
- **D-03:** Methods to extract from `lib/tournament_monitor_support.rb`: `report_result`, `update_game_participations`, `update_game_participations_for_game`, `accumulate_results`, `add_result_to`, `update_ranking`.
- **D-04:** Methods to extract from `lib/tournament_monitor_state.rb`: `write_game_result_data`, `finalize_game_result`.
- **D-05:** `write_finale_csv_for_upload` from support.rb also moves — it's called by the result pipeline and has no other callers.

### TablePopulator (TMEX-04)
- **D-06:** Extract as ApplicationService in `app/services/tournament_monitor/table_populator.rb`. Receives TournamentMonitor instance. Contains `populate_tables`, `do_placement`, `initialize_table_monitors`.
- **D-07:** `do_reset_tournament_monitor` from `lib/tournament_monitor_state.rb` moves to TablePopulator — it's the entry point that calls `populate_tables`. The AASM `after_enter` callback on `new_tournament_monitor` stays on the model and delegates to the service.
- **D-08:** State query methods (`group_phase_finished?`, `finals_finished?`, `all_table_monitors_finished?`, `table_monitors_ready?`, `finalize_round`) stay on the model/lib modules — they are used by views, controllers, and other callers beyond just the populator. If they only serve populate_tables, Claude may move them.

### Shared Decisions
- **D-09:** Follow established extraction pattern: extract → delegate → test. `self` → `@tournament_monitor` conversion.
- **D-10:** Unit tests in `test/services/tournament_monitor/`. All Phase 11-12 characterization tests MUST pass unchanged.
- **D-11:** After extraction, the lib modules (`tournament_monitor_support.rb`, `tournament_monitor_state.rb`) should be significantly smaller. If either becomes empty, it can be removed entirely.

### Claude's Discretion
- Exact extraction boundary for methods that serve both services (e.g., `finalize_round`)
- Whether to split populate_tables into smaller private methods within the service
- How to handle the `deep_merge_data!` calls — they stay on the model (data mutation method)
- Error handling and logging preservation
- Whether empty lib modules should be removed or kept as shells

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Extraction Targets
- `lib/tournament_monitor_support.rb` — 1078 lines: report_result (line 183), populate_tables (line 407), update_game_participations (line 5), accumulate_results (line 88), update_ranking (line 275), write_finale_csv_for_upload (line 301), initialize_table_monitors (line 370), do_placement (line 855)
- `lib/tournament_monitor_state.rb` — 522 lines: write_game_result_data (line 7), finalize_game_result (line 45), do_reset_tournament_monitor (line 201), finalize_round (line 120), group_phase_finished? (line 171), finals_finished? (line 183), all_table_monitors_finished? (line 115), table_monitors_ready? (line 190)
- `app/models/tournament_monitor.rb` — 181 lines: AASM block, delegation wrappers

### Existing Phase 13-14 Services (follow patterns)
- `app/services/tournament_monitor/player_group_distributor.rb` — PORO pattern
- `app/services/tournament_monitor/ranking_resolver.rb` — PORO with @tournament_monitor
- `app/services/tournament/table_reservation_service.rb` — ApplicationService pattern
- `app/services/application_service.rb` — Base class

### Characterization Tests (must pass unchanged)
- `test/models/tournament_monitor_t04_test.rb` — Group play flow
- `test/models/tournament_monitor_t06_test.rb` — Finals flow + result pipeline
- `test/models/tournament_monitor_ko_test.rb` — KO flow

### Research Findings
- `.planning/research/PITFALLS.md` — DB lock scope, AASM event sequence, data JSON mutation atomicity, do_reset_tournament_monitor save count

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/services/tournament_monitor/ranking_resolver.rb` — PORO with @tournament_monitor reference pattern
- `app/services/tournament/table_reservation_service.rb` — ApplicationService with external API calls

### Established Patterns
- ApplicationService for side-effect services (DB writes, locks, AASM events)
- `self` → `@tournament_monitor` conversion
- Delegation via thin wrapper methods on model
- `deep_merge_data!` stays on model — services call `@tournament_monitor.deep_merge_data!`

### Integration Points
- `report_result` called by `TournamentMonitorSupport` and controllers
- `populate_tables` called by `do_reset_tournament_monitor` (AASM after_enter callback chain)
- `game.with_lock` in report_result — pessimistic lock must stay inside the service
- AASM events (`start_playing_finals!`, `end_of_tournament!`) called from result pipeline
- `finalize_round` called by both result pipeline and populate_tables — shared dependency

</code_context>

<specifics>
## Specific Ideas

- The DB lock in `report_result` is critical for concurrent TableMonitor result submissions — it must stay inside the service, not be abstracted away
- AASM events must be fired on `@tournament_monitor`, not on the service — this ensures after_enter callbacks execute correctly
- `do_reset_tournament_monitor` is the most complex method — it's the AASM after_enter callback entry point that orchestrates game creation via populate_tables

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 15-high-risk-extractions*
*Context gathered: 2026-04-10*
