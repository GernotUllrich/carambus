# Phase 15: High-Risk Extractions - Research

**Researched:** 2026-04-10
**Domain:** Ruby service extraction — pessimistic locking, AASM event firing, complex game sequencing
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**ResultProcessor (TMEX-03)**
- D-01: Extract as ApplicationService in `app/services/tournament_monitor/result_processor.rb`. Receives TournamentMonitor instance. The DB lock (`game.with_lock`) stays inside the service.
- D-02: AASM events fired from the service via `@tournament_monitor.start_playing_finals!` etc. — the service calls AASM bang methods on the model reference.
- D-03: Methods to extract from `lib/tournament_monitor_support.rb`: `report_result`, `update_game_participations`, `update_game_participations_for_game`, `accumulate_results`, `add_result_to`, `update_ranking`.
- D-04: Methods to extract from `lib/tournament_monitor_state.rb`: `write_game_result_data`, `finalize_game_result`.
- D-05: `write_finale_csv_for_upload` from support.rb also moves — called by the result pipeline, no other callers.

**TablePopulator (TMEX-04)**
- D-06: Extract as ApplicationService in `app/services/tournament_monitor/table_populator.rb`. Receives TournamentMonitor instance. Contains `populate_tables`, `do_placement`, `initialize_table_monitors`.
- D-07: `do_reset_tournament_monitor` from `lib/tournament_monitor_state.rb` moves to TablePopulator. The AASM `after_enter` callback on `new_tournament_monitor` stays on the model and delegates to the service.
- D-08: State query methods (`group_phase_finished?`, `finals_finished?`, `all_table_monitors_finished?`, `table_monitors_ready?`, `finalize_round`) stay on the model/lib modules — they are used by views, controllers, and other callers beyond just the populator. If they only serve populate_tables, Claude may move them.

**Shared Decisions**
- D-09: Follow established extraction pattern: extract → delegate → test. `self` → `@tournament_monitor` conversion.
- D-10: Unit tests in `test/services/tournament_monitor/`. All Phase 11-12 characterization tests MUST pass unchanged.
- D-11: After extraction, the lib modules should be significantly smaller. If either becomes empty, it can be removed entirely.

### Claude's Discretion
- Exact extraction boundary for methods that serve both services (e.g., `finalize_round`)
- Whether to split populate_tables into smaller private methods within the service
- How to handle the `deep_merge_data!` calls — they stay on the model (data mutation method)
- Error handling and logging preservation
- Whether empty lib modules should be removed or kept as shells

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

## Summary

Phase 15 extracts the two highest-risk method groups from TournamentMonitor's lib modules: the result processing pipeline (`report_result` and its chain) into `ResultProcessor`, and the table population algorithm (`populate_tables`, `do_placement`, `initialize_table_monitors`, `do_reset_tournament_monitor`) into `TablePopulator`. Both services follow the established PORO/ApplicationService pattern from Phase 13-14.

The central technical challenge is `self` → `@tournament_monitor` reference conversion. Every implicit method call (`accumulate_results`, `reload`, `save!`, `deep_merge_data!`, `incr_current_round!`, `current_round`, etc.) in the extracted methods is currently dispatched on `self` (the TournamentMonitor model). After extraction, these must be prefixed with `@tournament_monitor.`. Instance variables (`@placements`, `@groups`, `@tournament_plan`, `@table`, `@table_monitor`, `@placement_candidates`, `@placements_done`) must become service-local `@` ivars initialized from `@tournament_monitor.data`, not from model state.

The DB lock scope in `report_result` is critical: `game.with_lock` wraps write_game_result_data + finish_match! transition atomically. This boundary must be preserved exactly. AASM events (`end_of_tournament!`, `start_playing_finals!`, `start_playing_groups!`) fire on `@tournament_monitor` from inside the service, which is correct — they trigger model `after_enter` callbacks and `after_update_commit` broadcasts as they did before.

**Primary recommendation:** Extract in this order: ResultProcessor first (smaller, more clearly scoped), then TablePopulator. Write delegation wrappers before running the characterization test suite. Verify all three existing characterization tests pass unchanged after each extraction.

---

## Standard Stack

### Core (No New Dependencies)
| Library | Version | Purpose | Note |
|---------|---------|---------|------|
| ApplicationService | existing | Base class for side-effect services | `app/services/application_service.rb` — 5 lines |
| AASM | existing | State machine on TournamentMonitor model | Events called on `@tournament_monitor`, not the service |
| ActiveRecord pessimistic locking | existing (Rails 7.2) | `game.with_lock` in ResultProcessor | Must stay inside the service, per D-01 |
| TournamentMonitor::RankingResolver | existing | Called by `update_ranking` and `populate_tables` via `player_id_from_ranking` | Already extracted in Phase 14 |

