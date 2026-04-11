# Phase 22: PartyMonitor Extraction - Research

**Researched:** 2026-04-11
**Domain:** Ruby on Rails model refactoring — PORO service extraction from ActiveRecord model
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Extract two clusters: TablePopulator (~123 LOC: do_placement + initialize_table_monitors + reset_party_monitor) and ResultProcessor (~281 LOC: report_result, finalize_game_result, finalize_round, accumulate_results, update_game_participations). Target ~404 line reduction (~67%).
- **D-02:** Extraction order: TablePopulator first (lower coupling, simpler methods), then ResultProcessor (complex, pessimistic lock). Validates pattern before tackling the hardest part.
- **D-03:** Data lookup methods (all_table_monitors_finished?, get_attribute_by_gname, get_game_plan_attribute_by_gname — ~21 LOC) stay in the model. Too small for a service.
- **D-04:** All extracted services are POROs with `initialize(party_monitor)` and multiple public methods. No `.call` convention. Matches `TournamentMonitor::ResultProcessor` and `TournamentMonitor::TablePopulator` patterns exactly.
- **D-05:** `PartyMonitor::` namespace under `app/services/party_monitor/` directory. Matches existing `TournamentMonitor::`, `Tournament::`, `League::` patterns.
- **D-06:** The pessimistic lock in `report_result` stays in the PartyMonitor model. Inside the lock, the model delegates to `ResultProcessor` for actual data writes. Lock boundary and state transitions stay in the model.
- **D-07:** All AASM transitions and event callbacks remain in PartyMonitor. Services never fire AASM events — they do data work and return. Model owns state machine flow.
- **D-08:** `do_placement` and `initialize_table_monitors` are grouped into one service: `PartyMonitor::TablePopulator`. Both methods deal with table/game assignment. Matches `TournamentMonitor::TablePopulator` pattern.
- **D-09:** `reset_party_monitor` is included in `TablePopulator` as it is part of the table setup lifecycle.
- **D-10:** PartyMonitor model keeps thin delegation wrappers for all extracted methods. Callers (controllers, reflexes, jobs) continue calling `party_monitor.do_placement` etc. without changes. Same pattern as Phase 21 (League extraction).

### Claude's Discretion

- Internal method decomposition within services
- Test file organization for new service classes
- Whether missing helper methods (next_seqno, write_game_result_data) are implemented as stubs in model or in services
- How to handle instance variable state (@placements, @placement_candidates) during extraction

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EXTR-02 | Extract service classes from PartyMonitor reducing line count significantly | Two POROs identified: TablePopulator (~123 LOC) and ResultProcessor (~281 LOC). Delegation wrappers in model preserve public API. Pattern fully verified against TournamentMonitor analog. |
</phase_requirements>

---

## Summary

PartyMonitor (605 lines) is being split into two PORO service classes following the exact same extraction pattern established by TournamentMonitor (Phases from prior milestone) and League (Phase 21). The codebase already has `app/services/tournament_monitor/table_populator.rb` and `app/services/tournament_monitor/result_processor.rb` as direct templates. The extraction is structurally simpler than TournamentMonitor's because PartyMonitor has fewer methods and less branching logic in the result pipeline.

Three critical pre-existing inconsistencies were found in the characterization tests (Phase 20) that the planner must account for: (1) `add_result_to` is called in `accumulate_results` but is NOT defined in `PartyMonitor` — it must be defined in `PartyMonitor::ResultProcessor`; (2) `next_seqno` is called in `do_placement` but is NOT defined in `PartyMonitor` (only in `TournamentMonitor`) — it must be defined or stubbed in `PartyMonitor::TablePopulator`; (3) `write_game_result_data` is called in `report_result` but is NOT defined in `PartyMonitor` — it must be defined in `PartyMonitor::ResultProcessor`.

The full test suite baseline is clean: **856 runs, 0 failures, 0 errors, 14 skips** (verified 2026-04-11). The characterization tests are **40 runs, 0 failures, 0 errors, 1 skip** — all must remain green after extraction.

