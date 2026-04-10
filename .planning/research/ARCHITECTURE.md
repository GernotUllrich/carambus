# Architecture Research: Tournament & TournamentMonitor Refactoring (v2.1)

**Domain:** Rails god-model extraction — live tournament orchestration on dual-server topology
**Researched:** 2026-04-10
**Confidence:** HIGH (direct codebase inspection, all conclusions from production code)

---

## System Context: Two-Server Topology

The most important architectural fact for this milestone: Tournament and TournamentMonitor serve **different servers** with different responsibilities.

```
API Server (central)                    Local Server (venue)
---------------------                   ----------------------
Tournament model                        TournamentMonitor model
  - 1775 lines                            - 499 lines
  - Lives here permanently                - Orchestrates live play
  - Sync target (PaperTrail)              - Delegates to TableMonitors
  - Scraping, seedings, state machine     - include TournamentMonitorSupport (lib, 1078 lines)
  - LocalProtector prevents local edits   - include TournamentMonitorState (lib, 522 lines)
  - ApiProtector prevents API-side edits  - ApiProtector prevents API-side edits

TournamentsController                   TournamentMonitorsController
TournamentChannel                       TournamentMonitorChannel (rejects on API server)
TournamentReflex                        (no separate reflex — controller-driven)
TournamentStatusUpdateJob               TournamentMonitorUpdateResultsJob
```

The real line count of TournamentMonitor logic is not 499 — it is **499 + 1078 + 522 = 2099 lines** across three files. The lib modules are included at load time and behave as if inlined. Any extraction plan must account for all three files.

---

## Dependency Map: What Touches Tournament

### Inbound callers of Tournament (things that call Tournament methods)

| Caller | Methods Used | Location |
|--------|-------------|----------|
| TournamentsController | AASM events: `reset_tmt_monitor!`, `forced_reset_tournament_monitor!`, `finish_seeding!`, `finish_mode_selection!`, `signal_tournament_monitors_ready!` | app/controllers/tournaments_controller.rb |
| TournamentsController | `initialize_tournament_monitor`, `calculate_and_cache_rankings`, `order_by_ranking_or_handicap` | app/controllers/tournaments_controller.rb |
| TournamentReflex | `tournament.send("#{attribute}=", val)`, `tournament.save!` — attribute delegation to TournamentLocal | app/reflexes/tournament_reflex.rb |
| TournamentReflex | `change_party_seeding`, `change_seeding`, `change_no_show`, `change_position`, `sort_by_ranking`, `sort_by_handicap` | app/reflexes/tournament_reflex.rb |
| TournamentStatusUpdateJob | `tournament.tournament_monitor`, `tournament.state`, `tournament.tournament_started` | app/jobs/tournament_status_update_job.rb |
| TournamentMonitorState (lib) | `tournament.finish_tournament!`, `tournament.have_results_published!`, `tournament.tournament_plan`, `tournament.games`, `tournament.manual_assignment`, `tournament.auto_upload_to_cc?`, `tournament.seedings`, `tournament.tournament_cc` | lib/tournament_monitor_state.rb |
| TournamentMonitorSupport (lib) | `tournament.seedings`, `tournament.games`, `tournament.data`, `tournament.tournament_plan`, `tournament.innings_goal`, `tournament.handicap_tournier?`, `tournament.gd_has_prio?`, `tournament.continuous_placements`, `tournament.manual_assignment` | lib/tournament_monitor_support.rb |
| RegionCc::TournamentSyncer | `tournament.save`, `tournament.update` | app/services/region_cc/tournament_syncer.rb |
| TournamentMonitor | `tournament.games.where(...).destroy_all`, `tournament.seedings`, `tournament.data["table_ids"]` | app/models/tournament_monitor.rb |

### Outbound dependencies of Tournament (things Tournament calls)