**Installation:** No new gems. All dependencies already present.

---

## Architecture Patterns

### Recommended Project Structure
```
app/services/tournament_monitor/
├── player_group_distributor.rb   # Phase 13 — DONE
├── ranking_resolver.rb           # Phase 14 — DONE
├── result_processor.rb           # Phase 15 — THIS PHASE (TMEX-03)
└── table_populator.rb            # Phase 15 — THIS PHASE (TMEX-04)

lib/
├── tournament_monitor_support.rb  # Shrinks: result pipeline + populate_tables leave
└── tournament_monitor_state.rb    # Shrinks: write_game_result_data, finalize_game_result,
                                  #          do_reset_tournament_monitor leave.
                                  #          Query methods (group_phase_finished? etc.) stay.
```

### Pattern 1: ApplicationService with `@tournament_monitor` Reference

Both new services follow the same pattern as `TournamentMonitor::RankingResolver` (but as ApplicationService due to side effects):

```ruby
# Source: app/services/tournament_monitor/ranking_resolver.rb (established pattern)
class TournamentMonitor::ResultProcessor
  def initialize(tournament_monitor)
    @tournament_monitor = tournament_monitor
  end

  def call
    # all extracted methods land here as private methods
  end

  private

  # Previously: def report_result(table_monitor)
  # Now: @tournament_monitor.report_result(table_monitor) delegates here
  def report_result(table_monitor)
    # every bare "tournament" → @tournament_monitor.tournament
    # every bare "accumulate_results" → accumulate_results (private, still in service)
    # every bare "reload" → @tournament_monitor.reload
    # every bare "save!" → @tournament_monitor.save!
    # every bare "deep_merge_data!(h)" → @tournament_monitor.deep_merge_data!(h)
    # every bare "incr_current_round!" → @tournament_monitor.incr_current_round!
    # every bare "decr_current_round!" → @tournament_monitor.decr_current_round!
    # every bare "data" → @tournament_monitor.data
    # every bare "end_of_tournament!" → @tournament_monitor.end_of_tournament!
    # every bare "start_playing_finals!" → @tournament_monitor.start_playing_finals!
    # every bare "start_playing_groups!" → @tournament_monitor.start_playing_groups!
    # every bare "all_table_monitors_finished?" → @tournament_monitor.all_table_monitors_finished?
    # every bare "finalize_round" → @tournament_monitor.finalize_round
    # every bare "group_phase_finished?" → @tournament_monitor.group_phase_finished?
    # every bare "finals_finished?" → @tournament_monitor.finals_finished?
    # every bare "write_game_result_data" → write_game_result_data (private in service)
    # every bare "finalize_game_result" → finalize_game_result (private in service)
    # every bare "table_monitors" → @tournament_monitor.table_monitors
    # every bare "tournament" → @tournament_monitor.tournament
    # every bare "sets_to_play" → @tournament_monitor.sets_to_play
    # every bare "innings_goal" → @tournament_monitor.innings_goal
    # "tournament_monitor" in finalize_game_result log tags → keep as string literals
    ...
  end
end
```

### Pattern 2: Delegation Wrapper on TournamentMonitor Model

After extraction, the model delegates through thin wrappers, as done for PlayerGroupDistributor and RankingResolver:

```ruby
# In app/models/tournament_monitor.rb — added after extraction:
def report_result(table_monitor)
  TournamentMonitor::ResultProcessor.new(self).report_result(table_monitor)
end

def do_reset_tournament_monitor
  TournamentMonitor::TablePopulator.new(self).do_reset_tournament_monitor
end

def populate_tables
  TournamentMonitor::TablePopulator.new(self).populate_tables
end
```

The AASM `after_enter: [:do_reset_tournament_monitor]` on the model's `new_tournament_monitor` state continues to call `do_reset_tournament_monitor` on the model — this wrapper then delegates to the service. No AASM change is needed.

### Pattern 3: Instance Variable Handling in TablePopulator

`populate_tables` and `do_placement` share in-memory state via `@placements`, `@placement_candidates`, `@placements_done`, `@groups`, `@tournament_plan`, `@table`, `@table_monitor`. These ivars work in the current design because all methods are on the same TournamentMonitor instance. After extraction, these become ivars on the service object (still `@placements`, etc.) — valid because the service is instantiated fresh per call.

