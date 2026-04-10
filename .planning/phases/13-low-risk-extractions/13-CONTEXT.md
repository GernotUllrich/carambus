# Phase 13: Low-Risk Extractions - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract three small, pure-logic services from Tournament and TournamentMonitor — proving the delegation pattern on the easiest targets before tackling larger extractions in Phases 14-15. No new features or behavior changes.

</domain>

<decisions>
## Implementation Decisions

### Service Class Pattern
- **D-01:** Follow v1.0 extraction pattern: extract to service class, delegate from model via thin wrapper methods.
- **D-02:** RankingCalculator and PlayerGroupDistributor as POROs (like ScoreEngine) — they are pure algorithm classes with no database writes. TableReservationService as ApplicationService — it orchestrates Google Calendar API calls and has side effects.
- **D-03:** Service files go in `app/services/tournament/` and `app/services/tournament_monitor/` (new directories, following existing `app/services/table_monitor/` pattern).

### Extraction Boundaries

#### Tournament::RankingCalculator (TEXT-01)
- **D-04:** Extract `calculate_and_cache_rankings` and `reorder_seedings` methods. The AASM `after_enter` callback on `tournament_seeding_finished` stays on the model — it calls the service.
- **D-05:** The service receives the tournament instance as a parameter (not injected via constructor). Returns the computed rankings hash.

#### Tournament::TableReservationService (TEXT-02)
- **D-06:** Extract `create_table_reservation`, `create_google_calendar_event`, `calculate_start_time`, `calculate_end_time`, `fallback_table_count`, `format_table_list`, `build_event_summary`. The public entry point is `create_table_reservation`.
- **D-07:** `required_tables_count` and `available_tables_with_heaters` stay on the model — they are query methods used by views/controllers beyond just calendar reservation.

#### TournamentMonitor::PlayerGroupDistributor (TMEX-01)
- **D-08:** Extract `distribute_to_group`, `distribute_with_sizes` class methods and `DIST_RULES`, `GROUP_RULES`, `GROUP_SIZES` constants. The `self.ranking` class method stays on TournamentMonitor — it's used beyond distribution.
- **D-09:** TournamentMonitor delegates `distribute_to_group` to `PlayerGroupDistributor.distribute_to_group` with identical signature. TournamentPlan.group_sizes_from also calls this — update that reference too.

### Test Strategy
- **D-10:** New service unit tests go in `test/services/tournament/` and `test/services/tournament_monitor/` (matching existing `test/services/table_monitor/` pattern).
- **D-11:** All existing characterization tests from Phases 11-12 MUST pass without modification after extraction — this is the primary verification gate.
- **D-12:** Each service gets focused unit tests. The existing characterization tests provide integration-level coverage through the delegation wrappers.

### Claude's Discretion
- Exact method signatures for service constructors/call methods
- Whether to use lazy accessor pattern (like ScoreEngine) or direct instantiation
- Internal organization of service files (constants placement, private helpers)
- Whether `frozen_string_literal: true` goes at top of new files (yes — project convention)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Extraction Targets
- `app/models/tournament.rb` lines 886-941 — `calculate_and_cache_rankings`, `reorder_seedings` (RankingCalculator)
- `app/models/tournament.rb` lines 985-1775 — Calendar reservation methods (TableReservationService)
- `app/models/tournament_monitor.rb` lines 135-327 — `ranking`, `distribute_to_group`, `distribute_with_sizes`, constants (PlayerGroupDistributor)
- `app/models/tournament_plan.rb` line 393 — `group_sizes_from` calls `TournamentMonitor.distribute_to_group`

### Existing Service Patterns (follow these)
- `app/services/table_monitor/score_engine.rb` — PORO pattern (lazy accessor, hash wrapper)
- `app/services/table_monitor/game_setup.rb` — ApplicationService pattern (`.call` class method)
- `app/services/table_monitor/result_recorder.rb` — ApplicationService with model reference
- `app/services/application_service.rb` — Base class for ApplicationService pattern

### Existing Service Tests (follow these)
- `test/services/table_monitor/score_engine_test.rb` — PORO service test pattern
- `test/services/table_monitor/game_setup_test.rb` — ApplicationService test pattern

### Characterization Tests (must pass unchanged)
- `test/models/tournament_aasm_test.rb` — Tests calculate_and_cache_rankings via AASM callback
- `test/models/tournament_calendar_test.rb` — Tests create_table_reservation flow
- `test/models/tournament_monitor_t04_test.rb` — Tests distribute_to_group for multiple player counts
- `test/models/tournament_monitor_t06_test.rb` — Tests game creation via populate_tables
- `test/models/tournament_monitor_ko_test.rb` — Tests KO tournament flow

### Research Findings
- `.planning/research/FEATURES.md` — Extraction candidates and dependency analysis
- `.planning/research/ARCHITECTURE.md` — Component boundaries and build order
- `.planning/research/PITFALLS.md` — PaperTrail versioning, data mutation atomicity

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/services/application_service.rb` — Base class with `self.call` pattern
- `app/services/table_monitor/` — 4 existing extracted services as reference implementations
- `test/services/table_monitor/` — Existing service test patterns

### Established Patterns
- v1.0 extractions: PORO for pure data/algorithm services, ApplicationService for side-effect services
- Delegation via thin wrapper methods on the model (e.g., `def score_engine; @score_engine ||= ScoreEngine.new(data); end`)
- `frozen_string_literal: true` in all files
- Constants move with the methods they serve

### Integration Points
- `Tournament#calculate_and_cache_rankings` called by AASM `after_enter` on `tournament_seeding_finished`
- `Tournament#create_table_reservation` called by controller and potentially by jobs
- `TournamentMonitor.distribute_to_group` called by model methods AND by `TournamentPlan.group_sizes_from`
- `TournamentMonitor.ranking` class method used by `player_id_from_ranking` and others — stays on model

</code_context>

<specifics>
## Specific Ideas

No specific requirements — follow established v1.0 patterns. User explicitly chose "You decide" for all gray areas.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 13-low-risk-extractions*
*Context gathered: 2026-04-10*