| Dependency | How Used |
|-----------|----------|
| TournamentMonitor | `tournament_monitor.destroy`, `create_tournament_monitor(...)`, `tournament_monitor.table_monitors` |
| Game | `games.where("games.id >= #{MIN_ID}").destroy_all` |
| Seeding | `seedings.where(...).destroy_all`, `seedings.create`, `seedings.order` |
| TableMonitorJob | `TableMonitorJob.perform_later(tm.id, "teaser")` — in `reset_tournament` |
| TournamentStatusUpdateJob | Triggered by `after_update_commit :broadcast_status_update, if: :saved_change_to_state?` on TournamentMonitor |
| GoogleCalendarService | `create_table_reservation` → `create_google_calendar_event` |
| Setting | `Setting.upload_game_to_cc(table_monitor)` — called from TournamentMonitorState |
| Region, Season, Discipline, Location, Player, Club, TournamentPlan | Associations and lookups used in scraping and seeding |
| Nokogiri, Net::HTTP | Used in `scrape_single_tournament_public` (large inline scraper) |

---

## Responsibility Clusters in Tournament (1775 lines)

The model currently holds seven distinct responsibility clusters:

### Cluster 1: Core Model Backbone (~150 lines)
Schema, associations, constants, serialization, scopes, `before_save` callback, AASM state machine definition. This stays in the model.

### Cluster 2: AASM Event Callbacks (~180 lines)
`reset_tournament`, `calculate_and_cache_rankings`, `initialize_tournament_monitor`, `before_all_events`, `admin_can_reset_tournament?`, `tournament_not_yet_started`, `tournament_started`. These are called by AASM — they must remain on the model or be delegated while preserving the AASM contract.

### Cluster 3: TournamentLocal Attribute Delegation (~80 lines)
The `define_method` loop for `%i[timeouts timeout gd_has_prio ...]` that proxies reads/writes through `TournamentLocal` for global records (id < MIN_ID). This is intrinsic to the model's data layer and stays.

### Cluster 4: Searchable Integration (~60 lines)
`text_search_sql`, `search_joins`, `search_distinct?`, `cascading_filters`, `field_examples`. These are callbacks for the `Searchable` concern. They stay in the model.

### Cluster 5: Public CC Scraper (~700 lines)
`scrape_single_tournament_public` (the main method), `parse_table_tr`, `parse_table_td`, `handle_game`, `variant0`–`variant8`, `result_with_*`, `fix_location_from_location_text`. This is the largest extractable cluster. It makes direct HTTP calls via `Net::HTTP`, parses HTML with Nokogiri, creates/updates Seeding, Game, GameParticipation, Player, Club, Location, TournamentCc records. It has no AASM or CableReady dependency.

### Cluster 6: Table Reservation Feature (~100 lines)
`create_table_reservation`, `available_tables_with_heaters`, `required_tables_count`, `fallback_table_count`, `format_table_list`, `build_event_summary`, `calculate_start_time`, `calculate_end_time`, `create_google_calendar_event`. Pure calculation + Google Calendar API call. No AASM or CableReady dependency.

### Cluster 7: Ranking and Seeding Helpers (~100 lines)
`reorder_seedings`, `date_str`, `name`, `cc_id`, `player_controlled?`, `match_location_from_location_text`, `t_no_from`, `has_clubcloud_results?`, `deep_merge_data!`. Mix of utilities. Most stay in the model; `deep_merge_data!` is a primitive used everywhere.

---

## Responsibility Clusters in TournamentMonitor + lib files (2099 lines total)

### TournamentMonitor model (499 lines)
AASM state machine, association declarations, `broadcast_status_update` → `TournamentStatusUpdateJob`, round management (`current_round`, `incr_current_round!`, `decr_current_round!`), ranking algorithm (`self.ranking`), player-from-ranking resolution (`player_id_from_ranking` and private helpers: `ko_ranking`, `group_rank`, `random_from_group_ranks`, `rank_from_group_ranks`), group distribution algorithm (`distribute_to_group`, `distribute_with_sizes`).

