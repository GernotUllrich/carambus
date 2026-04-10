# Feature Research

**Domain:** Tournament + TournamentMonitor refactoring (v2.1 milestone)
**Researched:** 2026-04-10
**Confidence:** HIGH — direct codebase analysis, no external sources needed

---

## What This Document Maps

This is a **refactoring work-item map**, not a product feature map. "Table stakes" means work that must happen for the milestone to succeed. "Differentiators" means work that makes the result meaningfully better. "Anti-features" means tempting scope that should be explicitly rejected.

---

## Tournament Model: Responsibility Clusters

Tournament (1775 lines) contains seven distinct responsibility areas. Not all are extraction candidates.

**Cluster 1 — Core AR model (keep in model):** Schema, associations, scopes, validations, constants, `data` serialization, `before_save` data migration. Lines ~60–240. Legitimate model code.

**Cluster 2 — TournamentLocal delegation (keep in model):** The `define_method` loop (~lines 239–269) that reads from `tournament_local` for global records (id < MIN_ID) and writes back on update. Tightly coupled to dual-identity behavior. Not extractable without major interface changes.

**Cluster 3 — AASM state machine (keep in model):** States: `new_tournament`, `accreditation_finished`, `tournament_seeding_finished`, `tournament_mode_defined`, `tournament_started_waiting_for_monitors`, `tournament_started`, `tournament_finished`, `results_published`, `closed`. Callbacks into `reset_tournament` and `calculate_and_cache_rankings`. Standard model code.

**Cluster 4 — ClubCloud scraping (EXTRACT → `TournamentCcScraper`):** `scrape_single_tournament_public` (~lines 392–810): 400-line method that fetches tournament details, participant list, game results, and rankings from ClubCloud HTML. Contains 9 distinct parse-variant private methods. Highest-value extraction candidate. Precedented by `CuescoScraper` and `UmbScraperV2`.

**Cluster 5 — Scraped game creation (EXTRACT with `TournamentCcScraper`):** `handle_game`, `parse_table_tr`, and all `variant0..variant8` parse helpers (~lines 1061–1349). Pure HTML row → `Game`/`GameParticipation` data transformation. These belong with the scraper, not the model.

**Cluster 6 — Ranking calculation (EXTRACT → `TournamentRankingCalculator`):** `calculate_and_cache_rankings` (~lines 886–932): loads `PlayerRanking` across 3 seasons, computes effective GD, stores in `data['player_rankings']`. Pure computation with no state side-effects beyond `save!`. Clean extraction target.

**Cluster 7 — Google Calendar reservation (EXTRACT → `TournamentCalendarReservation`):** `create_table_reservation`, `available_tables_with_heaters`, `required_tables_count`, `format_table_list`, `build_event_summary`, `calculate_start_time`, `calculate_end_time`, `create_google_calendar_event` (~lines 980–1774): self-contained feature, already publicly/privately split. Existing tests in `tournament_auto_reserve_test.rb` already document behavior.

---

## TournamentMonitor Model: Responsibility Clusters

TournamentMonitor (499 lines in model + 1078 lines in `lib/tournament_monitor_support.rb` + 522 lines in `lib/tournament_monitor_state.rb`) is already partially decomposed into lib modules. Total footprint: ~2100 lines.

**Cluster 1 — Core AR model + AASM (keep in model):** States: `new_tournament_monitor`, `playing_groups`, `playing_finals`, `tournament_finished`, `party_result_reporting_mode`, `closed`. State machine, `broadcast_status_update`, `log_state_change`. Lines 1–99.

**Cluster 2 — Round counter (keep in model):** `current_round`, `current_round!`, `incr_current_round!`, `decr_current_round!`. Simple data accessors on the `data` JSON blob. Too small to extract.

**Cluster 3 — Player distribution / group seeding (EXTRACT → `PlayerDistributor`):** `self.distribute_to_group`, `self.distribute_with_sizes`, `DIST_RULES`, `GROUP_RULES`, `GROUP_SIZES` constants (~lines 170–327). Pure algorithms with no AR dependencies — take player arrays, return group hashes. Highest testability gain for effort.

