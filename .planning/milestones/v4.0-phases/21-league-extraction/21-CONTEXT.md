# Phase 21: League Extraction - Context

**Gathered:** 2026-04-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract service classes from League model (2221 lines) to reduce line count significantly. All three characterized behavior clusters (standings, game plan reconstruction, scraping) are extracted into focused service classes. All Phase 20 characterization tests and all 751+ existing tests must remain green after extraction.

</domain>

<decisions>
## Implementation Decisions

### Extraction Scope & Ordering
- **D-01:** Extract all three characterized clusters plus BBV scraping. Target ~1100 line reduction (50%).
- **D-02:** Extraction order: standings (easiest, pure calculation) -> game plan reconstruction (moderate, DB writes) -> ClubCloud scraping (hardest, network I/O + bulk writes) -> BBV scraping (small, similar to ClubCloud).
- **D-03:** BBV scraping is extracted alongside ClubCloud scraping in the same phase, not deferred.

### Service Naming & Location
- **D-04:** All extracted services use `League::` namespace under `app/services/league/` directory. Matches existing `Tournament::`, `TournamentMonitor::`, `TableMonitor::` patterns.
- **D-05:** `League::StandingsCalculator` is a PORO (plain Ruby object) — `initialize(league)` with instance methods. No `.call` convention. Pure calculation, no side effects.
- **D-06:** `League::GamePlanReconstructor` inherits from `ApplicationService` — uses `.call(kwargs)` pattern since it writes to database (GamePlan records).
- **D-07:** `League::ClubCloudScraper` inherits from `ApplicationService` — orchestrates all ClubCloud league scraping.
- **D-08:** `League::BbvScraper` is a separate `ApplicationService` — BBV is a different data source with different HTML structure, deserves its own service class.

### Scraping Mega-Method Strategy
- **D-09:** The 821-line `scrape_single_league_from_cc` is extracted into `League::ClubCloudScraper` as a single service class. The method is broken into well-named private methods internally (team parsing, game parsing, detail fetching) but stays in one file. No sub-service split unless the result is still unmanageable.
- **D-10:** BBV scraping methods (`scrape_bbv_leagues`, `scrape_single_bbv_league`, `scrape_bbv_league_teams`) go into `League::BbvScraper`, separate from ClubCloudScraper.

### Delegation Pattern
- **D-11:** League model keeps thin one-liner wrapper methods that delegate to extracted services. Example: `def standings_table_karambol; League::StandingsCalculator.new(self).karambol; end`. No caller changes required — controllers, views, jobs continue calling `league.standings_table_karambol`.
- **D-12:** Wrapper methods are not marked as deprecated — they are the permanent public API. The service classes are the implementation.

### Claude's Discretion
- Internal method decomposition within `League::ClubCloudScraper` (how to split the 821-line method into private methods)
- Test file organization for new service classes
- Whether `League::GamePlanReconstructor` uses a single `.call` entry point or dispatches by operation type
- GamePlan utility methods (find_leagues_with_same_gameplan, find_or_create_shared_gameplan, delete_game_plans_for_season) — include in GamePlanReconstructor or leave in model

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Target Model (PRIMARY)
- `app/models/league.rb` — 2221 lines, the model being refactored. Read to understand all method clusters.

### Phase 20 Characterization (MUST pass after extraction)
- `.planning/phases/20-characterization/20-CONTEXT.md` — Characterization decisions: what was tested and how
- `test/models/league_test.rb` — Existing tests including Phase 20 characterization tests

### Existing Extraction Patterns (follow these)
- `app/services/tournament/ranking_calculator.rb` — Tournament extraction pattern (PORO calculator)
- `app/services/tournament_monitor/result_processor.rb` — TournamentMonitor extraction pattern (ApplicationService)
- `app/services/table_monitor/result_recorder.rb` — TableMonitor extraction pattern (ApplicationService)
- `app/services/application_service.rb` — Base service class with `.call` convention

### Related Services (already extracted, for context)
- `app/services/region_cc/league_syncer.rb` — 683 LOC, existing league sync service
- `app/services/region_cc/party_syncer.rb` — 172 LOC, existing party sync service

### Requirements
- `.planning/REQUIREMENTS.md` — EXTR-01 (extract from League), EXTR-03 (characterization tests pass), EXTR-04 (all tests green)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ApplicationService` base class — `.call(kwargs)` pattern for service classes with DB operations
- `League::` namespace directory at `app/services/league/` — needs to be created (doesn't exist yet)
- Existing `Tournament::RankingCalculator` — PORO pattern to follow for standings extraction
- `TournamentMonitor::ResultProcessor` — ApplicationService pattern to follow for scraping/game plan extraction

### Established Patterns
- Namespaced services under `app/services/{model_name}/` — Tournament, TournamentMonitor, TableMonitor all follow this
- PORO for pure calculation (no DB writes), ApplicationService for operations with side effects
- Thin delegation wrappers in models keep public API stable
- `frozen_string_literal: true` in all Ruby files
- StandardRB linting enforced

### Integration Points
- League model called from: controllers (leagues_controller), jobs, views, region_cc services
- `scrape_single_league_from_cc` called from `scrape_leagues_from_cc` and `scrape_league_optimized` — both also being extracted
- Standings methods called from views for league display
- Game plan reconstruction called from League model methods and potentially from controllers

</code_context>

<specifics>
## Specific Ideas

- Follow the exact extraction pattern from TournamentMonitor (Phase 13-14 in v2.1) — it was successful and the codebase already demonstrates the pattern.
- The 821-line `scrape_single_league_from_cc` should be internally organized into clear private methods (e.g., `parse_teams`, `parse_games`, `fetch_details`) but kept in one file initially.
- Each extracted service must have its own test file under `test/services/league/`.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 21-league-extraction*
*Context gathered: 2026-04-11*