Key: `@tournament_plan` is initialized in `do_reset_tournament_monitor` and then used in `populate_tables`. Since `do_reset_tournament_monitor` calls `populate_tables` within the same service instance (not via delegation round-trip), the ivar persists correctly.

```ruby
class TournamentMonitor::TablePopulator
  def initialize(tournament_monitor)
    @tournament_monitor = tournament_monitor
  end

  def do_reset_tournament_monitor
    @tournament_plan ||= @tournament_monitor.tournament.tournament_plan
    # calls populate_tables internally — @tournament_plan is available
    populate_tables unless @tournament_monitor.tournament.manual_assignment
    ...
  end

  private

  def populate_tables
    # @placements, @placement_candidates, @placements_done are service ivars
    @placements = @tournament_monitor.data["placements"].presence || {}
    ...
    # player_id_from_ranking stays as delegation:
    # @tournament_monitor.player_id_from_ranking(rule_str, opts)
  end

  def do_placement(new_game, r_no, t_no, sets, balls, innings)
    # self.allow_change_tables = false → @tournament_monitor.allow_change_tables = false
    # (cattr_accessor on TournamentMonitor class, not model-instance attribute)
    ...
  end
end
```

### Anti-Patterns to Avoid

- **Round-trip delegation for intra-service calls:** `populate_tables` is called from `do_reset_tournament_monitor` within the same service. Do NOT delegate this back through the model — call `populate_tables` directly as a private method call within the service. Calling `@tournament_monitor.populate_tables` would create a NEW service instance, losing `@tournament_plan` and other ivars.

- **Reading `@tournament_monitor.data` after a `deep_merge_data!`/`save!` inside the service without `reload`:** `accumulate_results` calls `data["rankings"] = rankings; save!` — after this, `@tournament_monitor.data` in memory IS the updated hash (no reload needed within the service). But if another code path reloads the model between steps, in-memory merges are lost.

- **Splitting `do_reset_tournament_monitor`'s save count:** The method currently makes ~6 distinct `deep_merge_data! + save!` calls. Each is intentional: they checkpoint state so crash recovery does not lose progress. Do not collapse them into one save — but do not add more saves either.

- **Using `self.allow_change_tables = false` in service code without prefix:** In the current module, `self` is the TournamentMonitor instance, so `self.allow_change_tables` accesses the `cattr_accessor`. In the service, `self` is the service object. Must write `TournamentMonitor.allow_change_tables = false` (class-level setter) or `@tournament_monitor.class.allow_change_tables = false`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Pessimistic locking | Custom mutex or semaphore | `game.with_lock` (ActiveRecord) | Already in use; proven pattern for this exact race condition |
| AASM state check before event | Manual `if state == "playing_groups"` | `@tournament_monitor.may_start_playing_finals?` | AASM provides guard predicates; use them |
| JSON deep merge | Custom hash merge | `@tournament_monitor.deep_merge_data!(hash)` | Already on model; handles `data_will_change!` marking |
| Player ranking resolution | Custom ranking sort | `@tournament_monitor.player_id_from_ranking(rule_str, opts)` | Phase 14 extracted RankingResolver handles all cases |

---

## Method-by-Method Extraction Map

### ResultProcessor (TMEX-03) — Methods Moving from lib/ to Service

**From `lib/tournament_monitor_support.rb`:**

| Method | Line | Self-refs to Convert | Calls Other Moving Methods | External Callers |
|--------|------|---------------------|---------------------------|-----------------|
| `report_result(table_monitor)` | 183 | `accumulate_results`, `reload`, `all_table_monitors_finished?`, `finalize_round`, `incr_current_round!`, `decr_current_round!`, `populate_tables`, `group_phase_finished?`, `finals_finished?`, `end_of_tournament!`, `start_playing_finals!`, `start_playing_groups!`, `tournament` | `write_game_result_data`, `finalize_game_result`, `accumulate_results`, `finalize_round`, `update_ranking`, `write_finale_csv_for_upload`, `populate_tables` | `TableMonitor#evaluate_result` (line 1465 via `tournament_monitor&.report_result(self)`) |
| `update_game_participations(tabmon)` | 5 | `update_game_participations_for_game` | `update_game_participations_for_game` | Called by `finalize_game_result` (internal to service) |
| `update_game_participations_for_game(game, data)` | 11 | `sets_to_play`, `tournament` | none | Called by `finalize_game_result` |
| `accumulate_results` | 88 | `tournament`, `innings_goal`, `data` (read + write), `data_will_change!`, `save!` | `add_result_to` | `report_result` (internal), `populate_tables` also calls this — **shared method** |
| `add_result_to(gp, hash)` | 140 | `tournament`, `innings_goal` | none | `accumulate_results` (internal) |
| `update_ranking` | 275 | `tournament`, `player_id_from_ranking`, `data`, `data_will_change!`, `save!` | `player_id_from_ranking` (stays on model — delegates to RankingResolver) | `report_result` (internal) |
| `write_finale_csv_for_upload` | 301 | `tournament`, `current_admin`, `current_user` | none | `report_result` (internal only — no other callers confirmed) |