### lib/tournament_monitor_support.rb (1078 lines)
**Game result writing:** `write_game_result_data`, `finalize_game_result` — writes TableMonitor data to Game, triggers ClubCloud upload, updates GameParticipation.
**Result reporting orchestration:** `report_result` — the main result-processing method. Acquires DB lock on game, calls `write_game_result_data`, fires `finish_match!` AASM event, calls `finalize_game_result`, then `accumulate_results`, then `finalize_round`/`populate_tables` state machine advance.
**Rankings:** `accumulate_results`, `add_result_to`, `update_ranking`.
**Table population:** `populate_tables` (~500 lines), `do_placement`, `initialize_table_monitors`, `finalize_round`, `write_finale_csv_for_upload`.
**State queries:** `all_table_monitors_finished?`, `group_phase_finished?`, `finals_finished?`, `table_monitors_ready?`.
**GameParticipation:** `update_game_participations`, `update_game_participations_for_game`.

### lib/tournament_monitor_state.rb (522 lines)
`write_game_result_data` (also in support — this is the actual implementation), `finalize_game_result`, `all_table_monitors_finished?`, `finalize_round`, `group_phase_finished?`, `finals_finished?`, `table_monitors_ready?`, `do_reset_tournament_monitor`, `initialize_table_monitors`, `populate_tables`, `do_placement`, various private helpers for the eae_pg algorithm.

**Note:** There is significant duplication/overlap between the two lib files. `tournament_monitor_state.rb` contains the canonical implementations; `tournament_monitor_support.rb` contains the coordination layer and GameParticipation writing. Both files are included into `TournamentMonitor`, so all methods are visible on the model instance.

---

## System Overview Diagram

```
API Server
-------------------------------------------------------------------
TournamentsController
  |-- index, show, edit, update, destroy (CRUD)
  |-- reset, start, finish_seeding, select_modus, finalize_modus
  |-- order_by_ranking_or_handicap, define_participants
  |-- reload_from_cc, apply_seeding_order, compare_seedings
  v
Tournament (model, 1775 lines)
  |-- include LocalProtector     (read-only guard for global records)
  |-- include SourceHandler      (scrape source tracking)
  |-- include RegionTaggable     (region filtering)
  |-- include Searchable         (search concern)
  |-- aasm states: new_tournament → seeding_finished → mode_defined → started → finished → published
  |-- has_one :tournament_monitor
  |-- has_many :games, :seedings, :teams, :videos
  |-- belongs_to :organizer (polymorphic: Region or Club)
  |-- [Cluster 5] scrape_single_tournament_public → Net::HTTP + Nokogiri
  |-- [Cluster 6] create_table_reservation → GoogleCalendarService

TournamentReflex (StimulusReflex)
  |-- 17 attribute setters (innings_goal, balls_goal, etc.) → tournament.save!
  |-- change_party_seeding, change_seeding, change_no_show, change_position
  |-- sort_by_ranking, sort_by_handicap, move_up, move_down, change_point_goal

TournamentChannel (ActionCable)
  |-- streams: "tournament-stream" or "tournament-stream-{id}"

TournamentStatusUpdateJob
  |-- renders tournaments/tournament_status partial
  |-- broadcasts to "tournament-stream-{tournament_id}" via CableReady

Local Server
-------------------------------------------------------------------
TournamentMonitorsController
  |-- show, update, destroy (CRUD)
  |-- switch_players, start_round_games, update_games
  |-- ensure_local_server (rejects API server requests)
  |-- ensure_tournament_director (authorization)
  v
TournamentMonitor (model, 2099 lines total)
  |-- include TournamentMonitorSupport  (lib/tournament_monitor_support.rb, 1078 lines)
  |-- include TournamentMonitorState   (lib/tournament_monitor_state.rb, 522 lines)
  |-- include ApiProtector             (read-only guard for API-server context)
  |-- aasm states: new → playing_groups → playing_finals → finished → closed
  |-- belongs_to :tournament
  |-- has_many :table_monitors
  |-- report_result → [lock] → write_game_result_data → finish_match! → finalize_game_result
  |-- populate_tables → executor_params parsing → do_placement
  |-- accumulate_results → rankings aggregation
  |-- distribute_to_group / distribute_with_sizes → player grouping
  |-- player_id_from_ranking → ko_ranking / group_rank / random_from_group_ranks

TournamentMonitorChannel (ActionCable)
  |-- rejects if API server (!local_server?)
  |-- streams: "tournament-monitor-stream"

TournamentMonitorUpdateResultsJob
  |-- rejects if API server (!local_server?)
  |-- renders game_results and rankings partials
  |-- broadcasts to "tournament-monitor-stream" via CableReady
```