**Primary recommendation:** Extract `PartyMonitor::TablePopulator` first (lower coupling, resolves `next_seqno` gap), then `PartyMonitor::ResultProcessor` (resolves `add_result_to` and `write_game_result_data` gaps). Add thin delegation wrappers to model. Create `test/services/party_monitor/` directory with one test file per service.

---

## Standard Stack

### Core Pattern (no new gems required)
[VERIFIED: codebase grep]

| Component | Location | Purpose |
|-----------|----------|---------|
| PORO service class | `app/services/party_monitor/` | No gem, plain Ruby class |
| `initialize(party_monitor)` | Service constructor | Holds reference to model |
| Multiple public methods | Service API | No `.call` convention |
| Thin delegation wrappers | `app/models/party_monitor.rb` | Public API compatibility |
| `frozen_string_literal: true` | Top of all Ruby files | Project convention (CLAUDE.md) |
| StandardRB | `.standard.yml` | Linting (project-enforced) |

**No new gem installations required.** [VERIFIED: codebase analysis]

---

## Architecture Patterns

### Recommended Directory Structure
[VERIFIED: ls app/services/]

```
app/services/party_monitor/
├── table_populator.rb        # do_placement, initialize_table_monitors, reset_party_monitor
└── result_processor.rb       # report_result (delegation shell), finalize_game_result,
                              # finalize_round, accumulate_results, update_game_participations,
                              # write_game_result_data, add_result_to (private helpers)

test/services/party_monitor/
├── table_populator_test.rb   # New — service-level tests
└── result_processor_test.rb  # New — service-level tests
```

### Pattern 1: PORO with initialize(model)
[VERIFIED: app/services/tournament_monitor/result_processor.rb, app/services/league/standings_calculator.rb]

```ruby
# frozen_string_literal: true

class PartyMonitor::TablePopulator
  def initialize(party_monitor)
    @party_monitor = party_monitor
  end

  def reset_party_monitor
    # ... extracted from model
  end

  def initialize_table_monitors
    # ... extracted from model — prefix Rails.logger with reference via @party_monitor
  end

  def do_placement(new_game, r_no, t_no, row = nil, row_nr = nil)
    # ... extracted from model
    # Instance vars (@placements etc.) become service-local — acceptable per D-04
  end

  private

  def next_seqno
    # Must be defined here — NOT on PartyMonitor model
    # See Critical Finding #2
  end
end
```

### Pattern 2: Thin delegation wrappers in model
[VERIFIED: app/models/league.rb lines 617-634]

```ruby
# In app/models/party_monitor.rb

def reset_party_monitor
  PartyMonitor::TablePopulator.new(self).reset_party_monitor
end

def initialize_table_monitors
  PartyMonitor::TablePopulator.new(self).initialize_table_monitors
end

def do_placement(new_game, r_no, t_no, row = nil, row_nr = nil)
  PartyMonitor::TablePopulator.new(self).do_placement(new_game, r_no, t_no, row, row_nr)
end
```

### Pattern 3: ResultProcessor delegation with lock boundary in model
[VERIFIED: app/services/tournament_monitor/result_processor.rb — D-06]

The `game.with_lock` block stays in PartyMonitor model. Inside the lock, the model instantiates `PartyMonitor::ResultProcessor.new(self)` to call `write_game_result_data`. The full `report_result` pipeline method moves to the service:

```ruby
# Model keeps the pessimistic lock wrapper:
def report_result(table_monitor)
  PartyMonitor::ResultProcessor.new(self).report_result(table_monitor)
end

# ResultProcessor owns the full pipeline including lock:
class PartyMonitor::ResultProcessor
  def report_result(table_monitor)
    TournamentMonitor.transaction do
      try do
        game = table_monitor.game
        if game.present? && table_monitor.may_finish_match?
          game.with_lock do
            table_monitor.reload
            game.reload
            write_game_result_data(table_monitor)  # now private in service
            if table_monitor.may_finish_match?
              table_monitor.finish_match!
            end
          end
        end
        finalize_game_result(table_monitor)
        accumulate_results
        # ...
      end
    end
  end
end
```