**From `lib/tournament_monitor_state.rb`:**

| Method | Line | Self-refs to Convert | External Callers |
|--------|------|---------------------|-----------------|
| `write_game_result_data(table_monitor)` | 7 | `tournament`, `game.deep_merge_data!`, `game.save!` | `report_result` (internal to service) |
| `finalize_game_result(table_monitor)` | 45 | `tournament`, `update_game_participations_for_game`, `data`, `save!` | `report_result` (internal to service) |

**Critical finding — `accumulate_results` is shared:**
`report_result` calls `accumulate_results` (step after finalize_round). `populate_tables` also calls `accumulate_results` (for KO tournament ranking refresh at line 810). Decision D-08 says state query methods stay on the model. `accumulate_results` is a data-mutation method, not a query — but it's called by both services. **Resolution per D-09:** Move `accumulate_results` and `add_result_to` to ResultProcessor. TablePopulator calls `@tournament_monitor.accumulate_results` via delegation wrapper on the model. This is the same delegation pattern used everywhere.

---

### TablePopulator (TMEX-04) — Methods Moving from lib/ to Service

**From `lib/tournament_monitor_support.rb`:**

| Method | Line | Self-refs to Convert | Key Instance Vars |
|--------|------|---------------------|-----------------|
| `populate_tables` | 407 | `tournament`, `current_round`, `player_id_from_ranking`, `deep_merge_data!`, `save!`, `accumulate_results`, `reload`, `table_monitors`, `allow_change_tables` (cattr) | `@placements`, `@placement_candidates`, `@placements_done`, `@table`, `@table_monitor` |
| `do_placement(game, r_no, t_no, sets, balls, innings)` | 855 | `tournament`, `current_round`, `next_seqno`, `deep_merge_data!`, `data`, `allow_change_tables` (cattr), `table_monitors` | `@placements`, `@placement_candidates`, `@placements_done`, `@table`, `@table_monitor` |
| `initialize_table_monitors` | 370 | `tournament`, `table_monitors`, `save!`, `reload` | none |

**From `lib/tournament_monitor_state.rb`:**

| Method | Line | Self-refs to Convert | Key Logic |
|--------|------|---------------------|----------|
| `do_reset_tournament_monitor` | 201 | `tournament`, `update(...)`, `deep_merge_data!`, `save!`, `initialize_table_monitors`, `populate_tables`, `current_round!`, `data`, `@tournament_plan`, `@groups`, `@placements`, `start_playing_finals!`, `start_playing_groups!`, `signal_tournament_monitors_ready!` (on tournament) | Longest method (lines 201–521). Calls `populate_tables` and `initialize_table_monitors` internally. |

**`cattr_accessor` handling in TablePopulator:**
`populate_tables` sets `self.allow_change_tables = false` (line 410) and `do_placement` may set `self.allow_change_tables = true` (line 692). In the module, `self` is the TournamentMonitor instance — but `allow_change_tables` is a `cattr_accessor` (class-level, not instance-level). In the service, this must become `TournamentMonitor.allow_change_tables = false` / `true`. The semantics are unchanged since `cattr_accessor` creates both class and instance accessors that share the same class-level value.

---

## DB Lock Scope in `report_result`

The pessimistic lock wraps exactly:
1. `table_monitor.reload` + `game.reload` — refresh state
2. `write_game_result_data(table_monitor)` — write game data (idempotent, has guards)
3. `game.reload` + `table_monitor.reload` — clear association cache
4. `table_monitor.finish_match!` (AASM event on TableMonitor) — state transition

**Outside the lock (correct, intentional):**
- `finalize_game_result` — ClubCloud upload, game participation updates, KO cleanup
- `accumulate_results` — ranking recalculation
- AASM events on TournamentMonitor (`end_of_tournament!`, `start_playing_finals!`, etc.)
- `populate_tables` — table assignment

This scope must be preserved exactly in ResultProcessor. The `game.with_lock` block body is lines 207–225 in the current source. [VERIFIED: direct code reading]

---

## AASM Events Fired from Result Pipeline

All AASM events are called on `@tournament_monitor` (the model), NOT on the service. `after_enter` callbacks fire because AASM calls them on the model instance.

