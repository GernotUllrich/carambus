# Phase 14: Medium-Risk Extractions - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Extract PublicCcScraper (~700+ lines of scraping pipeline) from Tournament and RankingResolver (~195 lines of regex rule parser) from TournamentMonitor. These are the two largest complexity reductions in this milestone. No new features or behavior changes.

</domain>

<decisions>
## Implementation Decisions

### PublicCcScraper (TEXT-03)
- **D-01:** Extract as ApplicationService in `app/services/tournament/public_cc_scraper.rb`. Service receives tournament instance and writes directly to DB (creates Game/GameParticipation/Seeding records via @tournament associations). Faithful extraction — move code as-is with `self` → `@tournament` conversion.
- **D-02:** Tournament gets a 1-line delegation wrapper for `scrape_single_tournament_public`.
- **D-03:** Claude determines the cleanest extraction boundary — which methods move and which stay. The goal is maximum line reduction while maintaining behavior preservation. All variant methods, parse helpers, and handle_game are candidates for extraction.

### RankingResolver (TMEX-02)
- **D-04:** Extract as PORO in `app/services/tournament_monitor/ranking_resolver.rb`. Service receives the TournamentMonitor instance. Accesses tournament, seedings, data["rankings"] through @tournament_monitor.
- **D-05:** `group_rank` calls `PlayerGroupDistributor.distribute_to_group` directly (the Phase 13 PORO) — not through the TournamentMonitor delegation wrapper. This is cleaner cross-service communication.
- **D-06:** TournamentMonitor gets a delegation wrapper for `player_id_from_ranking`. Private methods (`ko_ranking`, `group_rank`, `random_from_group_ranks`, `rank_from_group_ranks`) move entirely to the service.

### Shared Decisions
- **D-07:** Follow v1.0/Phase 13 extraction pattern: extract → delegate → test.
- **D-08:** Services in `app/services/tournament/` and `app/services/tournament_monitor/` (existing directories from Phase 13).
- **D-09:** New unit tests in `test/services/tournament/` and `test/services/tournament_monitor/`.
- **D-10:** All Phase 11-12 characterization tests MUST pass without modification after extraction.
- **D-11:** VCR/WebMock tests for scraper service reuse the approach from Phase 12 `tournament_scraping_test.rb`.

### Claude's Discretion
- Exact extraction boundary for PublicCcScraper (which helpers move, which stay)
- Whether to split PublicCcScraper into sub-classes (unlikely — faithful extraction is the goal)
- Internal method organization within services
- `self` → `@tournament` / `@tournament_monitor` conversion details
- Error handling preservation (rescue blocks move with their methods)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Extraction Targets
- `app/models/tournament.rb` lines 392-1590 — scrape_single_tournament_public + all parse/variant/handle methods (PublicCcScraper)
- `app/models/tournament_monitor.rb` lines 145-340 — player_id_from_ranking + ko_ranking + group_rank + random_from_group_ranks + rank_from_group_ranks (RankingResolver)

### Phase 13 Services (follow these patterns)
- `app/services/tournament/ranking_calculator.rb` — PORO extraction from Tournament
- `app/services/tournament/table_reservation_service.rb` — ApplicationService extraction from Tournament
- `app/services/tournament_monitor/player_group_distributor.rb` — PORO extraction from TournamentMonitor (called by RankingResolver's group_rank)

### Characterization Tests (must pass unchanged)
- `test/models/tournament_scraping_test.rb` — Scraping pipeline characterization (Phase 12)
- `test/models/tournament_monitor_ko_test.rb` — KO ranking resolution tests
- `test/models/tournament_monitor_t04_test.rb` — Group distribution tests
- `test/models/tournament_monitor_t06_test.rb` — Finals flow tests
- `test/models/tournament_aasm_test.rb` — AASM transition tests

### Research Findings
- `.planning/research/FEATURES.md` — Extraction candidates and dependency analysis
- `.planning/research/ARCHITECTURE.md` — PublicCcScraper identified as ~700 lines, biggest single extraction
- `.planning/research/PITFALLS.md` — VCR cassette risks, data mutation atomicity

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/services/tournament/table_reservation_service.rb` — ApplicationService pattern with @tournament reference
- `app/services/tournament_monitor/player_group_distributor.rb` — PORO called by RankingResolver
- `test/models/tournament_scraping_test.rb` — WebMock stub patterns for scraping tests

### Established Patterns
- ApplicationService for side-effect services (DB writes, HTTP calls)
- PORO for pure algorithm services (no side effects)
- `self` → `@tournament` / `@tournament_monitor` conversion in extracted methods
- Delegation wrapper: 1-line method on model that calls service

### Integration Points
- `scrape_single_tournament_public` called by controllers and potentially jobs
- `player_id_from_ranking` called by `TournamentMonitorSupport#populate_tables` (the most critical caller)
- `group_rank` calls `PlayerGroupDistributor.distribute_to_group` (cross-service dependency)
- `ko_ranking` and `rank_from_group_ranks` access `data["rankings"]` on the TournamentMonitor instance

</code_context>

<specifics>
## Specific Ideas

- PublicCcScraper is the biggest single line reduction in the milestone (~700+ lines)
- RankingResolver depends on PlayerGroupDistributor (Phase 13) — this is the first cross-service dependency between extracted services

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 14-medium-risk-extractions*
*Context gathered: 2026-04-10*