**Cluster 4 — Ranking rule resolution (EXTRACT → `RankingRuleResolver`):** `player_id_from_ranking`, `ko_ranking`, `group_rank`, `random_from_group_ranks`, `rank_from_group_ranks` (~lines 145–487 private section). Complex regex-based rule string parser resolving placement rules like `(g1.rk4 + g2.rk4).rk2` to player IDs via `data["rankings"]`. Most complex algorithm in the model — untested inline, valuable when isolated.

**Cluster 5 — Result accumulation (in `TournamentMonitorSupport` — evaluate extraction):** `accumulate_results`, `add_result_to`, `update_game_participations`, `update_game_participations_for_game`. Already in a module; evaluate as `ResultAccumulator` service following `ScoreEngine` precedent from v1.0.

**Cluster 6 — Game lifecycle (in `TournamentMonitorState` — evaluate extraction):** `write_game_result_data`, `finalize_game_result`, `report_result`, `finalize_round`, `group_phase_finished?`, `finals_finished?`, `all_table_monitors_finished?`. The main game-result pipeline. Already in a lib module; evaluate whether each pipeline stage warrants its own service class.

---

## Feature Landscape

### Table Stakes (Must Have for Milestone)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Characterization tests for Tournament | Must document behavior before touching anything; gate for all extractions | HIGH | 1775 lines, 7 clusters; VCR cassettes needed for `scrape_single_tournament_public` |
| Characterization tests for TournamentMonitor | Same — model + 2 lib modules = ~2100 lines; must cover group, KO, finals paths | HIGH | `tournament_monitor_ko_test.rb` partially covers KO path — extend, do not duplicate |
| Extract `TournamentCcScraper` | Biggest single complexity reduction in Tournament model; removes 400+ lines + 9 variant helpers | HIGH | Follows `CuescoScraper` / `ClubCloudClient` patterns; VCR cassettes required |
| Extract `PlayerDistributor` | Pure algorithm, no AR dependencies, highest testability gain per effort | MEDIUM | `DIST_RULES`, `GROUP_RULES`, `GROUP_SIZES` constants move with it; `self.ranking` may accompany |
| Extract `RankingRuleResolver` | Densest algorithm in TournamentMonitor, regex rule strings, currently untested in isolation | HIGH | Careful characterization first; depends on `data["rankings"]` structure being documented |
| Extract `TournamentRankingCalculator` | Self-contained, ~47 lines, already side-effect-clean | LOW | Straightforward; existing behavior documented by char tests |
| Extract `TournamentCalendarReservation` | Already isolated with public/private split, existing tests provide coverage | LOW | ~90 lines; uses `GoogleCalendarService` |
| Controller tests: `TournamentsController` | 1047-line controller with 20+ actions, zero tests currently | HIGH | Focus on `reset`, `start`, `finish_seeding`, `define_participants`, `select_modus`, `reload_from_cc` |
| Controller tests: `TournamentMonitorsController` | 214-line controller with game pipeline actions, zero tests | MEDIUM | Focus on `update_games`, `start_round_games`, `switch_players` |
| Job tests: `TournamentStatusUpdateJob` | Broadcasts live tournament status via CableReady; 101 lines | MEDIUM | Test broadcast output, not just invocation; test renderer fallback path |
| Job tests: `TournamentMonitorUpdateResultsJob` | 32 lines; exercises the async game-result path | LOW | Simple but covers the only async route into `report_result` |

### Differentiators (Make the Result Better, Not Just Done)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Reflex tests: `TournamentReflex` | 244-line reflex handles all live attribute updates; untested; `ATTRIBUTE_METHODS` codegen + seeding mutations | MEDIUM | Tests the metaprogrammed setters and `change_seeding`, `sort_by_ranking`, `sort_by_handicap` |
| `ResultAccumulator` service extraction | `accumulate_results` + `add_result_to` in support module; isolation makes the ranking accumulation path unit-testable | MEDIUM | Follows `ScoreEngine` pattern from v1.0 |
| Move `TournamentMonitorSupport`/`State` from `lib/` to `app/models/concerns/` | `lib/` is not always autoloaded consistently; concerns are the Rails convention for AR mixins | LOW | Low-risk rename + move; improves discoverability; no behavior change |
| Channel tests: `TournamentChannel`, `TournamentMonitorChannel` | Both are tiny (17/19 lines) but verify subscription correctness | LOW | Only meaningful once ActionCable test infrastructure is confirmed in place |
| Reek quality measurement before/after extraction | Proves refactoring reduced complexity, not just line count | LOW | Already part of v1.0 playbook — run before and after each extraction |

