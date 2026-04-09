# Architecture Patterns: God-Model Extraction

**Domain:** Rails god-model refactoring with real-time and state machine integration
**Researched:** 2026-04-09
**Confidence:** HIGH (based on direct codebase analysis, not speculation)

---

## What the Extraction Must Preserve

Before defining components, the constraints:

- `TableMonitorReflex` methods call model methods directly (`@table_monitor.add_n_balls(...)`, `@table_monitor.terminate_current_inning`, etc.). The model's public API cannot change.
- `after_update_commit` fires `TableMonitorJob.perform_later(self.id, ...)`. The job reads a fresh model instance. The model must still save to trigger this.
- AASM events (`finish_warmup!`, `finish_shootout!`, `evaluate_result`) must remain callable on the model instance.
- `get_options!` is called from both `TableMonitorJob` and indirectly from reflexes. It is a cattr_accessor-based caching method with known race condition risk — this is a sensitivity point.

---

## TableMonitor: Recommended Component Boundaries

Three extractable service clusters emerge from the 3903-line model:

### 1. TableMonitor::ScoreEngine

**Responsibility:** All in-game score mutation logic — the "what happens when a ball is potted" cluster.

Methods to extract (all currently in `TableMonitor`):
- `add_n_balls` (lines 1529–1709, ~180 lines)
- `terminate_current_inning` (lines 2140–2253, ~113 lines)
- `set_n_balls` (lines 2036–2139, ~103 lines)
- `recompute_result` (lines 1487–1528)
- `init_lists` (lines 1529–)
- `render_innings_list` / `render_last_innings`
- `undo` / `redo` / `can_undo?` / `can_redo?`
- Snooker-specific group: `update_snooker_state`, `recalculate_snooker_state_from_protocol`, `undo_snooker_ball`, `snooker_balls_on`, `snooker_remaining_points`, `initial_red_balls`
- `deep_diff` / `simple_score_update?` / `ultra_fast_score_update?`

**Interface contract with model:**
```ruby
# Model delegates to service, passing self
score_engine = TableMonitor::ScoreEngine.new(table_monitor)
score_engine.add_n_balls(n, player)
# Service mutates table_monitor.data directly, does NOT save
# Model saves after reflex finishes
```

**Why this boundary:** All these methods share `data` (the serialized JSON hash) as their sole input/output. They do not touch `state`, `game_id`, or external models. They are pure transformations of the score hash. This makes them extractable without touching AASM or CableReady.

**Does NOT communicate with:** AASM, CableReady, Jobs, Game model directly.

---

### 2. TableMonitor::GameSetup

**Responsibility:** Game initialization and player assignment — the "set up a new match" cluster.

Methods to extract:
- `start_game` (lines 2835–2968, ~133 lines) — the largest single method in the model
- `initialize_game` (lines 1195–1389)
- `assign_game`
- `set_player_sequence`
- `revert_players` / `switch_players`
- `seeding_from`

**Interface contract:**
```ruby
setup = TableMonitor::GameSetup.new(table_monitor)
setup.start_game(options)
# Creates/updates Game and GameParticipation records
# Returns without saving table_monitor — caller saves
```

**Why this boundary:** `start_game` is the most entangled method — it manages `Game` creation, `GameParticipation` records, `skip_update_callbacks` flag, and initial `data` hash construction. Extracting it to a service makes the three-save sequence (which suppresses callbacks) explicit and testable.

**Communicates with:** `Game`, `GameParticipation`, `Player` models. Sets `table_monitor.data` and `table_monitor.skip_update_callbacks`. Does NOT touch AASM or CableReady.

---

### 3. TableMonitor::ResultRecorder

**Responsibility:** Saving game results at set/match end — the "persist what happened" cluster.

Methods to extract:
- `save_result` (lines 2507–2578, ~71 lines)
- `save_current_set` (lines 2579–2625)
- `evaluate_result` (lines 2712–2834)
- `prepare_final_game_result`
- `switch_to_next_set` (lines 2640–2711)
- `get_max_number_of_wins` / `sets_played`

**Interface contract:**
```ruby
recorder = TableMonitor::ResultRecorder.new(table_monitor)
recorder.evaluate_result
# Calls AASM events on table_monitor (finish_match!, acknowledge_result!)
# Saves to Game record
# Does NOT call CableReady directly
```

**Critical integration point:** `evaluate_result` fires AASM events on the model (`finish_match!`). The service must receive the `table_monitor` instance and call AASM events on it — the service does not own the state machine. This is non-negotiable.