---

## Recommended Component Boundaries

### Tournament Extractions

#### Tournament::PublicCcScraper (ApplicationService)
**Responsibility:** All of `scrape_single_tournament_public` and its private helpers.
**Lines:** ~700 (Cluster 5)
**Why extract:** Largest single cluster. No AASM dependency. No CableReady dependency. Pure HTTP + Nokogiri + DB writes. Currently impossible to test in isolation because it is inlined in the model.
**Interface:**
```ruby
Tournament::PublicCcScraper.call(tournament: tournament, opts: {})
# Internally uses Net::HTTP + Nokogiri
# Creates/updates: Seeding, Game, GameParticipation, TournamentCc, Location, Player
# Returns: nothing (mutates DB)
```
**What stays in Tournament:** `scrape_single_tournament_public` becomes a one-liner delegating to the service.
**Risk:** MEDIUM — large but self-contained. The private `parse_table_tr`, `parse_table_td`, `handle_game`, `variant*` methods all move together.

#### Tournament::TableReservationService (ApplicationService)
**Responsibility:** Google Calendar event creation for table heating control.
**Lines:** ~100 (Cluster 6)
**Why extract:** Completely self-contained. Only dependency is `GoogleCalendarService`. Makes testing the algorithm possible without calling Google APIs.
**Interface:**
```ruby
Tournament::TableReservationService.call(tournament: tournament)
# Returns: Google Calendar event response or nil
```
**Risk:** LOW — isolated, no state machine involvement.

#### What Stays in Tournament After Extraction
- AASM state machine definition and all event callbacks
- `reset_tournament` (AASM callback — stays)
- `initialize_tournament_monitor` (AASM callback — stays)
- `calculate_and_cache_rankings` (AASM callback — stays)
- TournamentLocal attribute delegation loop
- Searchable concern callbacks
- `deep_merge_data!`, `t_no_from`, `name`, `date_str`, `has_clubcloud_results?`
- Association declarations, validations, constants, scopes
- Estimated post-extraction size: ~900 lines (from 1775)

---

### TournamentMonitor Extractions

The TournamentMonitor lib files are the primary extraction target. The model file itself (499 lines) is already reasonable.

#### TournamentMonitor::ResultProcessor (PORO or ApplicationService)
**Responsibility:** The `report_result` → `write_game_result_data` → `finalize_game_result` → `accumulate_results` → `finalize_round` sequence.
**Lines:** ~250 from lib files
**Why extract:** The result processing pipeline is the most complex, most risky, and most tested code path. Extracting it makes the lock → write → transition → finalize sequence explicit and testable without a running tournament.
**Interface:**
```ruby
processor = TournamentMonitor::ResultProcessor.new(tournament_monitor)
processor.process(table_monitor)
# Calls AASM events on tournament_monitor
# Calls finalize_game_result, accumulate_results, etc.
```
**Calls AASM events through:** `tournament_monitor.finish_match!`, `tournament_monitor.start_playing_groups!`, etc.
**Risk:** HIGH — this code has a DB lock, async jobs, and AASM transitions. Characterization tests must come first.

