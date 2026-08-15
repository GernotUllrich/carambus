# Phase 5: TableMonitor ResultRecorder & Final Cleanup - Research

**Researched:** 2026-04-09
**Domain:** Rails model extraction — ApplicationService pattern, AASM callback delegation, ScoreEngine delegation wiring
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** ResultRecorder is an ApplicationService subclass using `.call(table_monitor:, **opts)` pattern. Rationale: it creates/updates database records (save_result writes Game data, evaluate_result triggers AASM events + save!) — this is a one-shot operation with side effects, matching the GameSetup pattern, not the stateless ScoreEngine PORO pattern.
- **D-02:** ResultRecorder handles: `save_result`, `save_current_set`, `evaluate_result`, `switch_to_next_set`, `get_max_number_of_wins`. All result-related persistence logic moves into the service.
- **D-03:** ResultRecorder calls AASM events directly on the model via `@tm.finish_match!` and `@tm.end_of_set!`. Unlike ScoreEngine (which returns signals because it's a pure data PORO), ResultRecorder is already an AR-aware service that calls `@tm.save!`. Direct AASM event calls are simpler and match the existing code path exactly — no behavioral change risk.
- **D-04:** After AASM events fire, after_enter callbacks (set_game_over, set_start_time, set_end_time) execute on the model as before. ResultRecorder does NOT call CableReady directly — broadcasts happen through the existing after_update_commit callback chain.
- **D-05:** To hit <800 lines, the final cleanup must go beyond just ResultRecorder extraction (~200 lines). Additional cleanup includes:
  - Wire remaining undelegated ScoreEngine methods (8 methods identified in Phase 3 VERIFICATION.md warnings: update_innings_history, increment_inning_points, decrement_inning_points, delete_inning, insert_inning, recalculate_player_stats, update_player_innings_data, calculate_running_totals)
  - Remove dead code and inline helpers that are only called from already-extracted methods
  - Consolidate remaining orchestrator methods that call multiple services
- **D-06:** The 800-line target is a hard gate. If mechanical extraction doesn't reach it, additional method delegation to existing services (ScoreEngine, GameSetup) is in scope.
- **D-07:** All 4 extracted services (ScoreEngine, GameSetup, OptionsPresenter, ResultRecorder) must have passing unit tests. Characterization tests remain the regression safety net. No new characterization tests needed — Phase 1 tests cover the critical paths.
- **D-08:** Run Reek on table_monitor.rb after all cleanup. Compare against Phase 1 baseline (781 warnings). Save post-extraction report to `.planning/reek_post_extraction_table_monitor.txt`.

### Claude's Discretion

- Exact method split for remaining undelegated methods
- Whether to create additional small helper services or fold remaining methods into existing services
- Dead code identification and removal
- Internal organization of ResultRecorder (private method structure)

### Deferred Ideas (OUT OF SCOPE)

None — this is the final phase of the v1.0 milestone.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TMON-03 | Extract ResultRecorder service (result persistence + AASM event dispatch) | D-01 through D-04; file location, pattern, delegation wiring fully researched |
| TMON-06 | Full test coverage for all extracted TableMonitor services | D-07; test file locations, patterns, and DB setup requirements documented |
</phase_requirements>

---

## Summary

Phase 5 closes the extraction program for TableMonitor. The primary deliverable is `TableMonitor::ResultRecorder`, an ApplicationService (matching the GameSetup pattern) that absorbs five result-persistence methods from the model: `save_result`, `save_current_set`, `get_max_number_of_wins`, `switch_to_next_set`, and `evaluate_result`. A secondary deliverable is wiring thin delegation wrappers for eight methods that already exist in ScoreEngine but remain as duplicate full implementations in TableMonitor.

**Critical planning discovery:** The mechanical extraction of ResultRecorder + 8 ScoreEngine delegations saves approximately 699 net lines, reducing TableMonitor from 2544 to approximately 1845 lines. The 800-line hard gate (D-06) requires an additional ~1045 lines of reduction. The CONTEXT explicitly acknowledges this via D-06 ("additional method delegation to existing services is in scope"), but the gap is large enough that the planner must identify and plan a third wave of delegation targeting the largest remaining methods (see Architecture Patterns below). The planner should surface this math clearly so the user can confirm scope before execution.

**AASM callback safety:** Research confirms no spike test is needed. When ResultRecorder calls `@tm.end_of_set!` or `@tm.finish_match!`, AASM fires `after_enter` callbacks (`set_game_over`, `set_end_time`) on the `@tm` instance regardless of call site. This is standard Ruby/AASM behavior — callbacks are registered on the instance, not the caller.

**Primary recommendation:** Follow the three-wave structure: (1) create ResultRecorder service + unit tests, (2) wire ResultRecorder delegation in TableMonitor, (3) wire 8 ScoreEngine delegations. Then measure line count and plan additional delegation per D-06 until <800.

---

## Standard Stack

### Core (established in earlier phases)

| Component | Version/Location | Purpose | Why Standard |
|-----------|-----------------|---------|--------------|
| `ApplicationService` | `app/services/application_service.rb` | Base class for AR-aware one-shot services | Established pattern; GameSetup already uses it |
| `AASM` | `aasm 5.5.2` (Gemfile) | State machine on TableMonitor | Pre-existing; cannot change |
| Minitest | Rails 7.2 built-in | Test framework | Project standard (not RSpec) |
| FactoryBot (optional) | `factory_bot_rails` | Test data | Used in characterization tests; GameSetup test uses `Player.create!` directly |

### Established Patterns (must reuse)

| Pattern | Reference | Notes |
|---------|-----------|-------|
| ApplicationService subclass | `app/services/table_monitor/game_setup.rb` | ResultRecorder MUST follow this exactly |
| Lazy accessor delegation | `TableMonitor#score_engine` (line 381) | Use same pattern for `result_recorder` accessor |
| Thin AR-wrapper delegation | `start_game`, `assign_game` (1-line wrappers) | Model keeps public API; delegates to service |
| ScoreEngine delegation (pure data + save) | existing `balls_left`, `foul_one`, `add_n_balls` | Pattern for the 8 undelegated methods |
| Test DB setup without fixtures | `game_setup_test.rb` setup block | `Player.create!` + `TableMonitor.create!` directly |

---

## Architecture Patterns

### File Locations

```
app/
├── services/
│   └── table_monitor/
│       ├── game_setup.rb            # EXISTS - reference pattern
│       └── result_recorder.rb       # CREATE in this phase
├── models/
│   └── table_monitor/
│       ├── score_engine.rb          # EXISTS - already has all 8 methods
│       └── options_presenter.rb     # EXISTS

test/
├── services/
│   └── table_monitor/
│       ├── game_setup_test.rb       # EXISTS
│       └── result_recorder_test.rb  # CREATE in this phase
├── models/
│   └── table_monitor/
│       ├── score_engine_test.rb     # EXISTS
│       └── options_presenter_test.rb # EXISTS
└── characterization/
    └── table_monitor_char_test.rb   # EXISTS - regression safety net (41 tests)
```

### Pattern 1: ResultRecorder as ApplicationService (D-01)

ResultRecorder follows the GameSetup pattern exactly. It receives the model instance, holds it as `@tm`, and calls methods directly on it.

```ruby
# Source: app/services/table_monitor/game_setup.rb (reference)
# File: app/services/table_monitor/result_recorder.rb

# frozen_string_literal: true

class TableMonitor::ResultRecorder < ApplicationService
  def initialize(kwargs = {})
    @tm = kwargs[:table_monitor]
  end

  # Used for evaluate_result dispatch
  def call
    perform_evaluate_result
  end

  private

  def perform_evaluate_result
    # Moves evaluate_result body here; calls @tm.end_of_set!, @tm.save!, etc.
    # No CableReady calls — broadcasts via after_update_commit on @tm
  end

  def perform_save_result
    # Moves save_result body here
  end

  def perform_save_current_set
    # Moves save_current_set body here
  end

  # ... etc.
end
```

**Key design constraint:** ResultRecorder does NOT call CableReady directly (D-04). The existing `after_update_commit` broadcast chain on TableMonitor fires automatically after `@tm.save!`.

### Pattern 2: AASM Event Calls from Service Context (D-03)

AASM events called on `@tm` from inside ResultRecorder fire `after_enter` callbacks on `@tm` exactly as if called from within the model. No special handling required.

```ruby
# In ResultRecorder#perform_evaluate_result:
@tm.end_of_set!
# → AASM fires: after_enter :set_game_over (for :set_over state)
# → set_game_over calls @tm.save (soft save) — this is fine before ResultRecorder's own save!

@tm.finish_match!
# → AASM fires: after: :set_end_time
# → set_end_time updates game.ended_at — also fine
```

**Verified:** [VERIFIED: codebase grep] AASM after_enter callbacks (`set_game_over` at line 455, `set_end_time` at line 723) both use soft `save` or `assign_attributes` — they do not conflict with ResultRecorder's subsequent `save!` calls.

### Pattern 3: Multiple Entry Points on ResultRecorder

ResultRecorder handles five logically related but separately callable operations. The `call` method handles `evaluate_result` (the primary flow). Named class methods or a `:action` keyword provide access to other operations:

```ruby
# Option A: Action-keyed entry points (matches context)
TableMonitor::ResultRecorder.call(table_monitor: @tm)  # evaluate_result
TableMonitor::ResultRecorder.save_result(table_monitor: @tm)
TableMonitor::ResultRecorder.save_current_set(table_monitor: @tm)

# Option B: Single service with method delegation from TM wrappers
# TM keeps thin wrappers; each calls ResultRecorder with action param
```

**Claude's Discretion:** The internal organization of ResultRecorder. Option A (multiple class-method entry points, as in `GameSetup.assign`) is the recommended approach matching the established pattern.

### Pattern 4: TableMonitor Delegation Wrappers

After extraction, TableMonitor keeps the public method signatures but delegates to ResultRecorder:

```ruby
# In TableMonitor (thin wrappers):
def evaluate_result
  TableMonitor::ResultRecorder.call(table_monitor: self)
end

def save_result
  TableMonitor::ResultRecorder.save_result(table_monitor: self)
end

def save_current_set
  TableMonitor::ResultRecorder.save_current_set(table_monitor: self)
end

def get_max_number_of_wins
  TableMonitor::ResultRecorder.get_max_number_of_wins(table_monitor: self)
end

def switch_to_next_set
  TableMonitor::ResultRecorder.switch_to_next_set(table_monitor: self)
end
```

**Critical:** Reflexes call `@table_monitor.evaluate_result` (7 call sites in `table_monitor_reflex.rb`, 1 in `game_protocol_reflex.rb`). The TM public method MUST be preserved. [VERIFIED: codebase grep]

### Pattern 5: ScoreEngine Delegation for 8 Undelegated Methods

The 8 methods identified in Phase 3 VERIFICATION.md already have full implementations in `ScoreEngine` [VERIFIED: codebase grep of `score_engine.rb` lines 678-960]. The TableMonitor versions are duplicates with AR persistence (`data_will_change!`, `save!`) added. The delegation pattern replaces ~435 lines with ~40 thin wrapper lines:

```ruby
# BEFORE (in TableMonitor, ~100 lines per method):
def update_innings_history(innings_params)
  return { success: false, error: 'Not in playing state' } unless playing? || set_over?
  # ... 140 lines of hash mutation logic ...
  data_will_change!
  save!
  { success: true }
end

# AFTER (thin AR wrapper, ~6 lines):
def update_innings_history(innings_params)
  result = score_engine.update_innings_history(innings_params, playing_or_set_over: playing? || set_over?)
  return result unless result[:success]
  data_will_change!
  save!
  result
end
```

**Verified for all 8 methods:** ScoreEngine has `update_innings_history(innings_params, playing_or_set_over:)`, `increment_inning_points`, `decrement_inning_points`, `delete_inning`, `insert_inning`, `recalculate_player_stats(player, save_now: false)`, `update_player_innings_data`, `calculate_running_totals`. [VERIFIED: codebase grep]

**Note on `recalculate_player_stats`:** Currently private in TableMonitor (`private` section starts at line 2399; `recalculate_player_stats` is at line 2404). Called from `increment_inning_points` and `decrement_inning_points` within TM. After delegation, TM's version can be removed entirely — ScoreEngine handles it internally.

### Pattern 6: 800-Line Gap Analysis (Critical for Planning)

| Extraction | Lines Removed from TM | Replacement Lines | Net Saving |
|------------|----------------------|-------------------|------------|
| ResultRecorder (5 methods) | ~319 (lines 1482–1800) | ~15 delegation wrappers | ~304 |
| 8 ScoreEngine delegations | ~435 (lines 2047–2481) | ~40 thin wrappers | ~395 |
| **Total mechanical** | **~754** | **~55** | **~699** |

**Result:** 2544 − 699 = **~1845 lines remaining** after mechanical extraction.
**Target:** <800 lines.
**Gap:** ~1045 additional lines must be removed via D-06 "additional method delegation."

**Largest remaining method candidates (Claude's Discretion):**

| Method | Lines | AR-coupled? | Delegation Path |
|--------|-------|-------------|-----------------|
| `initialize_game` | ~196 | Yes (reads associations, calls `deep_merge_data!`) | Move body into `GameSetup#perform_start_game` (already called from there); TM keeps 1-line wrapper |
| `terminate_current_inning` | ~114 | Yes (`data_will_change!`, `save!`, `evaluate_result`) | Hash mutation portion → new `ScoreEngine#terminate_inning_data`; TM wrapper does `data_will_change!; save!; evaluate_result` |
| `evaluate_panel_and_current` | ~82 | Reads self attrs, no save | Could move to OptionsPresenter or stay as internal |
| Logging-only methods (`log_state_transition`, `log_state_change`) | ~40 | No writes | Inline or reduce emoji/debug logs |

**Even with all four candidates above delegated:** 1845 − (196+114+82+40) = ~1413 lines. Still above 800.

**The planner must flag this to the user.** The 800-line target as a hard gate in a single phase appears infeasible given the current state of the model. The planner should present options: (a) accept ~1200–1400 as the realistic outcome of this phase with the planned extractions, or (b) expand scope to additional extractions not yet planned (redo/undo logic, timer methods, etc.).

### Anti-Patterns to Avoid

- **CableReady in ResultRecorder:** D-04 explicitly prohibits this. Broadcasts happen via `after_update_commit` on the model.
- **Duplicating AASM transition logic:** ResultRecorder calls existing events (`end_of_set!`, `finish_match!`) — never copy the transition guard logic.
- **Making ResultRecorder stateful:** It should be a one-shot service. No instance variables that persist between calls.
- **Moving evaluate_result guard logic into TM wrapper:** The guard (`game&.started_at.present? && ...`) should stay inside ResultRecorder where it can be unit-tested.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| AASM event dispatch from service | Custom callback firing | `@tm.end_of_set!` directly | AASM fires after_enter on instance; no custom plumbing needed |
| Result hash accumulation | Custom merge logic | Existing `deep_merge_data!` on `@tm` | Already handles jsonb mutation marking |
| Test database isolation | Custom teardown | Rails transactional fixtures | Already configured in test_helper |
| ScoreEngine delegation | Rewriting hash logic | `score_engine.method_name(args)` | ScoreEngine already has all 8 methods — verified |

---

## Common Pitfalls

### Pitfall 1: Double Save from AASM Callback + ResultRecorder
**What goes wrong:** `@tm.end_of_set!` triggers `set_game_over` which calls `@tm.save`. ResultRecorder then also calls `@tm.save!`. Developers worry this is a bug.
**Why it happens:** `set_game_over` uses soft `save` (no exception on failure). ResultRecorder uses `save!`. They are independent saves.
**How to avoid:** This is correct behavior — no change needed. The `set_game_over` save persists the `panel_state` change from the AASM callback; the ResultRecorder `save!` persists the result data.
**Warning signs:** If you see `save` removed from `set_game_over` to "avoid double save," that's a bug.

### Pitfall 2: evaluate_result Recursion Risk
**What goes wrong:** `evaluate_result` calls `switch_to_next_set` which calls `save!` and `evaluate_result` (in terminate_current_inning path). If the delegation chain is incomplete, you get infinite recursion.
**Why it happens:** The existing code uses `return` after `switch_to_next_set` to prevent recursion. This must be preserved in ResultRecorder.
**How to avoid:** Mirror all `return` statements in the evaluate_result body exactly. The characterization tests will catch any regression.
**Warning signs:** Stack overflow errors in test or development.

### Pitfall 3: ScoreEngine Delegation — `save_now` Parameter Mismatch
**What goes wrong:** `recalculate_player_stats` in TableMonitor accepts `save_now: true` (default). ScoreEngine version has `save_now: false` (with `# rubocop:disable Lint/UnusedMethodArgument` because SE never saves). The TM delegation wrapper must absorb the save responsibility.
**How to avoid:** TM wrapper ignores the ScoreEngine's `save_now` param entirely; TM wrapper always calls `data_will_change!; save!` after ScoreEngine mutates the hash.
**Warning signs:** Tests that call `recalculate_player_stats(player, save_now: false)` still expecting no save.

### Pitfall 4: `update_innings_history` — Duplicate Implementation Gap
**What goes wrong:** The TM version of `update_innings_history` (line 2047) and the ScoreEngine version (line 678) were evolved independently. They have minor differences (single/double quotes, some logging). The TM must call ScoreEngine and not re-add TM-side logic.
**How to avoid:** After delegation, run the characterization tests immediately. The ScoreEngine version was verified as functionally equivalent in Phase 3.

### Pitfall 5: `TableMonitor::DEBUG` References in Reflexes
**What goes wrong:** `game_protocol_reflex.rb` has 19 occurrences of `TableMonitor::DEBUG`. The constant was removed from TableMonitor in Phase 3. This causes a `NameError` in production if not addressed.
**Why it matters now:** This is pre-existing dead code that may be cleaned up during the "remove dead code" step of D-05.
**How to avoid:** If touching `game_protocol_reflex.rb` for delegation wiring, replace `if TableMonitor::DEBUG` guards with `Rails.logger.debug { ... }` blocks (established TMON-05 pattern).

### Pitfall 6: Line Count Math — 800-Line Target
**What goes wrong:** Planning assumes ResultRecorder + 8 ScoreEngine delegations achieves <800 lines.
**Reality:** Mechanical extractions reduce TM from 2544 to ~1845. An additional ~1045 lines must come from further delegation or elimination. This requires explicit scope decision from user.
**How to avoid:** Planner must present the gap analysis and options before locking the plan.

---

## Code Examples

### ResultRecorder — Class Skeleton

```ruby
# frozen_string_literal: true
# Source: app/services/table_monitor/game_setup.rb (reference pattern)

# Kapselt die Ergebnis-Persistierung und AASM-Event-Ausloesung aus TableMonitor.
# Verantwortlichkeiten:
#   - save_result: Satz-Ergebnis-Hash aufbauen und in data["sets"] schreiben
#   - save_current_set: Satz finalisieren und data["sets"] anhaengen
#   - evaluate_result: Spielende-Erkennung, AASM-Events ausloesen, Weiterleitung
#   - switch_to_next_set: Naechsten Satz initialisieren
#   - get_max_number_of_wins: Maximale Satzsiege ermitteln
#
# Kein CableReady-Zugriff — Broadcasts laufen ueber den after_update_commit-Callback des Modells.
class TableMonitor::ResultRecorder < ApplicationService
  def initialize(kwargs = {})
    @tm = kwargs[:table_monitor]
  end

  # Haupteinstieg fuer evaluate_result-Delegation
  def call
    perform_evaluate_result
  end

  # Klassenmethod-Einstiegspunkte fuer separate Operationen (wie GameSetup.assign)
  def self.save_result(table_monitor:)
    new(table_monitor: table_monitor).perform_save_result
  end

  def self.save_current_set(table_monitor:)
    new(table_monitor: table_monitor).perform_save_current_set
  end

  def self.get_max_number_of_wins(table_monitor:)
    new(table_monitor: table_monitor).perform_get_max_number_of_wins
  end

  def self.switch_to_next_set(table_monitor:)
    new(table_monitor: table_monitor).perform_switch_to_next_set
  end

  private

  def perform_evaluate_result; end
  def perform_save_result; end
  def perform_save_current_set; end
  def perform_get_max_number_of_wins; end
  def perform_switch_to_next_set; end
end
```

### TableMonitor — Delegation Wrappers

```ruby
# Source: app/models/table_monitor.rb (matching start_game pattern at line 1802)
def evaluate_result
  TableMonitor::ResultRecorder.call(table_monitor: self)
end

def save_result
  TableMonitor::ResultRecorder.save_result(table_monitor: self)
end

def save_current_set
  TableMonitor::ResultRecorder.save_current_set(table_monitor: self)
end

def get_max_number_of_wins
  TableMonitor::ResultRecorder.get_max_number_of_wins(table_monitor: self)
end

def switch_to_next_set
  TableMonitor::ResultRecorder.switch_to_next_set(table_monitor: self)
end
```

### ScoreEngine Delegation — AR Wrapper Pattern

```ruby
# Source: existing pattern from add_n_balls (line 1003) and balls_left (line 961)
def update_innings_history(innings_params)
  result = score_engine.update_innings_history(
    innings_params,
    playing_or_set_over: playing? || set_over?
  )
  return result unless result[:success]
  data_will_change!
  save!
  result
rescue StandardError => e
  Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
  { success: false, error: e.message }
end

def increment_inning_points(inning_index, player)
  return unless playing? || set_over?
  score_engine.increment_inning_points(inning_index, player)
  data_will_change!
  save!
rescue StandardError => e
  Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
end
```

### ResultRecorder Unit Test — Setup Pattern

```ruby
# Source: test/services/table_monitor/game_setup_test.rb (reference)
class TableMonitor::ResultRecorderTest < ActiveSupport::TestCase
  setup do
    # cattr_accessor leak prevention (same as GameSetupTest)
    TableMonitor.options = nil
    # ...

    @player_a = Player.create!(id: 50_000_003, firstname: "A", lastname: "B", dbu_nr: 10003)
    @player_b = Player.create!(id: 50_000_004, firstname: "C", lastname: "D", dbu_nr: 10004)

    @game = Game.new
    @game.save(validate: false)

    GameParticipation.create!(game: @game, player: @player_a, role: "playera")
    GameParticipation.create!(game: @game, player: @player_b, role: "playerb")

    @tm = TableMonitor.create!(state: "playing", game: @game, data: standard_playing_data)
  end

  def standard_playing_data(overrides = {})
    {
      "playera" => { "result" => 50, "innings" => 5, "innings_list" => [10,10,10,10], "innings_redo_list" => [10], "hs" => 10, "gd" => "10.00" },
      "playerb" => { "result" => 30, "innings" => 5, "innings_list" => [6,6,6,6], "innings_redo_list" => [6], "hs" => 6, "gd" => "6.00" },
      "sets_to_win" => 1, "sets_to_play" => 1,
      "ba_results" => { "Sets1" => 0, "Sets2" => 0 }
    }.deep_merge(overrides)
  end
end
```

### Reek Final Measurement

```bash
# Source: .planning/STATE.md — Reek globally installed as /Users/gullrich/.rbenv/shims/reek
reek app/models/table_monitor.rb > .planning/reek_post_extraction_table_monitor.txt
wc -l .planning/reek_post_extraction_table_monitor.txt
# Compare: baseline was 781 warnings (.planning/reek_baseline_table_monitor.txt)
```

---

## State of the Art

| Old Approach | Current Approach | Changed | Impact |
|--------------|------------------|---------|--------|
| All result logic in TableMonitor | ResultRecorder ApplicationService | Phase 5 | Testable in isolation without AASM state setup |
| 8 methods duplicated in TM and ScoreEngine | TM delegates to ScoreEngine; ScoreEngine is source of truth | Phase 5 | Single implementation; TM is thin orchestrator |
| TableMonitor 2544 lines | Target <800 (realistic: ~1200–1500) | Phase 5 | God object decomposed |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Mechanical extraction reaches ~1845 lines (not 800) as shown by line count analysis | Architecture Patterns / Pitfall 6 | If wrong: target is achievable without additional scope — but math is verified against actual file [VERIFIED: codebase grep] |
| A2 | `recalculate_player_stats` can be fully removed from TM (it's currently private, called only from other private methods) | Architecture Patterns | If wrong: caller sites exist in public TM interface — check `grep` before removing |

---

## Open Questions

1. **800-line target feasibility**
   - What we know: Mechanical extraction (ResultRecorder + 8 SE delegations) reaches ~1845 lines, not 800
   - What's unclear: Whether user intended the full extraction of additional large methods (initialize_game, terminate_current_inning) in this phase, or whether the 800-line target was aspirational
   - Recommendation: Planner presents math, user confirms scope before plan is locked. D-06 explicitly allows additional delegation — the question is how much.

2. **`game_protocol_reflex.rb` DEBUG constant cleanup**
   - What we know: 19 occurrences of `if TableMonitor::DEBUG` in `game_protocol_reflex.rb` that reference a removed constant
   - What's unclear: Whether this causes runtime errors currently or is guarded by constant existence check
   - Recommendation: Check if `TableMonitor::DEBUG` raises `NameError` or returns nil. If the constant no longer exists, these are live bugs. Clean during the dead-code pass.

---

## Environment Availability

Step 2.6: SKIPPED — this phase is code/refactoring changes only. External dependencies (Reek) already verified:

| Dependency | Required By | Available | Version |
|------------|------------|-----------|---------|
| Reek | D-08 final measurement | ✓ | 6.5.0 (at `/Users/gullrich/.rbenv/shims/reek`) |
| Rails test suite | D-07 unit tests | ✓ | Rails 7.2 (`bin/rails test`) |

---

## Sources

### Primary (HIGH confidence)
- `app/models/table_monitor.rb` — read directly; all line numbers and method sizes verified
- `app/models/table_monitor/score_engine.rb` — verified all 8 target methods exist at lines 678–960
- `app/services/table_monitor/game_setup.rb` — reference pattern for ResultRecorder design
- `test/services/table_monitor/game_setup_test.rb` — reference pattern for ResultRecorder test setup
- `app/reflexes/table_monitor_reflex.rb` — verified 7 `evaluate_result` call sites
- `app/reflexes/game_protocol_reflex.rb` — verified 1 `evaluate_result` call site + 4 ScoreEngine method call sites
- `.planning/phases/05-tablemonitor-resultrecorder-final-cleanup/05-CONTEXT.md` — user decisions D-01 through D-08
- `.planning/phases/03-tablemonitor-scoreengine/03-VERIFICATION.md` — confirmed 8 undelegated method list
- `.planning/reek_baseline_table_monitor.txt` — 781 warnings baseline confirmed
- `bin/rails test` — characterization tests: 41 runs, 75 assertions, 0 failures (verified live)
- `bin/rails test test/models/table_monitor/ test/services/table_monitor/` — 90 runs, 171 assertions, 0 failures (verified live)

---

## Metadata

**Confidence breakdown:**
- ResultRecorder design: HIGH — direct model code read, established GameSetup reference pattern
- ScoreEngine delegation wiring: HIGH — verified all 8 target methods exist in ScoreEngine
- AASM callback safety: HIGH — characterization tests already cover after_enter behavior
- 800-line gap analysis: HIGH — direct line count measurement with math

**Research date:** 2026-04-09
**Valid until:** End of Phase 5 execution (code is stable; no external dependencies)
