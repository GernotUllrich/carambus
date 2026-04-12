# Phase 22: PartyMonitor Extraction - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract service classes from PartyMonitor model (605 lines) to reduce line count significantly. Two service classes are extracted: TablePopulator (placement + table initialization) and ResultProcessor (result pipeline). All Phase 20 characterization tests and all existing tests must remain green after extraction.

</domain>

<decisions>
## Implementation Decisions

### Extraction Scope & Ordering
- **D-01:** Extract two clusters: TablePopulator (~123 LOC: do_placement + initialize_table_monitors + reset_party_monitor) and ResultProcessor (~281 LOC: report_result, finalize_game_result, finalize_round, accumulate_results, update_game_participations). Target ~404 line reduction (~67%).
- **D-02:** Extraction order: TablePopulator first (lower coupling, simpler methods), then ResultProcessor (complex, pessimistic lock). Validates pattern before tackling the hardest part.
- **D-03:** Data lookup methods (all_table_monitors_finished?, get_attribute_by_gname, get_game_plan_attribute_by_gname — ~21 LOC) stay in the model. Too small for a service.

### Service Style & Naming
- **D-04:** All extracted services are POROs (plain Ruby objects) with `initialize(party_monitor)` and multiple public methods. No `.call` convention. Matches `TournamentMonitor::ResultProcessor` and `TournamentMonitor::TablePopulator` patterns exactly.
- **D-05:** `PartyMonitor::` namespace under `app/services/party_monitor/` directory. Matches existing `TournamentMonitor::`, `Tournament::`, `League::` patterns.

### Result Pipeline Complexity
- **D-06:** The pessimistic lock in `report_result` stays in the PartyMonitor model. Inside the lock, the model delegates to `ResultProcessor` for actual data writes. Lock boundary and state transitions stay in the model.
- **D-07:** All AASM transitions and event callbacks remain in PartyMonitor. Services never fire AASM events — they do data work and return. Model owns state machine flow.

### Placement & Init Grouping
- **D-08:** `do_placement` and `initialize_table_monitors` are grouped into one service: `PartyMonitor::TablePopulator`. Both methods deal with table/game assignment. Matches `TournamentMonitor::TablePopulator` pattern.
- **D-09:** `reset_party_monitor` is included in `TablePopulator` as it is part of the table setup lifecycle.

### Delegation Pattern
- **D-10:** PartyMonitor model keeps thin delegation wrappers for all extracted methods. Callers (controllers, reflexes, jobs) continue calling `party_monitor.do_placement` etc. without changes. Same pattern as Phase 21 (League extraction).

### Claude's Discretion
- Internal method decomposition within services
- Test file organization for new service classes
- Whether missing helper methods (next_seqno, write_game_result_data) are implemented as stubs in model or in services
- How to handle instance variable state (@placements, @placement_candidates) during extraction

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Target Model (PRIMARY)
- `app/models/party_monitor.rb` — 605 lines, 8 AASM states, the model being refactored

### Phase 20 Characterization (MUST pass after extraction)
- `.planning/phases/20-characterization/20-CONTEXT.md` — Characterization decisions: D-03 through D-05 cover PartyMonitor
- `test/models/party_monitor_test.rb` — Phase 20 characterization tests (40 tests)

### Existing Extraction Patterns (follow these)
- `app/services/tournament_monitor/result_processor.rb` — TournamentMonitor PORO extraction pattern for result processing
- `app/services/tournament_monitor/table_populator.rb` — TournamentMonitor PORO extraction pattern for placement
- `app/services/tournament_monitor/ranking_resolver.rb` — TournamentMonitor PORO extraction pattern for utilities

### Phase 21 Extraction Patterns (recent, also follow)
- `app/services/league/standings_calculator.rb` — PORO pattern (thin delegation wrappers)
- `app/models/league.rb` — Delegation wrapper examples from Phase 21

### Related Services
- `app/services/region_cc/party_syncer.rb` — 172 LOC, existing party sync service

### Requirements
- `.planning/REQUIREMENTS.md` — EXTR-02 (extract from PartyMonitor)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TournamentMonitor::ResultProcessor` — direct pattern to follow for PartyMonitor::ResultProcessor
- `TournamentMonitor::TablePopulator` — direct pattern to follow for PartyMonitor::TablePopulator
- `ApiProtectorTestOverride` — already in test_helper.rb, needed for PartyMonitor tests
- Phase 21 delegation wrapper pattern — proven approach, reuse in PartyMonitor

### Established Patterns
- PORO services with `initialize(model)` + multiple public methods (TournamentMonitor pattern)
- AASM events stay in model, services do data work only
- Thin delegation wrappers keep model public API stable
- `frozen_string_literal: true` in all Ruby files
- StandardRB linting enforced

### Integration Points
- PartyMonitor called from: `PartyMonitorReflex`, `party_monitors_controller`, jobs
- `report_result` uses pessimistic lock (`game.with_lock`) — lock boundary must stay in model
- `do_placement` interacts with `TableMonitor` instances — coupling must be preserved via delegation
- `initialize_table_monitors` creates TableMonitor records for each table

</code_context>

<specifics>
## Specific Ideas

- Follow the TournamentMonitor extraction pattern from v2.1 exactly — PartyMonitor is the team-competition analog with similar AASM structure but different sequencing (home/guest team rotation).
- The pessimistic lock in `report_result` is critical for race condition prevention — it must not be weakened or restructured during extraction.
- Instance variables (@placements, @placement_candidates) used by do_placement become service-local state in TablePopulator — this is acceptable for algorithm complexity per the TournamentMonitor pattern.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 22-partymonitor-extraction*
*Context gathered: 2026-04-11*