#### TournamentMonitor::TablePopulator (PORO)
**Responsibility:** The `populate_tables` method and its helpers (`do_placement`, `initialize_table_monitors`).
**Lines:** ~600 from lib/tournament_monitor_support.rb
**Why extract:** `populate_tables` is the single most complex method in the codebase — 500+ lines with deeply nested loops reading `executor_params` JSON, constructing games, and assigning table monitors. Extracting it makes it independently testable with fixture-based executor_params JSON.
**Interface:**
```ruby
populator = TournamentMonitor::TablePopulator.new(tournament_monitor)
populator.populate
# Reads tournament_monitor.data["placements"]
# Reads tournament.tournament_plan.executor_params
# Calls do_placement for each game
# Does NOT save tournament_monitor (caller saves)
```
**Risk:** HIGH — the most complex algorithm in the codebase. Must have comprehensive characterization tests before touching.

#### TournamentMonitor::RankingAccumulator (PORO)
**Responsibility:** `accumulate_results`, `add_result_to`, `update_ranking`.
**Lines:** ~100 from lib files
**Why extract:** Ranking aggregation is pure computation over GameParticipation records. No AASM. No broadcasts. Independently testable with fixture data.
**Interface:**
```ruby
accumulator = TournamentMonitor::RankingAccumulator.new(tournament_monitor)
accumulator.accumulate
# Reads GameParticipation records
# Writes data["rankings"] on tournament_monitor
# Does NOT save (caller saves)
```
**Risk:** LOW-MEDIUM — stateless computation, easy to characterize.

#### TournamentMonitor::PlayerGroupDistributor (PORO)
**Responsibility:** `distribute_to_group`, `distribute_with_sizes`, `GROUP_RULES`, `GROUP_SIZES`, `DIST_RULES` constants.
**Lines:** ~120 lines (already in model, not lib)
**Why extract:** These are pure algorithms with zero AR dependency. Already tested in `tournament_monitor_ko_test.rb`. Extract to make the algorithm callable without a TournamentMonitor instance.
**Interface:**
```ruby
distributor = TournamentMonitor::PlayerGroupDistributor.new(players, ngroups, group_sizes)
distributor.distribute
# Returns: { "group1" => [player_ids], "group2" => [player_ids], ... }
```
**Risk:** LOW — already partially tested, no side effects.

#### TournamentMonitor::RankingResolver (PORO)
**Responsibility:** `player_id_from_ranking`, `ko_ranking`, `group_rank`, `random_from_group_ranks`, `rank_from_group_ranks`.
**Lines:** ~200 lines (in model file)
**Why extract:** This is the rule-string parser for complex ranking resolution in KO and group tournaments. It is called by `populate_tables` and testable in isolation with fixture data.
**Interface:**
```ruby
resolver = TournamentMonitor::RankingResolver.new(tournament_monitor)
player_id = resolver.resolve(rule_str, opts)
```
**Risk:** MEDIUM — complex regex-based rule parsing, but no side effects. Already tested in `tournament_monitor_ko_test.rb`.

#### What Stays in TournamentMonitor After Extraction
- AASM state machine definition and all event callbacks
- `do_reset_tournament_monitor` (AASM callback — stays)
- `broadcast_status_update` → `TournamentStatusUpdateJob`
- Round management: `current_round`, `current_round!`, `incr_current_round!`, `decr_current_round!`
- `self.ranking` class method (used by RankingResolver — may pass it in or keep)
- Association declarations, serialization, `deep_merge_data!`
- `log_state_change`, `debug_log`, `before_all_events`
- Estimated post-extraction size: ~200 lines model + ~100 lines in each lib file (thin delegators)

---

## Data Flow After Extraction

### Live result processing flow (Local Server only)