| Event Call | Location in `report_result` | After_enter Callback | What It Does |
|-----------|----------------------------|---------------------|-------------|
| `table_monitor.finish_match!` | Inside `game.with_lock` | TableMonitor `after_enter` (broadcasts) | Transitions TableMonitor to finished state |
| `end_of_tournament!` | After all rounds finished | TournamentMonitor: `after_update_commit :broadcast_status_update` | Fires Sidekiq broadcast job |
| `tournament.finish_tournament!` | After `end_of_tournament!` | Tournament model AASM | Tournament state transition |
| `tournament.have_results_published!` | After finish_tournament! | Tournament model AASM | Results publication state |
| `start_playing_finals!` | When group phase done but finals not done | `before_enter: :debug_log` only | Transitions to playing_finals |
| `start_playing_groups!` | When round finishes but group phase ongoing | `before_enter: :debug_log` only | Re-enters playing_groups |

**From `do_reset_tournament_monitor` (TablePopulator):**

| Event Call | On Object | After_enter Callback |
|-----------|-----------|---------------------|
| `start_playing_finals!` | `@tournament_monitor` | `before_enter: :debug_log` |
| `start_playing_groups!` | `@tournament_monitor` | `before_enter: :debug_log` |
| `tournament.signal_tournament_monitors_ready!` | `@tournament_monitor.tournament` | Tournament model |

---

## State Query Methods — Callers Analysis (D-08)

| Method | Location | Callers Outside Result/Populate Pipeline |
|--------|----------|----------------------------------------|
| `group_phase_finished?` | `tournament_monitor_state.rb:171` | `report_result` only — no views/controllers/reflexes found |
| `finals_finished?` | `tournament_monitor_state.rb:183` | `report_result` only — no views/controllers/reflexes found |
| `all_table_monitors_finished?` | `tournament_monitor_state.rb:115` | `report_result` AND `PartyMonitor#report_result` (line 323) |
| `table_monitors_ready?` | `tournament_monitor_state.rb:190` | Not called in any confirmed external caller in current code |
| `finalize_round` | `tournament_monitor_state.rb:120` | `report_result` AND `PartyMonitor#report_result` (line 324) |
| `accumulate_results` | `tournament_monitor_support.rb:88` | `report_result` AND `populate_tables` (KO path at line 810) |

**Finding:** `all_table_monitors_finished?` and `finalize_round` are called from `PartyMonitor` — they MUST stay on TournamentMonitor (or be delegated from it). D-08 is confirmed correct: these stay on the model/lib.

**Finding:** `group_phase_finished?` and `finals_finished?` appear to be called only from `report_result`. Per D-08, they may move to ResultProcessor — but the decision says "stay on model" unless only serving the populator. Since they serve the result pipeline only, this is Claude's discretion per D-08. Recommendation: **leave them on the model** for safety; the cost of moving is low, the risk of breaking PartyMonitor or future callers is not worth it.

---

## `do_reset_tournament_monitor` — Save Count Baseline

The method makes the following `save!`/`update`/`deep_merge_data!+save!` calls (must be preserved exactly per Pitfall 4 from PITFALLS.md):

1. `update(sets_to_play: ..., ...)` — initial settings sync (line 205)
2. `tournament.games.where(...).destroy_all` — game cleanup
3. `update(data: {}) unless new_record?` — data reset (line 222)
4. (conditional) `deep_merge_data!("error" => ...) + save!` — on seeding count == 0 error
5. (conditional) `deep_merge_data!("error" => ...) + save!` — on tournament_plan player mismatch
6. `deep_merge_data!("groups" => @groups, "placements" => @placements) + save!` — after group calc (line 268)
7. (conditional) `deep_merge_data!("error" => ...) + save!` — on executor_params validation errors
8. (conditional) `deep_merge_data!("error" => ...) + save!` — on game creation errors
9. `deep_merge_data!("error" => ...) + save!` — in outer rescue

Each `save!` inside the method creates a PaperTrail version (via ApiProtector, which has `has_paper_trail`). This is the existing behavior — do not reduce or increase saves.

---

## Common Pitfalls (Phase 15 Specific)

### Pitfall A: `populate_tables` calls `accumulate_results` — which service owns it?

**What goes wrong:** `accumulate_results` is called in `report_result` (line 235) and in `populate_tables` KO path (line 810). If both services extract it privately, it's duplicated. If only one extracts it, the other must delegate.