### Pattern 4: Service-level test file structure
[VERIFIED: test/services/league/standings_calculator_test.rb]

```ruby
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/party_monitor_test_helper"

class PartyMonitor::TablePopulatorTest < ActiveSupport::TestCase
  include PartyMonitorTestHelper

  self.use_transactional_tests = true

  setup do
    result = create_party_monitor_with_party
    @pm = result[:party_monitor]
    @party = result[:party]
  end

  teardown do
    PartyMonitor.allow_change_tables = nil
  end
  # ... tests
end
```

### Anti-Patterns to Avoid

- **Firing AASM events from service:** Per D-07, services never call `@party_monitor.prepare_next_round!` etc. Services do data work; model fires events.
- **Moving the `game.with_lock` into the service without delegation:** Per D-06, the lock boundary logic is the service's `report_result` — not split between model and service.
- **Defining `next_seqno` as a model method:** It must live in `PartyMonitor::TablePopulator` (private). Calling it on the model directly has never worked — the characterization test already documents this.
- **Forgetting `data_will_change!` before mutating `data`:** `data` is a serialized JSON column; dirty tracking requires explicit `data_will_change!` before mutation, then `save!`. This pattern is throughout both extracted methods.
- **Using `party_monitor.data["rankings"] = rankings` in accumulate_results without `data_will_change!`:** The characterization test documents this as a pre-existing bug — the service should implement the same buggy behavior (behavior preservation is the requirement, not fixing bugs).

---

## Critical Findings (Pre-existing Gaps)

These three methods are called in PartyMonitor but NOT defined on PartyMonitor. They must be defined within the extracted services. [VERIFIED: codebase grep, characterization tests confirm]

### Finding 1: `add_result_to` — missing from model
- **Called by:** `accumulate_results` (lines 469-488 in party_monitor.rb)
- **Defined in:** `TournamentMonitor::ResultProcessor` only
- **Action:** Define `add_result_to` as a private method in `PartyMonitor::ResultProcessor`
- **Template:** `app/services/tournament_monitor/result_processor.rb` lines 406-447 (adapt: uses `@tournament_monitor.tournament.seedings` — PartyMonitor analog is `@party_monitor.party.league`)

### Finding 2: `next_seqno` — missing from model
- **Called by:** `do_placement` (line 174 in party_monitor.rb)
- **Defined in:** `TournamentMonitor` model (app/models/tournament_monitor.rb line 173) — not on PartyMonitor
- **Action:** Define `next_seqno` as a private method in `PartyMonitor::TablePopulator`
- **Characterization test:** `test "next_seqno is NOT defined on PartyMonitor"` explicitly documents this — pin test must remain true (refute @pm.respond_to?(:next_seqno, true))
- **Caution:** Do NOT add `next_seqno` to the model, or the characterization test fails

### Finding 3: `write_game_result_data` — missing from model
- **Called by:** `report_result` (line 304 in party_monitor.rb), inside `game.with_lock`
- **Defined in:** `TournamentMonitor` model AND `TournamentMonitor::ResultProcessor` service — not on PartyMonitor
- **Action:** Define as private method in `PartyMonitor::ResultProcessor`
- **Characterization test:** `test "write_game_result_data is NOT defined on PartyMonitor"` — must remain true
- **Caution:** Do NOT add `write_game_result_data` to the model

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Pessimistic locking | Custom mutex | `game.with_lock` (ActiveRecord) | Race-condition safe, database-backed |
| PORO loading | Custom autoloader | Rails autoloading via namespace + directory | Convention already proven |
| Test isolation | Custom teardown logic | `use_transactional_tests = true` + teardown `PartyMonitor.allow_change_tables = nil` | Proven in characterization tests |

