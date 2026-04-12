# Phase 20: Characterization - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Pin all critical paths in League, PartyMonitor, Party, and LeagueTeam with characterization tests before any extraction work begins. This gates Phases 21-22 (extraction). No code changes to production models — tests only.

</domain>

<decisions>
## Implementation Decisions

### League Characterization (CHAR-01, CHAR-02)
- **D-01:** League has NO AASM state machine. CHAR-01 (originally "AASM transitions") should be reinterpreted as "League core behavior pinned by tests" — associations, configuration, computed properties.
- **D-02:** Three behavior clusters need characterization:
  1. **Standings tables** (~170 LOC): `standings_table_karambol`, `standings_table_snooker`, `standings_table_pool` — verify correct ranking output for known input
  2. **Game plan reconstruction** (~240 LOC): `reconstruct_game_plan_from_existing_data`, `analyze_game_plan_structure`, `reconstruct_game_plans_for_season` — 3 existing tests exist, expand coverage
  3. **Scraping pipeline** (~400 LOC): `scrape_leagues_from_cc`, `scrape_league_optimized`, `scrape_league_teams_optimized`, `scrape_party_games_optimized` — VCR cassettes needed (follows v1.0 RegionCc pattern)

### PartyMonitor Characterization (CHAR-03, CHAR-04)
- **D-03:** Full characterization of all 8 AASM states: `seeding_mode` → `table_definition_mode` → `next_round_seeding_mode` → `ready_for_next_round` → `playing_round` → `round_result_checking_mode` → `party_result_checking_mode` → `closed`
- **D-04:** Critical paths to pin:
  1. `do_placement` — complex game-to-table assignment with TableMonitor interaction
  2. `report_result` — pessimistic lock preventing race conditions during result write + state transition
  3. `initialize_table_monitors` — table monitor setup
  4. Round management — `current_round`, `incr/decr_current_round`, `next_seqno`
  5. Result pipeline — `finalize_game_result`, `finalize_round`, `accumulate_results`, `update_game_participations`
- **D-05:** PartyMonitor includes `ApiProtector` (forbids API access) — tests need `ApiProtectorTestOverride` (already in test_helper.rb from v2.0)

### Party Characterization (CHAR-05)
- **D-06:** Party has no AASM. Pin: associations (polymorphic games, league_team_a/b, seedings), computed properties (`name`, `party_nr`, `intermediate_result`), and boolean flags (`manual_assignment`, `continuous_placements`, `allow_follow_up`)

### LeagueTeam Characterization (CHAR-06)
- **D-07:** LeagueTeam is 63 lines. Pin: associations (league, club, parties_a/b for home/guest), seedings linkage, `cc_id_link`

### Claude's Discretion
- Test file organization (one file per model vs by behavior cluster)
- VCR cassette strategy for League scraping tests
- Fixture design for PartyMonitor AASM tests (production fixture plans vs programmatic)
- How many test methods per behavior cluster
- Whether to include Reek baseline measurement (follows v1.0 pattern)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Target Models (PRIMARY — these are what we're testing)
- `app/models/league.rb` — 2219 lines, no AASM, standings + game plan + scraping clusters
- `app/models/party_monitor.rb` — 605 lines, 8 AASM states, do_placement, report_result with pessimistic lock
- `app/models/party.rb` — 216 lines, associations, boolean flags, no AASM
- `app/models/league_team.rb` — 63 lines, associations, home/guest via parties_a/b

### Existing Tests
- `test/models/league_test.rb` — 3 existing tests for reconstruct_game_plan_from_existing_data (expand, don't duplicate)

### Related Services (already extracted in v1.0)
- `app/services/region_cc/league_syncer.rb` — 683 LOC, sync_leagues/teams/plan/players
- `app/services/region_cc/party_syncer.rb` — 172 LOC, sync_parties/party_games

### Controllers (for context, not testing in Phase 20)
- `app/controllers/parties_controller.rb`
- `app/controllers/party_monitors_controller.rb`
- `app/controllers/leagues_controller.rb`
- `app/controllers/league_teams_controller.rb`

### v2.1 Characterization Patterns (reference)
- `.planning/milestones/v2.1-phases/11-tm-characterization/` — TournamentMonitor characterization pattern
- `.planning/milestones/v2.1-phases/12-tournament-characterization/` — Tournament characterization pattern

### Test Infrastructure
- `test/test_helper.rb` — ApiProtectorTestOverride, LocalProtectorTestOverride
- `test/support/scraping_helpers.rb` — VCR cassette helpers
- `test/fixtures/` — existing fixtures for leagues, parties, etc.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ApiProtectorTestOverride` — already in test_helper.rb, needed for PartyMonitor tests
- `LocalProtectorTestOverride` — already in test_helper.rb
- VCR cassette infrastructure — established in v1.0 for RegionCc, reuse for League scraping
- `ScrapingHelpers` and `SnapshotHelpers` from test/support/

### Established Patterns
- v2.1 characterization pattern: fixtures with production data → AASM transition tests → side effect assertions
- T04/T06 test structure: fixture plans with real executor_params JSON
- Reek baseline measurement before extraction (optional, from v1.0)

### Integration Points
- PartyMonitor has `has_many :table_monitors` — test setup needs TableMonitor fixtures
- League scraping tests need VCR cassettes (network calls to ClubCloud)
- Party `intermediate_result` is partially stubbed — may need careful testing approach
- `report_result` pessimistic lock needs DB-level testing (not just mock)

</code_context>

<specifics>
## Specific Ideas

- PartyMonitor is the team-competition analog of TournamentMonitor — similar AASM structure but very different sequencing (home/guest team rotation, not bracket/group). The characterization approach should follow v2.1 Phase 11-12 patterns.
- League has no AASM unlike Tournament — the characterization focuses on method output correctness (standings, game plans) rather than state machine coverage.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 20-characterization*
*Context gathered: 2026-04-11*