```
TableMonitor#evaluate_result (AASM callback)
  -> tournament_monitor.report_result(table_monitor)
     [currently in lib/tournament_monitor_support.rb]
     -> becomes: TournamentMonitor::ResultProcessor.new(self).process(table_monitor)
        -> [DB lock on game]
        -> write_game_result_data(table_monitor)
           [becomes: part of ResultProcessor]
        -> table_monitor.finish_match! [AASM event on TableMonitor, not on TournamentMonitor]
        -> [release lock]
        -> finalize_game_result(table_monitor)
           -> Setting.upload_game_to_cc (ClubCloud upload)
           -> update_game_participations_for_game(game, data)
        -> TournamentMonitor::RankingAccumulator.new(self).accumulate
        -> finalize_round
        -> TournamentMonitor::TablePopulator.new(self).populate (if all games done)
        -> AASM events: start_playing_groups! / start_playing_finals! / end_of_tournament!
        -> TournamentMonitorUpdateResultsJob.perform_later
        -> TournamentStatusUpdateJob.perform_later
```

### Tournament state machine flow (API Server or Local)

```
User action (controller)
  -> tournament.finish_seeding! [AASM event]
     -> after_enter: calculate_and_cache_rankings [stays in model]
  -> tournament.start_tournament! [AASM event]
     -> initialize_tournament_monitor [stays in model]
        -> TournamentMonitor.create (delegates params from tournament)
        -> TournamentMonitorSupport#do_reset_tournament_monitor
           -> TournamentMonitor::PlayerGroupDistributor.distribute_to_group
           -> TournamentMonitor::TablePopulator#initialize_table_monitors
  -> [TournamentMonitor state: new -> playing_groups]
```

### Real-time broadcast flow

```
TournamentMonitor saved (any change to :state)
  -> after_update_commit :broadcast_status_update, if: :saved_change_to_state?
  -> TournamentStatusUpdateJob.perform_later(tournament)
     -> renders tournaments/tournament_status partial
     -> cable_ready["tournament-stream-{id}"].inner_html(...)
     -> cable_ready.broadcast
     -> Browser updates tournament status view (live scoreboard)
```

---

## Build Order

Build order is driven by test-before-refactor constraint and dependency graph.

### Phase 1: Characterization Tests (no extraction yet)

Write tests that characterize current behavior before any code changes. This is the v1.0 pattern that worked.

**1a. Tournament model characterization tests**
- AASM state transitions: `new_tournament` → each state
- `reset_tournament` — destroys TournamentMonitor, clears games and seedings
- `initialize_tournament_monitor` — creates TournamentMonitor with correct params
- `calculate_and_cache_rankings` — correct player_rank stored in data
- TournamentLocal delegation — reads/writes go to right table based on id < MIN_ID
- `required_tables_count` and `available_tables_with_heaters`

**1b. TournamentMonitor characterization tests**
- `distribute_to_group` with each player count (6–16)
- `player_id_from_ranking` with each rule string format
- `accumulate_results` — correct ranking aggregation
- `report_result` integration flow (fixtures with completed game)
- `populate_tables` with simple executor_params (groups format)
- AASM state transitions: new → playing_groups → playing_finals → finished

**1c. Controller and channel tests**
- `TournamentsController` — all actions, including `ensure_local_server` guard
- `TournamentMonitorsController` — all actions, `update_games` validation logic
- `TournamentChannel` — subscribe, stream_from assertion
- `TournamentMonitorChannel` — rejects on API server, accepts on local server
- `TournamentStatusUpdateJob` — renders partial, broadcasts correct selectors
- `TournamentMonitorUpdateResultsJob` — skips on API server, broadcasts on local

### Phase 2: Low-risk extractions (no AASM, no real-time)

**2a. Tournament::TableReservationService**
- Extract Cluster 6 (Google Calendar). Zero risk.
- Add unit tests for calculation methods.

**2b. TournamentMonitor::PlayerGroupDistributor**
- Extract static group distribution algorithm.
- Already partially tested — this is easy.

**2c. TournamentMonitor::RankingAccumulator**
- Extract `accumulate_results` and `add_result_to`.
- Pure computation, no AASM.