**Communicates with:** `Game`, `TournamentMonitor` (via `report_result`). Fires AASM events on `table_monitor`. Does NOT call CableReady (broadcasting is triggered by `after_update_commit` which fires after the model saves).

---

### What Stays in TableMonitor

After extraction, the model retains:
- AASM state machine definition (states, events, transitions, callbacks)
- `after_update_commit` callback with job dispatch logic
- `log_state_change` / `log_state_change_destroy` callbacks
- `get_options!` / `clear_options_cache` (view-preparation logic, tightly coupled to cattr_accessor pattern)
- `state_display`, `locked_scoreboard`, display-related query methods
- `do_play` / `reset_timer!` / `update_every_n_seconds` (timer management, talks to `TableMonitorClockJob`)
- Association declarations, serialization, basic attribute accessors
- All AASM event callbacks (`set_game_over`, `set_start_time`, `set_end_time`, `reset_table_monitor`)
- `deep_merge_data!` / `deep_delete!` (data manipulation primitives used by multiple services)

Estimated post-extraction size: ~600–800 lines. Reaching the 500-line target requires also extracting `get_options!` — see build order note below.

---

## RegionCc: Recommended Component Boundaries

Four extractable service clusters emerge:

### 1. RegionCc::HttpClient

**Responsibility:** Raw HTTP communication with ClubCloud — the "talk to the remote API" cluster.

Methods to extract:
- `post_cc` (lines 636–677)
- `post_cc_with_formdata` (lines 586–634)
- `get_cc` (lines 679–685)
- `get_cc_with_url` (lines 687–706)
- `discover_admin_url_from_public_site` (lines 477–537)
- `ensure_admin_base_url!` (lines 539–567)

**Interface contract:**
```ruby
client = RegionCc::HttpClient.new(base_url: region_cc.base_url)
res, doc = client.get(action, params, session_id: session_id)
res, doc = client.post(action, params, session_id: session_id)
```

**Why this boundary:** These methods share no domain knowledge. They take a URL, params, and session cookie; they return `[Net::HTTPResponse, Nokogiri::Document]`. They do not touch ActiveRecord. Pure I/O abstraction. This is the lowest-risk extraction and the highest-value one for testing (currently untestable without VCR cassettes for every sync operation).

**Does NOT communicate with:** Any Rails model. Takes `base_url` as constructor argument.

---

### 2. RegionCc::LeagueSyncer

**Responsibility:** League and team structure synchronization.

Methods to extract:
- `synchronize_league_structure`
- `synchronize_league_plan_structure`
- `sync_league_teams_new` / `sync_league_teams`
- `sync_league_plan`
- `sync_team_players_structure`
- `sync_team_players`
- `sync_category_ccs` / `sync_group_ccs` / `sync_discipline_ccs`

**Interface contract:**
```ruby
syncer = RegionCc::LeagueSyncer.new(region_cc, client: http_client)
syncer.synchronize_league_structure(season_name:, armed: true)
```

**Communicates with:** `League`, `Season`, `LeagueTeam`, `Player`, `BranchCc` models. Uses `RegionCc::HttpClient` for HTTP. Writes to DB. Raises `ArgumentError` on missing references.

---

### 3. RegionCc::TournamentSyncer

**Responsibility:** Tournament structure and competition synchronization.

Methods to extract:
- `sync_tournaments`
- `sync_tournament_ccs`
- `sync_tournament_series_ccs`
- `sync_competitions` / `sync_seasons_in_competitions`
- `fix_tournament_structure`
- `synchronize_tournament_structure`
- `sync_championship_type_ccs`

**Interface contract:**
```ruby
syncer = RegionCc::TournamentSyncer.new(region_cc, client: http_client)
syncer.sync_tournaments(season_name:, armed: true)
```

**Communicates with:** `Tournament`, `TournamentCc`, `Season`, `Competition` models. Uses `RegionCc::HttpClient`.

---

### 4. RegionCc::PartySyncer

**Responsibility:** Party (match) and game result synchronization.

Methods to extract:
- `sync_parties`
- `sync_party_games`
- `sync_game_plans`
- `sync_game_details`
- `sync_registration_list_ccs` / `sync_registration_list_ccs_detail`

**Interface contract:**
```ruby
syncer = RegionCc::PartySyncer.new(region_cc, client: http_client)
syncer.sync_parties(season_name:, armed: true)
```

**Communicates with:** `Party`, `Game`, `GameParticipation` models. Uses `RegionCc::HttpClient`.

---