**How to avoid:** Move `accumulate_results` and `add_result_to` to ResultProcessor. The model's `accumulate_results` delegation wrapper calls `ResultProcessor.new(self).send(:accumulate_results)` — but that's awkward since it's private. Better: make `accumulate_results` a public method on ResultProcessor, and `do_placement`/`populate_tables` in TablePopulator call `@tournament_monitor.accumulate_results` (which delegates to the ResultProcessor). This is the same pattern as `player_id_from_ranking` → RankingResolver.

**Warning signs:** Two private `accumulate_results` methods with identical logic in both service files.

---

### Pitfall B: `@tournament_plan` ivar set in `do_reset_tournament_monitor` needed by `populate_tables`

**What goes wrong:** `do_reset_tournament_monitor` sets `@tournament_plan ||= tournament.tournament_plan` (line 223) before calling `populate_tables`. After extraction, both are on TablePopulator. `populate_tables` reads `executor_params = JSON.parse(tournament.tournament_plan.executor_params)` directly — it does NOT use `@tournament_plan`. So this is a non-issue: `populate_tables` fetches the plan independently. [VERIFIED: direct code reading lines 411, 278]

**Warning signs:** Assuming `@tournament_plan` is shared state between the two methods in the service.

---

### Pitfall C: `populate_tables` is called both from `do_reset_tournament_monitor` and from `report_result`

**What goes wrong:** `report_result` calls `populate_tables` at line 240: `populate_tables unless tournament.manual_assignment`. After extraction, `report_result` is in ResultProcessor and `populate_tables` is in TablePopulator. ResultProcessor cannot call TablePopulator's private method — it must call through the delegation wrapper: `@tournament_monitor.populate_tables`.

**How to avoid:** ResultProcessor calls `@tournament_monitor.populate_tables` (delegation wrapper on model). The model wrapper creates a TablePopulator instance. This creates a fresh service instance per call — which is correct because `@placements` etc. are re-loaded from `@tournament_monitor.data` at the start of `populate_tables`.

**Warning signs:** ResultProcessor directly instantiating `TablePopulator` — coupling between services. Always go through the model delegation wrapper.

---

### Pitfall D: `self.allow_change_tables = false` is a class-level cattr, not instance

**What goes wrong:** In the module, `self` is TournamentMonitor, so `self.allow_change_tables = false` is the same as `TournamentMonitor.allow_change_tables = false`. In the service, `self` is the service — this would set an undefined ivar or raise `NoMethodError`.

**How to avoid:** Replace `self.allow_change_tables = false` with `TournamentMonitor.allow_change_tables = false` in TablePopulator. Similarly for `self.allow_change_tables = true`.

---

### Pitfall E: `initialize_table_monitors` calls `self` (the TM model) as `tournament_monitor: self`

**What goes wrong:** Line 397: `table_monitor.update(tournament_monitor: self)`. In the service, `self` is TablePopulator. Must become `table_monitor.update(tournament_monitor: @tournament_monitor)`.

**How to avoid:** Grep for all literal `self` references in extracted methods before writing service code.

---

### Pitfall F: AASM `after_enter: [:do_reset_tournament_monitor]` calls the model method

**What goes wrong:** The AASM block calls `do_reset_tournament_monitor` as a symbol — which resolves to `self.do_reset_tournament_monitor`. After extraction, this model method must exist as a delegation wrapper. If the delegation wrapper is missing, the `after_enter` callback calls the original lib module method (if not yet removed), or raises `NoMethodError` if the lib module method was removed first.

**How to avoid:** Write the delegation wrapper on TournamentMonitor BEFORE removing the lib module method. Test order: (1) add delegation wrapper, (2) run characterization tests to confirm delegation works, (3) remove lib module method.

---

### Pitfall G: `try do` blocks in `populate_tables` and `do_placement`

**What goes wrong:** `populate_tables` (line 408) and `do_placement` (line 861) use `try do` — this is ActiveSupport's `Object#try`, which calls the block and rescues `NoMethodError`. It is NOT a begin/rescue block. In practice this acts as a nil-safe block executor. This must be preserved exactly in the service.

**How to avoid:** Do not refactor `try do` into `begin/rescue` during extraction. The `try` method is available in services because they inherit from Object (via Rails autoload). [VERIFIED: `try` appears at lines 186, 408, 861 in support.rb]

---

## Existing Service Pattern Reference