### Phase 3: Medium-risk extractions (AR writes, no AASM)

**3a. Tournament::PublicCcScraper**
- Extract Cluster 5 (public CC scraper, ~700 lines).
- This is the biggest single reduction for Tournament.
- Requires VCR cassettes or fixture HTML for scraping tests.
- Use the existing `test/fixtures/html/tournament_details_nbv_870.html` as the foundation.

**3b. TournamentMonitor::RankingResolver**
- Extract `player_id_from_ranking` and private helpers.
- Depends on `TournamentMonitor.ranking` (class method) — pass it as a collaborator.

### Phase 4: High-risk extractions (AASM integration, real-time)

**4a. TournamentMonitor::TablePopulator**
- Extract `populate_tables` (the 500-line complex algorithm).
- Must have comprehensive characterization tests from Phase 1.
- This is the highest-risk extraction in the milestone.

**4b. TournamentMonitor::ResultProcessor**
- Extract the `report_result` orchestration pipeline.
- Calls AASM events through `tournament_monitor` reference — do not move AASM.
- DB lock logic moves with the service.

### Phase 5: Controller and job test coverage

After extractions are stable, write additional tests for:
- `TournamentMonitorsController#update_games` validation cases
- `TournamentMonitorsController#start_round_games` state transitions
- `TournamentStatusUpdateJob` fallback render path
- `TournamentReflex` attribute setter delegation

---

## Integration Patterns

### Pattern: AASM events stay on the model, services call through reference

```ruby
# In TournamentMonitor::ResultProcessor
class TournamentMonitor::ResultProcessor
  def initialize(tournament_monitor)
    @tm = tournament_monitor
  end

  def process(table_monitor)
    # ... computation ...
    @tm.start_playing_groups!  # AASM event fires on model, callbacks fire
    TournamentMonitorUpdateResultsJob.perform_later(@tm)
  end
end
```

Never move `aasm` blocks into service classes. State machine definitions must stay on the model.

### Pattern: Service receives model, writes to data hash, does not save

```ruby
# In TournamentMonitor::RankingAccumulator
def accumulate
  rankings = compute_rankings
  @tm.data_will_change!
  @tm.data["rankings"] = rankings
  @tm.save!  # OR: let caller save — match existing behavior
end
```

The key question for each extraction is whether the service saves or the caller saves. Match the existing behavior exactly during extraction. Do not change the save protocol during the refactoring phase.

### Pattern: Thin coordinator remains in model after extraction

```ruby
# In TournamentMonitor (after extraction)
def report_result(table_monitor)
  TournamentMonitor::ResultProcessor.new(self).process(table_monitor)
end

# In lib/tournament_monitor_support.rb — becomes:
def populate_tables
  TournamentMonitor::TablePopulator.new(self).populate
end
```

Callers of `tournament_monitor.report_result(table_monitor)` do not change. The public API is preserved.

### Pattern: Local-server guard at channel and job level

Both `TournamentMonitorChannel` and `TournamentMonitorUpdateResultsJob` explicitly guard with `ApplicationRecord.local_server?`. Do not move or weaken these guards. They are correct and intentional — TournamentMonitor does not exist on the API server during live tournaments.

### Anti-Pattern: Extracting lib includes prematurely

`TournamentMonitorSupport` and `TournamentMonitorState` are Ruby modules included into the model. They can call instance methods like `tournament`, `table_monitors`, `data`, `save!` freely because they are mixed in. If extracted to separate service classes, these dependencies must be explicitly injected. Do not move lib module methods to services without verifying every implicit `self` reference.

### Anti-Pattern: Testing with unguarded API server context

`ApiProtectorTestOverride` in `test_helper.rb` prevents silent save rollbacks in API server context. Any test that creates or modifies TournamentMonitor records must ensure this override is active. Check `test_helper.rb` before writing new TournamentMonitor tests.

---

## Known Sensitivity Points