---

## Common Pitfalls

### Pitfall 1: Breaking characterization tests by adding methods to model
**What goes wrong:** Developer adds `next_seqno` or `write_game_result_data` directly to `PartyMonitor` model for convenience. Characterization tests `refute @pm.respond_to?(:next_seqno, true)` and `refute @pm.respond_to?(:write_game_result_data, true)` immediately fail.
**Why it happens:** Easiest solution seems to be putting helpers in the model.
**How to avoid:** These methods belong in the service only. The delegation wrapper is the correct model-level entry point.
**Warning signs:** Characterization test failures after adding methods to model.

### Pitfall 2: Instance variable state leaking across delegation calls
**What goes wrong:** `@placements`, `@placement_candidates`, `@placements_done` are service-local in `TablePopulator`. If a new instance is created per delegation call (e.g., `PartyMonitor::TablePopulator.new(self).do_placement(...)`), state initialized in one call is gone in the next.
**Why it happens:** The `do_placement` method uses `@placements ||= ...` expecting persistence across multiple calls in the same placement loop.
**How to avoid:** The reflex at line 305 calls `@party_monitor.do_placement(game, r_no, t_no, row, row_nr)` in a loop. The delegation wrapper must either: (a) cache the service instance on the model (`@table_populator ||= PartyMonitor::TablePopulator.new(self)`), or (b) accept that a fresh instance is created per call and rely on data["placements"] reloading state (which is what the `||=` guards do). Option (b) matches the TournamentMonitor pattern where `@placements ||= @tournament_monitor.data["placements"].presence || {}` re-reads from the model on each call.
**Warning signs:** Placements not accumulating across multiple `do_placement` calls.

### Pitfall 3: `cattr_accessor :allow_change_tables` on PartyMonitor vs TournamentMonitor
**What goes wrong:** `do_placement` in TournamentMonitor::TablePopulator references `TournamentMonitor.allow_change_tables`. PartyMonitor has its own `cattr_accessor :allow_change_tables`. The service must reference `PartyMonitor.allow_change_tables`, not `TournamentMonitor.allow_change_tables`.
**Why it happens:** Copy-paste from TournamentMonitor template.
**How to avoid:** In `PartyMonitor::TablePopulator`, all references to the model class must use `PartyMonitor`, not `TournamentMonitor`. The teardown in characterization tests already handles `PartyMonitor.allow_change_tables = nil`.
**Warning signs:** Table assignment errors, or `allow_change_tables` affecting TournamentMonitor state during tests.

### Pitfall 4: `accumulate_results` data mutation bug must be preserved
**What goes wrong:** The characterization test explicitly pins a pre-existing bug: `data["rankings"] = rankings` via `HashWithIndifferentAccess` wrapper does not persist because `data_will_change!` is called before the mutation but the assignment goes to the wrapper object, not the underlying attribute. The test asserts `@pm.data["rankings"]` is nil after reload.
**How to avoid:** Extract `accumulate_results` verbatim — do not fix the bug during extraction. The characterization test is the pin. Behavior preservation is the requirement.
**Warning signs:** The characterization test `assert_nil @pm.data["rankings"]` fails (which would mean the bug was accidentally fixed — breaking the characterization contract).

### Pitfall 5: `TournamentMonitor.transaction` scope in `report_result`
**What goes wrong:** `report_result` wraps execution in `TournamentMonitor.transaction`. This is surprising — PartyMonitor uses TournamentMonitor's transaction scope. Changing to `PartyMonitor.transaction` or `ActiveRecord::Base.transaction` changes transactional semantics.
**How to avoid:** Extract `report_result` verbatim — keep `TournamentMonitor.transaction do` as-is. This is documented behavior, confirmed by characterization test.
**Warning signs:** Transaction rollback behavior changes in integration tests.

---

## Code Examples

### Verified delegation wrapper (League::StandingsCalculator pattern)
[VERIFIED: app/models/league.rb lines 617-634]