`TournamentMonitor::RankingResolver` is the closest pattern reference for the `@tournament_monitor` reference style. `app/services/tournament/table_reservation_service.rb` shows the ApplicationService pattern with external API calls (closest to ResultProcessor's ClubCloud upload in `finalize_game_result`).

Key difference from Phase 13-14 extractions: Phase 15 services have side effects (DB writes, AASM events, Sidekiq jobs), so they use ApplicationService base class, not plain PORO. [VERIFIED: app/services/application_service.rb — `def self.call(kwargs = {}); new(kwargs).call; end`]

However, both services accept a single `tournament_monitor` argument, not a kwargs hash. The `call` class method on ApplicationService expects `kwargs = {}`. Options:
- Add `def self.call_with(tournament_monitor)` class method, OR
- Use `new(tournament_monitor)` directly (callers always use `new(self).method_name(args)` pattern like RankingResolver), OR
- Follow RankingResolver: don't inherit ApplicationService, just be a plain class with `def initialize(tournament_monitor)`

**Recommendation (Claude's Discretion):** Follow RankingResolver pattern (plain class, no ApplicationService inheritance) since the entry points are multiple public methods (`report_result`, `accumulate_results`, `do_reset_tournament_monitor`, `populate_tables`), not a single `call`. ApplicationService's `call` pattern fits single-entry services. [ASSUMED — consistent with Phase 13-14 decisions but not explicitly re-confirmed for Phase 15]

---

## Delegation Wrappers Needed on TournamentMonitor Model

After extraction, the following delegation wrappers must be added to `app/models/tournament_monitor.rb` (and existing lib module methods removed):

**For ResultProcessor:**
```ruby
def report_result(table_monitor)
  TournamentMonitor::ResultProcessor.new(self).report_result(table_monitor)
end

def update_game_participations(tabmon)
  TournamentMonitor::ResultProcessor.new(self).update_game_participations(tabmon)
end

def accumulate_results
  TournamentMonitor::ResultProcessor.new(self).accumulate_results
end

def update_ranking
  TournamentMonitor::ResultProcessor.new(self).update_ranking
end
```

**For TablePopulator:**
```ruby
def do_reset_tournament_monitor
  TournamentMonitor::TablePopulator.new(self).do_reset_tournament_monitor
end

def populate_tables
  TournamentMonitor::TablePopulator.new(self).populate_tables
end

def initialize_table_monitors
  TournamentMonitor::TablePopulator.new(self).initialize_table_monitors
end
```

**Note:** `write_game_result_data`, `finalize_game_result`, `add_result_to`, `write_finale_csv_for_upload` are internal to ResultProcessor — no delegation wrapper needed since they are not called externally.

---

## Lib Module Fate After Extraction

**`lib/tournament_monitor_support.rb` — What remains after Phase 15:**
- The entire file is extracted: `update_game_participations`, `update_game_participations_for_game`, `accumulate_results`, `add_result_to`, `report_result`, `update_ranking`, `write_finale_csv_for_upload`, `initialize_table_monitors`, `populate_tables`, `do_placement` all leave.
- **Result: File should be empty or contain only the module declaration.** Per D-11, if empty, remove entirely.

**`lib/tournament_monitor_state.rb` — What remains after Phase 15:**
- Leaves: `write_game_result_data`, `finalize_game_result`, `do_reset_tournament_monitor`
- Stays: `all_table_monitors_finished?`, `finalize_round`, `group_phase_finished?`, `finals_finished?`, `table_monitors_ready?`
- **Result: Smaller but not empty.** File should be retained, now 5 methods (~100 lines).

---

## Characterization Tests — Scope Verification

All three characterization test files must pass unchanged:

| Test File | State Machine Path Covered | Result Pipeline Methods Exercised |
|-----------|---------------------------|----------------------------------|
| `test/models/tournament_monitor_t04_test.rb` | Group play flow, `start_playing_groups!`, `start_playing_finals!` | `accumulate_results` implicitly via state transitions |
| `test/models/tournament_monitor_t06_test.rb` | Group + finals, `write_game_result_data`, `accumulate_results`, `group_phase_finished?` | Full result pipeline including `finalize_game_result` path |
| `test/models/tournament_monitor_ko_test.rb` | KO bracket, `player_id_from_ranking`, `do_reset_tournament_monitor` | `populate_tables` for initial KO game creation |

**Test environment limitation (pinned behavior):** `do_reset_tournament_monitor` in test env destroys games with `id >= MIN_ID` then counts `id >= MIN_ID` games — always finds 0. This causes the method to return an ERROR hash in tests. Tests that need `playing_groups` state call `start_playing_groups!` directly. This limitation applies identically to the extracted service — no change needed.

**New unit tests needed (per D-10):**
```
test/services/tournament_monitor/result_processor_test.rb
test/services/tournament_monitor/table_populator_test.rb
```

These should test the service's public interface mirrors the model's delegation. Integration covered by existing characterization tests.

---

## Environment Availability

Step 2.6: SKIPPED (no external CLI dependencies — all dependencies are Ruby gems already present in Gemfile.lock)

---

## Validation Architecture

Step 4: SKIPPED — `workflow.nyquist_validation` is explicitly `false` in `.planning/config.json`.

---

## Security Domain

This phase performs code refactoring only — no new input handling, no new authentication paths, no new data exposure. AASM transitions and DB locking patterns are unchanged; only their file location changes.

`security_enforcement` not explicitly set to false in config, but no new ASVS-relevant controls are introduced. The existing `game.with_lock` pessimistic locking (V1 — Concurrency) is preserved exactly.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `accumulate_results` and `add_result_to` should move to ResultProcessor, not be duplicated | Method-by-Method Map | TablePopulator would need its own copy or a different delegation path — low risk, easy to adjust |
| A2 | Both services should be plain classes (not ApplicationService), matching RankingResolver pattern | Architecture Patterns | Could use ApplicationService — does not affect behavior, only `call` class method convention |
| A3 | `write_game_result_data`, `finalize_game_result`, `add_result_to`, `write_finale_csv_for_upload` need no delegation wrappers (internal only) | Delegation Wrappers | If any external caller exists and was missed by grep, the wrapper would be needed |

---

## Open Questions

1. **`finalize_round` ownership:** Currently called from `report_result` (ResultProcessor) AND from `PartyMonitor`. The method stays on the model per D-08. But `finalize_round` calls `accumulate_results` (line 168 in state.rb), which will move to ResultProcessor. After extraction, the model's `finalize_round` calls `@tournament_monitor_instance.accumulate_results` — which delegates to ResultProcessor. This is correct and self-consistent.

2. **`update_game_participations` vs `update_game_participations_for_game`:** The former delegates to the latter (wrapper for backward compatibility). Both move to ResultProcessor. External callers: only `finalize_game_result` (which is also in ResultProcessor). No external delegation wrapper needed.

3. **`write_finale_csv_for_upload` uses `respond_to?(:current_admin)`:** The method checks `respond_to?(:current_admin) && current_admin.present?` — this uses TournamentMonitor's `cattr_accessor :current_admin`. In the service, `respond_to?(:current_admin)` would be false (service doesn't define it). Must become `TournamentMonitor.respond_to?(:current_admin) && TournamentMonitor.current_admin.present?` — or more directly, `TournamentMonitor.current_admin.present?`.

---

## Sources

### Primary (HIGH confidence)
- Direct code reading: `lib/tournament_monitor_support.rb` (1078 lines, all sections) — verified method locations, self-references, callers
- Direct code reading: `lib/tournament_monitor_state.rb` (522 lines, full file) — verified method locations, AASM callback entry point
- Direct code reading: `app/models/tournament_monitor.rb` (181 lines) — AASM block, delegation pattern, cattr_accessors
- Direct code reading: `app/services/tournament_monitor/ranking_resolver.rb` — established `@tournament_monitor` reference pattern
- Direct code reading: `app/services/application_service.rb` — ApplicationService base class shape
- Direct code reading: `app/models/table_monitor.rb` (lines 1465, 1499) — report_result caller confirmed
- Direct code reading: `app/models/party_monitor.rb` (lines 277, 323, 324, 360, 570-571) — `finalize_round` and `all_table_monitors_finished?` cross-caller confirmed
- Direct code reading: `.planning/research/PITFALLS.md` — Pitfall 4 (data JSON atomicity), Pitfall 9 (AASM after_enter cascade), Pitfall 10 (cattr_accessor leakage)
- Direct code reading: `.planning/phases/15-high-risk-extractions/15-CONTEXT.md` — locked decisions D-01 through D-11

### Secondary (MEDIUM confidence)
- Direct code reading: `app/reflexes/table_monitor_reflex.rb` (lines 164, 222, 281) — confirmed report_result is not called directly from reflexes; TableMonitor#evaluate_result is the entry point

---

## Metadata

**Confidence breakdown:**
- Method extraction map: HIGH — based on direct line-by-line code reading of both lib files
- Self-reference conversion list: HIGH — enumerated from actual method bodies
- DB lock scope: HIGH — commented explicitly in source with race condition rationale
- AASM event sequence: HIGH — read from model AASM block and report_result flow
- Shared method ownership: HIGH — grep confirmed all external callers
- Service pattern recommendation (PORO vs ApplicationService): MEDIUM — training knowledge + codebase pattern consistency

**Research date:** 2026-04-10
**Valid until:** Stable — no external APIs; code-only research against a frozen codebase snapshot