**`populate_tables` executor_params JSON parsing**
The `executor_params` JSON contains a complex domain-specific schema (`{"g1": {"sq": {"r1": {"t1": "1-2"}}, "balls": 40}, ...}`). The `populate_tables` method interprets this schema across ~500 lines. Any extraction must carry the same JSON interpretation logic without regressions. VCR or fixture-based executor_params JSON should be collected from production before extraction.

**DB lock in `report_result`**
`report_result` acquires a pessimistic lock on the game record (`game.with_lock do`). This prevents race conditions when multiple TableMonitors finish simultaneously. If `ResultProcessor` is extracted, the lock must remain inside the service. The comment in the code explains the exact race condition this prevents — read it before touching.

**`data_will_change!` before every data mutation**
`TournamentMonitor#data` is serialized JSON. ActiveRecord's dirty tracking does not detect nested hash mutations. Every method that mutates `data["something"]` must call `data_will_change!` first. Services that take ownership of data mutation inherit this requirement. Missing `data_will_change!` causes silent data loss (the column is not written to the DB).

**`TournamentMonitor.ranking` is a class method**
`TournamentMonitor::RankingResolver` will need `TournamentMonitor.ranking(hash, opts)` — a class method that sorts a hash by weighted criteria. Pass it as a collaborator or keep it accessible via the class. Do not move it to an instance method.

**`write_finale_csv_for_upload` hardcodes email addresses**
This method sends result CSVs to `gernot.ullrich@gmx.de` plus the `current_admin` email. It is called at tournament end. When extracted, the email logic may need to be configurable or testable in isolation. For now, extract it as-is and mark it for future cleanup.

**TournamentMonitor has no tests yet**
Unlike TableMonitor (58 characterization tests before v1.0 extraction), TournamentMonitor has only `tournament_monitor_ko_test.rb` and integration tests. The Phase 1 characterization test effort for TournamentMonitor is the largest risk in this milestone. Plan for this to take as long as the actual extraction work.

---

## Component Communication Map (After Extraction)

```
API Server
-----------
TournamentsController
  -> Tournament (model: AASM, associations, delegates, backbone)
       -> Tournament::PublicCcScraper     (scrape_single_tournament_public)
       -> Tournament::TableReservationService (Google Calendar)
  -> TournamentReflex (17 attribute setters, seeding changes)
  -> TournamentStatusUpdateJob -> TournamentChannel -> Browser

Local Server
-------------
TournamentMonitorsController
  -> TournamentMonitor (model: AASM, association, round management, delegates)
       -> TournamentMonitor::ResultProcessor    (report_result pipeline)
       -> TournamentMonitor::TablePopulator     (populate_tables)
       -> TournamentMonitor::RankingAccumulator (accumulate_results)
       -> TournamentMonitor::RankingResolver    (player_id_from_ranking)
       -> TournamentMonitor::PlayerGroupDistributor (distribute_to_group)
  -> TournamentMonitorUpdateResultsJob -> TournamentMonitorChannel -> Browser
  -> TableMonitor (via table_monitors association)
       -> [v1.0 services: ScoreEngine, GameSetup, ResultRecorder]
```

---

## Sources

All findings from direct inspection of production code:
- `app/models/tournament.rb` (1775 lines)
- `app/models/tournament_monitor.rb` (499 lines)
- `lib/tournament_monitor_support.rb` (1078 lines)
- `lib/tournament_monitor_state.rb` (522 lines)
- `app/controllers/tournaments_controller.rb`
- `app/controllers/tournament_monitors_controller.rb`
- `app/channels/tournament_channel.rb`
- `app/channels/tournament_monitor_channel.rb`
- `app/jobs/tournament_status_update_job.rb`
- `app/jobs/tournament_monitor_update_results_job.rb`
- `app/reflexes/tournament_reflex.rb`
- `.planning/PROJECT.md`

Confidence: HIGH — all conclusions from reading actual production code.