```ruby
# In model — four thin delegation methods
def standings_table_karambol
  League::StandingsCalculator.new(self).karambol
end

def standings_table_snooker
  League::StandingsCalculator.new(self).snooker
end
```

### Verified service constructor (TournamentMonitor pattern)
[VERIFIED: app/services/tournament_monitor/result_processor.rb line 24-27]

```ruby
class TournamentMonitor::ResultProcessor
  def initialize(tournament_monitor)
    @tournament_monitor = tournament_monitor
  end
```

### Verified test teardown for cattr pollution
[VERIFIED: test/models/party_monitor_aasm_test.rb line 31-33]

```ruby
teardown do
  PartyMonitor.allow_change_tables = nil  # avoid cattr pollution between tests
end
```

---

## Callers of Methods Being Extracted

[VERIFIED: grep of app/reflexes/, app/controllers/, app/jobs/]

| Method | Caller | Location |
|--------|--------|----------|
| `do_placement` | `PartyMonitorReflex#assign_to_table` | `app/reflexes/party_monitor_reflex.rb:305` |
| `reset_party_monitor` | `PartyMonitorReflex#reset_party_monitor` | `app/reflexes/party_monitor_reflex.rb:343` |
| `initialize_table_monitors` | Called internally by `reset_party_monitor` | `app/models/party_monitor.rb:129` |
| `report_result` | Called from `table_monitor_reflex.rb` (commented out in current code at line 281) | `app/reflexes/table_monitor_reflex.rb` |
| `finalize_game_result` | Called internally by `report_result` | Internal only |
| `finalize_round` | Called internally by `report_result` | Internal only |
| `accumulate_results` | Called internally by `report_result` and `finalize_round` | Internal only |
| `update_game_participations` | Called internally by `finalize_game_result` and `finalize_round` | Internal only |

**Key finding:** All external callers use the delegation API (`party_monitor.do_placement`, `party_monitor.reset_party_monitor`). Delegation wrappers preserve this API with zero caller changes required. [VERIFIED: grep confirmed]

---

## Method Line Count Breakdown

[VERIFIED: grep -n "def " in party_monitor.rb + line inspection]

**TablePopulator cluster (~123 LOC):**
| Method | Lines (approx.) | Decision |
|--------|-----------------|----------|
| `reset_party_monitor` | 110-135 = ~25 LOC | Moves to TablePopulator (D-09) |
| `initialize_table_monitors` | 136-153 = ~18 LOC | Moves to TablePopulator (D-08) |
| `do_placement` | 154-237 = ~84 LOC | Moves to TablePopulator (D-08) |
| **Subtotal** | **~127 LOC** | |

**ResultProcessor cluster (~281 LOC):**
| Method | Lines (approx.) | Decision |
|--------|-----------------|----------|
| `report_result` | 277-358 = ~82 LOC | Moves to ResultProcessor (D-01) |
| `finalize_round` | 360-404 = ~45 LOC | Moves to ResultProcessor (D-01) |
| `finalize_game_result` | 406-441 = ~36 LOC | Moves to ResultProcessor (D-01) |
| `accumulate_results` | 445-495 = ~51 LOC | Moves to ResultProcessor (D-01) |
| `update_game_participations` | 497-568 = ~72 LOC | Moves to ResultProcessor (D-01) |
| `add_result_to` (private, new) | ~40 LOC (from TM template) | New private in ResultProcessor |
| **Subtotal** | **~326 LOC** | |

**Staying in model (~180 LOC remaining):**
- Schema header, includes, associations, callbacks, AASM block (~88 LOC)
- `fixed_display_left?`, `log_state_change`, `data`, `data=` (~20 LOC)
- `deep_merge_data!`, `current_round`, `current_round!`, `incr_current_round!`, `decr_current_round!`, `states`, `events` (~30 LOC)
- `all_table_monitors_finished?`, `get_attribute_by_gname`, `get_game_plan_attribute_by_gname` (~30 LOC) (D-03)
- Thin delegation wrappers (~8 LOC new)
- `before_all_events` private (~3 LOC)