### What Stays in RegionCc

- Association declarations (`belongs_to :region`, `has_many :branch_ccs`)
- Constants (`PATH_MAP`, `PUBLIC_ACCESS`, `STATUS_MAP`, `BASE_URL`)
- `self.sync_regions` (bootstrap operation, reasonable to keep or extract later)
- `sync_branches` (short, region-configuration level)
- `sync_leagues` (top-level coordinator — calls LeagueSyncer)
- `deep_merge_data!` / `raise_err_msg` utilities
- Logger configuration (`REPORT_LOGGER`)
- `fix` method (minor data correction, ~12 lines)

Estimated post-extraction size: ~200–300 lines.

---

## Data Flow After Extraction

### TableMonitor real-time flow (unchanged externally)

```
Browser keyboard input
  -> StimulusJS controller
  -> TableMonitorReflex#key_a (or key_b, key_c, key_d, undo, redo, nnn_enter)
  -> Reflex calls table_monitor.method_now_delegated_to_service(...)
     [ScoreEngine or ResultRecorder mutates table_monitor.data]
  -> Reflex calls table_monitor.save
  -> after_update_commit fires
  -> TableMonitorJob.perform_later(self.id, operation_type)
  -> Job renders partial, calls cable_ready["table-monitor-stream"].inner_html(...)
  -> cable_ready.broadcast
  -> Browser DOM updated
```

The services sit between step 3 and step 4. The reflex still calls the model; the model delegates to services. The save/broadcast chain is unchanged.

### AASM integration pattern

AASM events (`finish_warmup!`, `finish_shootout!`) remain on the model. Services call them through the model reference they receive:

```ruby
# Inside ResultRecorder
def evaluate_result
  # ... compute result logic ...
  @table_monitor.finish_match!  # AASM event on model
  @table_monitor.save
end
```

Services never define or fire AASM events themselves. The state machine stays authoritative in the model.

### RegionCc sync flow (unchanged externally)

```
Admin console / background job
  -> region_cc.sync_leagues(opts)
  -> [stays in model, acts as coordinator]
  -> RegionCc::LeagueSyncer.new(self, client:).synchronize_league_structure(opts)
     -> RegionCc::HttpClient.get(action, params)
     -> Nokogiri parse
     -> League.find_or_create / update
  -> [returns to model or caller]
```

The `sync_*` methods in the model become thin coordinators that instantiate the appropriate service and delegate.

---

## Suggested Build Order

The dependency graph drives the order. Lower-risk, higher-isolation extractions come first.

### Phase A — RegionCc (lower real-time risk)

**Step 1: RegionCc::HttpClient**
- Zero ActiveRecord coupling. Pure I/O.
- Unlocks VCR-based testing of all sync operations without DB.
- No other sync service works correctly without this, so it must go first.
- Risk: LOW.

**Step 2: RegionCc::LeagueSyncer**
- Depends on HttpClient (inject as constructor arg).
- Largest cluster; most test value.
- Risk: MEDIUM (cross-model writes, but no callbacks, no real-time).

**Step 3: RegionCc::TournamentSyncer and RegionCc::PartySyncer**
- Same pattern as LeagueSyncer. Can be done in either order.
- Risk: MEDIUM.

### Phase B — TableMonitor (higher real-time risk, extract last)

**Step 4: TableMonitor::ScoreEngine**
- No AASM coupling. No external model coupling. Pure `data` hash transformation.
- Extract first within TableMonitor because it is the most self-contained.
- Risk: MEDIUM (complex logic, but isolated from callbacks/jobs).

**Step 5: TableMonitor::GameSetup**
- Depends on `Game`, `GameParticipation`, `Player` — but only creates/updates records.
- The `skip_update_callbacks` flag management must move with `start_game`.
- Risk: MEDIUM-HIGH (multi-save sequence, suppressed callbacks).

**Step 6: TableMonitor::ResultRecorder**
- Calls AASM events. Must be extracted last within TableMonitor because it touches the most cross-cutting concerns.
- Verify AASM callback chain (`after_enter: :set_game_over`) still fires correctly when events are called from a service object.
- Risk: HIGH.

---

## Integration Patterns

### Pattern: Service receives model, mutates in memory, does not save

```ruby
class TableMonitor::ScoreEngine
  def initialize(table_monitor)
    @tm = table_monitor
  end

  def add_n_balls(n, player = nil)
    # ... mutates @tm.data ...
    # Does NOT call @tm.save
  end
end
```