### Anti-Features (Explicitly Out of Scope)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Refactor `TournamentsController` (1047 lines) | Large controller is an obvious target | Controller refactoring is a different milestone; touching it during model extraction risks cascading view/partial changes | Write tests that pin current behavior; refactor in a dedicated future milestone |
| Extract `TournamentLocal` delegation logic | The `define_method` loop is messy | Tightly coupled to the dual-identity (global vs local) model contract; extraction requires changing call sites across the entire codebase | Document in characterization tests, leave in place |
| Add new tournament features | Tempting when working deep in the model | "No new features" is the project constraint (PROJECT.md) | File issues for later milestones |
| Consolidate `UmbScraperV2` + scraper variations | Real inconsistency | Explicitly Out of Scope in PROJECT.md ("Scraper consolidation (UmbScraper v1/v2) — separate concern") | Future milestone |
| League model refactoring (2219 lines) | Same God-object pattern | Explicitly Out of Scope in PROJECT.md ("League model refactoring — tackle in future milestone") | Future milestone |
| System/integration browser tests for scraping | Coverage seems good | System tests require browser + full stack; VCR cassettes are the right tool for scraper validation | Integration tests with VCR cassettes are sufficient |
| Changing public method signatures | Caller cleanup seems cleaner | Reflexes, jobs, and controllers call model methods directly; signature changes require a coordinated sweep | Preserve all public method names; delegate from model to extracted services |

---

## Feature Dependencies

```
Characterization tests (Tournament)
    └── required before ──> TournamentCcScraper extraction
    └── required before ──> TournamentRankingCalculator extraction
    └── required before ──> TournamentCalendarReservation extraction

Characterization tests (TournamentMonitor)
    └── required before ──> PlayerDistributor extraction
    └── required before ──> RankingRuleResolver extraction
    └── required before ──> ResultAccumulator extraction (if pursued)

TournamentCcScraper extraction
    └── includes ──> All variant helpers (variant0..variant8, handle_game, parse_table_tr)
    └── requires ──> VCR cassettes for scrape paths (details, participants, results, rankings)

RankingRuleResolver extraction
    └── depends on ──> data["rankings"] structure documented by char tests
    └── calls ──> PlayerDistributor.distribute_to_group (group_rank method)

PlayerDistributor extraction
    └── self-contained ──> No AR dependencies; pure algorithm
    └── must export ──> class methods: .distribute_to_group, .distribute_with_sizes, .ranking
```

### Dependency Notes

- **Characterization tests before any extraction** is the project's test-first constraint. Every extraction is gated by tests documenting the behavior being preserved.
- **`TournamentCcScraper` owns all variant helpers** — `handle_game`, `parse_table_tr`, and all `variant*` methods should move as a unit. Splitting them creates an incoherent model with parse logic split across two files.
- **`PlayerDistributor` is the best early win** — no AR dependencies, extractable immediately after characterization tests, useful as a proof-of-pattern before tackling the harder extractions.
- **`RankingRuleResolver` depends on `PlayerDistributor`** — `group_rank` calls `distribute_to_group`. After extraction, `RankingRuleResolver` must call `PlayerDistributor.distribute_to_group` explicitly.

---

## MVP Definition

### Phase 1: Characterization (must come first, gates everything)

- [ ] Characterization tests for Tournament — all 7 clusters documented, VCR cassettes recorded for scrape paths
- [ ] Characterization tests for TournamentMonitor — group/KO/finals paths, player distribution, ranking resolution
- [ ] Verify existing `tournament_monitor_ko_test.rb` passes, identify gaps in coverage

### Phase 2: Clean Extractions (independent, low-risk)

- [ ] Extract `PlayerDistributor` — pure algorithm, best testability gain/risk ratio; move with constants
- [ ] Extract `TournamentRankingCalculator` — already isolated computation, ~47 lines
- [ ] Extract `TournamentCalendarReservation` — already isolated, existing tests provide coverage

### Phase 3: Complex Extractions (require Phase 1 char tests)