**Expected model line count after extraction:** ~180 LOC (from 605) — ~70% reduction.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `add_result_to` in `PartyMonitor::ResultProcessor` should use `@party_monitor.party.league` where TournamentMonitor uses `@tournament_monitor.tournament.seedings` for balls_goal lookup | Critical Findings | The balls_goal seeding lookup in the party context may not have an equivalent; planner may need to stub or simplify | 
| A2 | `next_seqno` logic from `TournamentMonitor` (line 173) is applicable to PartyMonitor context | Critical Findings | If sequence numbering is different in team match context, the extracted implementation may compute wrong seqnos |

---

## Environment Availability

Step 2.6: SKIPPED (no external dependencies — pure code refactoring, no external tools required).

---

## Open Questions

1. **`add_result_to` port: balls_goal seeding lookup**
   - What we know: TournamentMonitor's `add_result_to` queries `@tournament_monitor.tournament.seedings.where(...)` for player `balls_goal`. PartyMonitor uses `party.games` for `accumulate_results`.
   - What's unclear: Does PartyMonitor need `balls_goal` at all, or is that a tournament-specific concept? The `accumulate_results` in party_monitor uses a simpler rankings hash without `balls_goal` or `gd_pct` fields.
   - Recommendation: Compare the `accumulate_results` ranking hash structure in party_monitor.rb (lines 446-494) vs tournament_monitor. The party_monitor version is simpler (no `balls_goal`, no `gd_pct`). The `add_result_to` helper for PartyMonitor should be written from scratch to match only what `accumulate_results` in party_monitor needs.

2. **`next_seqno` implementation**
   - What we know: Called in `do_placement` line 174. Defined in `TournamentMonitor` at line 173. NOT on PartyMonitor — characterization test pins this.
   - What's unclear: The exact logic needed (counting existing games? incrementing a counter?).
   - Recommendation: Read `TournamentMonitor#next_seqno` at app/models/tournament_monitor.rb line 173 before implementing. The planner should include this as a required read for the executor.

---

## Sources

### Primary (HIGH confidence)
- `app/models/party_monitor.rb` — 605 lines, target model, read in full
- `app/services/tournament_monitor/result_processor.rb` — canonical ResultProcessor pattern, read in full
- `app/services/tournament_monitor/table_populator.rb` — canonical TablePopulator pattern, read first 80 lines (interface established)
- `app/services/league/standings_calculator.rb` — Phase 21 PORO delegation pattern, read in full
- `app/models/league.rb` lines 617-634 — thin delegation wrapper examples, read verified
- `test/models/party_monitor_aasm_test.rb` — 40 characterization tests (Phase 20), read in full
- `test/models/party_monitor_placement_test.rb` — 40 characterization tests (Phase 20), read in full
- `test/support/party_monitor_test_helper.rb` — shared fixture factory, read in full
- `test/services/league/standings_calculator_test.rb` — service test structure example, read in full
- `bin/rails test` run — 856 runs, 0 failures, 0 errors, 14 skips (baseline confirmed)
- `bin/rails test test/models/party_monitor_aasm_test.rb test/models/party_monitor_placement_test.rb` — 40 runs, 0 failures, 1 skip (characterization baseline confirmed)

### Secondary (MEDIUM confidence)
- grep analysis of `app/reflexes/`, `app/controllers/`, `app/jobs/` for callers of extracted methods

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pattern fully established by prior phases, no new libraries
- Architecture: HIGH — verified against two existing service extractions (TournamentMonitor, League)
- Pitfalls: HIGH — verified from characterization tests and live test run
- Critical findings (missing methods): HIGH — verified by codebase grep and characterization tests

**Research date:** 2026-04-11
**Valid until:** 2026-05-11 (stable codebase, refactoring initiative)