The reflex is responsible for saving:
```ruby
# In TableMonitorReflex#key_a
@table_monitor.score_engine.add_n_balls(1, "playera")
@table_monitor.save  # triggers after_update_commit -> Job -> CableReady
```

This means CableReady broadcasts continue to be triggered by the existing `after_update_commit` hook. No change to the broadcasting layer.

### Pattern: Model exposes service as lazy accessor

```ruby
# In TableMonitor
def score_engine
  @score_engine ||= TableMonitor::ScoreEngine.new(self)
end
```

Reflexes call `table_monitor.score_engine.add_n_balls(...)` — same call site shape as before, just routed through the service. No reflex changes required in Phase B steps 4 and 5.

### Pattern: Coordinator method for RegionCc sync

```ruby
# In RegionCc (remains in model)
def sync_leagues(opts = {})
  client = RegionCc::HttpClient.new(base_url: base_url)
  RegionCc::LeagueSyncer.new(self, client: client).synchronize_league_structure(opts)
end
```

Callers of `region_cc.sync_leagues(...)` are unchanged. The public API is preserved.

### Anti-Pattern: Service that calls cable_ready directly

Do not extract the CableReady broadcasting logic into a service. The broadcasting in `TableMonitorJob` is intentionally decoupled from model saves (it runs in a background job, loads a fresh DB instance, renders a partial). Breaking this coupling would require the service to hold references to the job queue or ActionCable server, making it untestable.

### Anti-Pattern: Service that owns AASM state

AASM states and events must remain on the `TableMonitor` model. `aasm column: "state"` writes to the DB column. If a service fires `table_monitor.state = "playing"` directly (bypassing AASM events), the `after_enter` callbacks (`set_game_over`, etc.) will not fire. Always fire AASM events through the model reference.

---

## Component Communication Map

```
TableMonitorReflex
  -> TableMonitor (model, AASM, save triggers broadcast)
       -> TableMonitor::ScoreEngine     (data hash mutation)
       -> TableMonitor::GameSetup       (Game/GameParticipation creation)
       -> TableMonitor::ResultRecorder  (result persistence, fires AASM events back on model)
  -> [model.save fires after_update_commit]
       -> TableMonitorJob (background)
            -> CableReady (broadcast to "table-monitor-stream")
                 -> Browser DOM

RegionCc (model, coordinator)
  -> RegionCc::HttpClient              (Net::HTTP + Nokogiri, no AR)
  -> RegionCc::LeagueSyncer            (League/Team AR writes, uses HttpClient)
  -> RegionCc::TournamentSyncer        (Tournament AR writes, uses HttpClient)
  -> RegionCc::PartySyncer             (Party/Game AR writes, uses HttpClient)
```

---

## Known Sensitivity Points

**`get_options!` / `cattr_accessor :options` race condition**
The `options` accessor is class-level. `TableMonitorJob` already works around this with `options_snapshot = table_monitor.options.deep_dup`. This issue predates extraction and does not get worse from extracting score logic. However, if `ScoreEngine` ever needs to call `get_options!`, it must not rely on the class-level accessor — pass the snapshot explicitly.

**`skip_update_callbacks` flag in `GameSetup`**
`start_game` does three saves and sets `skip_update_callbacks = true` to prevent six spurious job enqueues. When `start_game` moves to `GameSetup`, the service must set this flag on the model before the first save and unset it after the last. The flag must remain on the model — it is checked in `after_update_commit`.

**AASM `after_enter` callbacks fire on save, not on event call**
`state :set_over, after_enter: [:set_game_over]` — `set_game_over` calls `save` internally. When `ResultRecorder` calls `table_monitor.end_of_set!`, this will trigger `set_game_over` which calls `save` which triggers `after_update_commit` which enqueues a job. This nested save/broadcast chain is existing behavior; it must not be broken by extraction.

**RegionCc `REPORT_LOGGER` is a constant on the model**
The sync services will need access to `RegionCc.logger`. Pass it as a constructor argument or have services call `RegionCc.logger` directly. Do not redefine the logger in each service class.

---

## Sources

All findings are from direct inspection of:
- `/app/models/table_monitor.rb` (3903 lines)
- `/app/models/region_cc.rb` (2728 lines)
- `/app/jobs/table_monitor_job.rb` (401 lines)
- `/app/reflexes/table_monitor_reflex.rb`
- `/app/services/application_service.rb`
- `.planning/PROJECT.md`
- `.planning/codebase/ARCHITECTURE.md`

Confidence: HIGH — conclusions drawn from reading actual production code, not from general Rails patterns.