- [ ] Extract `TournamentCcScraper` with all variant helpers — VCR cassettes required
- [ ] Extract `RankingRuleResolver` — most complex algorithm, highest regression risk

### Phase 4: Controller / Job / Reflex Coverage

- [ ] `TournamentsController` tests — 20+ actions; pin current behavior before future controller work
- [ ] `TournamentMonitorsController` tests — focus on `update_games`, `start_round_games`
- [ ] `TournamentStatusUpdateJob` tests — verify CableReady broadcast output and renderer fallback
- [ ] `TournamentReflex` tests — verify `ATTRIBUTE_METHODS` metaprogramming, seeding mutations

---

## Feature Prioritization Matrix

| Work Item | Correctness Value | Implementation Cost | Priority |
|-----------|-------------------|---------------------|----------|
| Characterization tests (Tournament) | HIGH — blocks all extractions | HIGH | P1 |
| Characterization tests (TournamentMonitor) | HIGH — blocks all extractions | HIGH | P1 |
| `PlayerDistributor` extraction | HIGH — most testable algorithm, pure | LOW | P1 |
| `TournamentRankingCalculator` extraction | MEDIUM — isolated computation | LOW | P1 |
| `TournamentCalendarReservation` extraction | MEDIUM — already isolated | LOW | P1 |
| `TournamentCcScraper` extraction | HIGH — biggest complexity reduction | HIGH | P2 |
| `RankingRuleResolver` extraction | HIGH — removes regex soup from model | HIGH | P2 |
| `TournamentsController` tests | HIGH — 1047-line controller untested | HIGH | P2 |
| `TournamentMonitorsController` tests | MEDIUM — game pipeline actions | MEDIUM | P2 |
| `TournamentStatusUpdateJob` tests | MEDIUM — async broadcast path | MEDIUM | P2 |
| `TournamentReflex` tests | MEDIUM — live attribute updates | MEDIUM | P3 |
| `ResultAccumulator` extraction | MEDIUM — already in module | MEDIUM | P3 |
| Move lib modules to concerns | LOW — cosmetic Rails convention | LOW | P3 |
| Channel tests | LOW — tiny files | LOW | P3 |

---

## Test Coverage Gap Analysis

### No tests exist for:

- `TournamentsController` (1047 lines, 20+ actions) — highest priority gap in the project
- `TournamentMonitorsController` (214 lines)
- `TournamentStatusUpdateJob` (101 lines)
- `TournamentReflex` (244 lines)
- `TournamentChannel` / `TournamentMonitorChannel` (17/19 lines each)
- `TournamentMonitorUpdateResultsJob` (32 lines)
- `scrape_single_tournament_public` in Tournament model (400+ lines, 9 variant helpers)
- `TournamentMonitorState#report_result` pipeline (core game-result flow)

### Partial tests exist for:

- `tournament_test.rb` — 3 tests: LocalProtector, data field, PaperTrail; not characterization-level
- `tournament_monitor_ko_test.rb` — KO path, `ko_ranking`, `distribute_to_group`; a starting point
- `tournament_search_test.rb` — search behavior
- `tournament_auto_reserve_test.rb` — Google Calendar reservation; provides characterization for `TournamentCalendarReservation`

### Already well-tested (no new work needed here):

- `TableMonitor` and its 4 extracted services (v1.0 complete)
- `RegionCc` and its 10 extracted services (v1.0 complete)

---

## Sources

- Direct analysis of `app/models/tournament.rb` (1775 lines)
- Direct analysis of `app/models/tournament_monitor.rb` (499 lines)
- Direct analysis of `lib/tournament_monitor_support.rb` (1078 lines)
- Direct analysis of `lib/tournament_monitor_state.rb` (522 lines)
- Direct analysis of `app/controllers/tournaments_controller.rb` (1047 lines)
- Direct analysis of `app/controllers/tournament_monitors_controller.rb` (214 lines)
- Direct analysis of `app/reflexes/tournament_reflex.rb` (244 lines)
- Direct analysis of `app/jobs/tournament_status_update_job.rb` (101 lines)
- Direct analysis of existing test files in `test/models/`
- `.planning/PROJECT.md` for constraints and prior decisions

---

*Feature research for: Tournament + TournamentMonitor refactoring (v2.1)*
*Researched: 2026-04-10*
