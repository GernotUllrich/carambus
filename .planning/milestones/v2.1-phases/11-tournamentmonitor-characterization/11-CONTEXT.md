# Phase 11: TournamentMonitor Characterization - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Pin TournamentMonitor behavior (AASM, result pipeline, game sequencing, player distribution, ApiProtector) before any extraction work. TournamentMonitor spans 2099 lines across 3 files: `tournament_monitor.rb` (499), `lib/tournament_monitor_support.rb` (1078), `lib/tournament_monitor_state.rb` (522). No extraction or refactoring in this phase.

</domain>

<decisions>
## Implementation Decisions

### Test Scope Strategy
- **D-01:** Cover three tournament plan types: T04 (round-robin / "jeder gegen jeden"), T06 (with finals round / "mit Finalrunde"), and KO (knockout). These represent the three main flow paths through TournamentMonitor.
- **D-02:** Pin all critical paths for each plan type: AASM state transitions, populate_tables (game sequencing), player distribution (distribute_to_group), result reporting pipeline, and do_reset_tournament_monitor.
- **D-03:** Use fixture plans exported from the production database for T04 and T06 test data. The existing KoTournamentTestHelper creates plans programmatically — T04 and T06 use real plan data instead.

### Test Organization
- **D-04:** Test files live in `test/models/`, not `test/characterization/` — all TournamentMonitor tests in one place alongside the existing `tournament_monitor_ko_test.rb`.
- **D-05:** Split by plan type: `tournament_monitor_t04_test.rb`, `tournament_monitor_t06_test.rb`, extending existing `tournament_monitor_ko_test.rb`. Each file covers all critical paths for that plan type.

### ApiProtector Verification
- **D-06:** Write an explicit save test that creates a local TournamentMonitor (id >= MIN_ID), saves it, and asserts `persisted?`. This test would fail without ApiProtectorTestOverride — proving the override is active for TournamentMonitor.

### Reek Baseline
- **D-07:** Run Reek on all 3 files: `app/models/tournament_monitor.rb`, `lib/tournament_monitor_support.rb`, `lib/tournament_monitor_state.rb`. One-time baseline report saved to `.planning/` for comparison after extraction phases.

### Claude's Discretion
- Exact test method grouping within each plan-type test file
- Which specific AASM transitions and callback chains to prioritize within each plan type
- Whether to create shared test helpers across the three plan-type test files
- How to handle the `cattr_accessor :current_admin` and `cattr_accessor :allow_change_tables` teardown between tests

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Models Under Test
- `app/models/tournament_monitor.rb` — Primary target (499 lines, AASM state machine, distribute_to_group, player_id_from_ranking, ko_ranking)
- `lib/tournament_monitor_support.rb` — Included module (1078 lines, populate_tables, do_reset_tournament_monitor, result reporting pipeline)
- `lib/tournament_monitor_state.rb` — Included module (522 lines, state management, data JSON manipulation)
- `app/models/tournament_plan.rb` — Tournament plan definitions (executor_params JSON schema, plan types: default_plan, ko_plan, dko_plan)

### Related Models
- `app/models/tournament.rb` — Parent model, provides seedings, games, tournament_plan association
- `app/models/table_monitor.rb` — Child model, polymorphic via `tournament_monitor` association
- `app/models/game.rb` — Games created by populate_tables
- `app/models/seeding.rb` — Player seedings used by distribute_to_group and ko_ranking

### Test Infrastructure
- `test/test_helper.rb` — ApiProtectorTestOverride, LocalProtectorTestOverride, test configuration
- `test/models/tournament_monitor_ko_test.rb` — Existing KO test (14 tests, KoTournamentTestHelper)
- `test/support/` — Shared helpers (VCR, scraping, snapshots)

### Research Findings
- `.planning/research/PITFALLS.md` — ApiProtector silent rollback, PaperTrail versioning, cattr_accessor teardown, data JSON mutation atomicity
- `.planning/research/FEATURES.md` — Responsibility clusters, extraction candidates, test coverage gaps
- `.planning/research/ARCHITECTURE.md` — Component boundaries, lib file scope (2099 lines total), integration points

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/models/tournament_monitor_ko_test.rb`: Existing KO test pattern with `KoTournamentTestHelper` — adapt for T04/T06 helpers
- `test/test_helper.rb`: ApiProtectorTestOverride already patches ApiProtector — verify it covers TournamentMonitor
- `TournamentPlan.default_plan(n)`: Programmatically creates round-robin plans — may be useful for T04 test data generation if fixtures insufficient
- `TournamentMonitor::DIST_RULES`, `GROUP_RULES`, `GROUP_SIZES`: Constants defining player distribution — testable inputs

### Established Patterns
- Minitest with `test "description"` syntax, `fixtures :all`, `use_transactional_tests = true`
- `setup` block creates tournament with plan + seedings, calls `initialize_tournament_monitor`
- `teardown` block cleans up created records
- Private methods tested via `send(:method_name)`
- `cattr_accessor` class-level state must be reset in teardown to avoid test pollution

### Integration Points
- `TournamentMonitor#do_reset_tournament_monitor` — AASM after_enter callback, creates games via populate_tables
- `TournamentMonitor#broadcast_status_update` → `TournamentStatusUpdateJob` — after_update_commit when state changes
- `TournamentMonitor.distribute_to_group` — class method called by model and by TournamentPlan.group_sizes_from
- `deep_merge_data!` — non-saving mutation of `data` JSON field, used extensively in result reporting

</code_context>

<specifics>
## Specific Ideas

- T04 is "jeder gegen jeden" (round-robin / everyone plays everyone) — the simplest group-play format
- T06 is "mit Finalrunde" (with finals round) — group play followed by a finals stage, exercises the full AASM path including `start_playing_groups` → `start_playing_finals` transitions
- Fixture plans should come from the production database to ensure real-world executor_params JSON structure
- KO test already exists with 14 tests — extend rather than rewrite

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 11-tournamentmonitor-characterization*
*Context gathered: 2026-04-10*
