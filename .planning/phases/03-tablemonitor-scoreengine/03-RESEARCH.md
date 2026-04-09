# Phase 3: TableMonitor ScoreEngine - Research

**Researched:** 2026-04-09
**Domain:** Ruby service extraction, pure data-mutation pattern, Rails lazy accessor
**Confidence:** HIGH

## Summary

Phase 3 extracts the score computation logic from `TableMonitor` (3903 lines) into a standalone service `TableMonitor::ScoreEngine` that mutates only the `data` hash and returns no side effects. The extraction follows the same pattern validated in Phase 2 (RegionCc service extraction): thin delegating wrappers remain on the model while logic moves to dedicated service classes.

The critical boundary is that several score methods in `TableMonitor` mix **pure hash mutation** with **persistence and AASM events** (`save!`, `evaluate_result`, `end_of_set!`). ScoreEngine receives only the data hash and discipline flags — it must not call `save!`, AASM events, or enqueue jobs. The orchestration code (`save!` + `evaluate_result`) remains in TableMonitor. Methods like `add_n_balls` and `terminate_current_inning` will be split: their inner computation moves to ScoreEngine, their outer lifecycle calls stay in TableMonitor.

The DEBUG constant (151 occurrences across the file) currently gates all informational logging behind a compile-time env check. TMON-05 replaces this with standard `Rails.logger.debug` calls, which the Rails logger filters at runtime. This is a straightforward mechanical substitution with no logic changes.

**Primary recommendation:** Extract ScoreEngine as `app/models/table_monitor/score_engine.rb`, initialize it via a lazy accessor (`@score_engine ||= TableMonitor::ScoreEngine.new(self.data, discipline: discipline)`), update the data reference after each mutation, and stub `score_engine` in tests using fixture data hashes.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TMON-01 | Extract ScoreEngine service (pure hash mutation logic) | ScoreEngine boundary mapped (see Architecture Patterns); methods catalogued |
| TMON-05 | Remove DEBUG constants, use Rails.logger levels | 151 occurrences catalogued; replacement pattern documented |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ruby stdlib (PORO) | 3.2.1 | ScoreEngine is a plain Ruby object, no gem needed | Hash manipulation requires no external library |
| Rails.logger | Rails 7.2 | Replaces DEBUG-gated logging | Project-standard logging throughout codebase |
| Minitest | Rails 7.2 built-in | Unit tests for ScoreEngine | Project uses Minitest exclusively |

[VERIFIED: codebase grep] — No new gems required. ScoreEngine is a PORO. ApplicationService base class exists but ScoreEngine does not match the `.call(kwargs)` pattern (it is a stateful object wrapping a mutable hash, not a single-operation service). Use a plain Ruby class instead.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Plain Ruby class for ScoreEngine | ApplicationService subclass | `.call(kwargs)` pattern is for stateless single-pass operations; ScoreEngine is called many times per game with accumulated hash state — a stateful object is the right abstraction |
| `Rails.logger.debug` | `Rails.logger.info` | `debug` is the semantically correct level for fine-grained per-method tracing; it is suppressed in production by default log level |

## Architecture Patterns

### Recommended File Location
```
app/models/
├── table_monitor.rb             # Stays; delegates to ScoreEngine via lazy accessor
└── table_monitor/
    └── score_engine.rb          # New file
test/models/
└── table_monitor/
    └── score_engine_test.rb     # New file
```

[ASSUMED] — The nested-file convention (model directory named after the model) is idiomatic Rails for model sub-objects, but this specific project has no existing example of this pattern. The alternative is `app/services/table_monitor/score_engine.rb`. Codebase convention for extracted services is under `app/services/` (e.g., `app/services/region_cc/`), but ScoreEngine is not a service in the ApplicationService sense — it is a model-level collaborator. Either location is defensible; the planner should pick one and document the reason.

### Pattern 1: Lazy Accessor Delegation
**What:** TableMonitor holds a memoized ScoreEngine instance, invalidated on reload.
**When to use:** Any time a score mutation method is called from a reflex or controller.

```ruby
# In TableMonitor
def score_engine
  @score_engine ||= TableMonitor::ScoreEngine.new(data)
end

# After any score mutation call, sync the mutated hash back:
# score_engine.add_n_balls(n) already mutates the same Hash object passed by reference
# No sync needed as long as ScoreEngine receives the actual data hash (not a copy)
```

[VERIFIED: codebase grep] — TableMonitor `data` is serialized via `serialize :data, coder: JSON, type: Hash`. The deserialized Hash is the object referenced by `self.data`. Passing `data` directly to ScoreEngine passes the same object — mutations in ScoreEngine are visible on the model side without an explicit sync step. This is the clean design: no copy, no merge, no sync.

The cached options pattern at lines 1727-1739 (`@cached_options ||=`) confirms lazy memoization is already in use in this class.

```ruby
# Clear the lazy accessor if data is reloaded
def reload(...)
  @score_engine = nil
  super
end
```

### Pattern 2: ScoreEngine Interface
**What:** ScoreEngine wraps the `data` hash and exposes the same method names that previously lived on TableMonitor. It takes the hash by reference and mutates it directly.

```ruby
# app/models/table_monitor/score_engine.rb
# frozen_string_literal: true

class TableMonitor::ScoreEngine
  # data: the live Hash reference from the TableMonitor instance
  # discipline: string — needed for Biathlon/snooker branching
  def initialize(data, discipline: nil)
    @data = data
    @discipline = discipline
  end

  # Returns nothing; mutates @data in place
  def add_n_balls(n_balls, player = nil, skip_snooker_state_update: false)
    # ... hash mutation logic only ...
    # Does NOT call save!, evaluate_result, terminate_current_inning
    # Returns :goal_reached (signal) or nil so TableMonitor can decide what to do next
  end

  # ... other methods ...
end
```

[ASSUMED] — The "signal return value" pattern (ScoreEngine returns a symbol like `:goal_reached` to tell TableMonitor to call `terminate_current_inning`) is one approach. An alternative is that ScoreEngine has no return value and TableMonitor re-checks the data hash after each mutation to decide whether side effects are needed. Either is valid; the planner must pick one.

### Pattern 3: Delegating Wrapper in TableMonitor
**What:** TableMonitor's public methods become one-liners.

```ruby
# Before extraction:
def add_n_balls(n_balls, player = nil, skip_snooker_state_update: false)
  if DEBUG
    Rails.logger.info "..."
  end
  # 170 lines of logic
end

# After extraction:
def add_n_balls(n_balls, player = nil, skip_snooker_state_update: false)
  result = score_engine.add_n_balls(n_balls, player,
                                    skip_snooker_state_update: skip_snooker_state_update)
  if result == :goal_reached
    data_will_change!
    self.copy_from = nil
    terminate_current_inning(player)
  else
    data_will_change!
    self.copy_from = nil
  end
end
```

[ASSUMED] — Exact wrapper shape depends on the signal-return vs check-after-mutation decision above.

### Anti-Patterns to Avoid

- **Copying the data hash into ScoreEngine:** `ScoreEngine.new(data.dup)` breaks the by-reference contract and requires an explicit merge step after each call. This adds complexity and risk.
- **Moving `save!` into ScoreEngine:** Violates the "no database writes" constraint. ScoreEngine must remain a pure data transform.
- **Moving AASM events into ScoreEngine:** `evaluate_result`, `end_of_set!`, `acknowledge_result!` all need the AR model's state machine — they stay in TableMonitor.
- **Moving `terminate_current_inning` wholesale into ScoreEngine:** This method contains `TableMonitor.transaction`, `save!`, and `evaluate_result` calls. Only the inner hash-mutation portion moves to ScoreEngine; the outer transaction/save/evaluate stays in TableMonitor as a new private method (e.g., `commit_inning_termination`).

## Boundary Map: What Moves vs What Stays

[VERIFIED: codebase read — all line references confirmed against app/models/table_monitor.rb]

### Moves to ScoreEngine (pure hash mutation, no AR/AASM)

| Method | Lines | Boundary note |
|--------|-------|---------------|
| `add_n_balls` | 1529-1708 | Inner computation only; `save!` + `evaluate_result` calls stay in TM |
| `set_n_balls` | 2036-2138 | Inner computation only; `save` + `terminate_current_inning` calls stay in TM |
| `redo` | 2281-2325 | The non-PaperTrail branch (hash mutation) moves; PaperTrail-based path stays in TM (accesses `versions`) |
| `undo` | 2369-2506 | The non-PaperTrail hash mutation branches move; PaperTrail `versions` paths stay in TM |
| `foul_one` | 1452-1481 | Hash mutation moves; `terminate_current_inning` call stays in TM |
| `foul_two` | 1428-1450 | Hash mutation moves; `terminate_current_inning` call stays in TM |
| `balls_left` | 1416-1426 | Delegates to `add_n_balls` — follows add_n_balls |
| `recompute_result` | 1487-1508 | Pure hash computation — moves cleanly |
| `init_lists` | 1510-1527 | Pure hash initialization — moves cleanly |
| `update_snooker_state` | 836-884 | Pure hash mutation — moves cleanly |
| `undo_snooker_ball` | 736-782 | Calls `recompute_result`; pure hash — moves cleanly |
| `recalculate_snooker_state_from_protocol` | 785-833 | Pure hash mutation — moves cleanly |
| `snooker_balls_on` | 885-986 | Pure query on hash — moves cleanly |
| `snooker_remaining_points` | 987-1011 | Pure query on hash — moves cleanly |
| `initial_red_balls` | 722-732 | Pure query on data + config — moves cleanly |
| `render_innings_list` | 543-607 | HTML rendering from hash — moves cleanly |
| `render_last_innings` | 613-670 | HTML rendering from hash — moves cleanly |
| `innings_history` | 3218-3404 | Pure hash query — moves cleanly |
| `update_innings_history` | 3406-3544 | Hash mutation only; `save` calls move to TM |
| `increment_inning_points` | 3546-3575 | Hash mutation; `recalculate_player_stats` call stays in TM |
| `decrement_inning_points` | 3578-3602 | Same as above |
| `delete_inning` | 3605-3671 | Hash mutation; `save!` calls stay in TM |
| `insert_inning` | 3673-3762 | Hash mutation; `save!` calls stay in TM |
| `recalculate_player_stats` | 3763-3790 | Hash mutation; `save!` call stays in TM |
| `update_player_innings_data` | 3793-3828 | Hash mutation; `save!` call stays in TM |
| `calculate_running_totals` | 3831-3840 | Pure query — moves cleanly |

### Stays in TableMonitor (AR/AASM/CableReady/persistence)

| Method | Reason |
|--------|--------|
| `terminate_current_inning` | Contains `TableMonitor.transaction`, `save!`, `evaluate_result` — moves only the inner hash portion to ScoreEngine |
| `evaluate_result` | AASM events (`end_of_set!`, `acknowledge_result!`), `save!`, `switch_to_next_set` |
| `undo` / `redo` PaperTrail branches | Access `versions`, call `save!` on reified records |
| `set_game_over` | AASM callback, calls `save` |
| All AASM event handlers | State machine — stays in TM |
| `after_update_commit` | CableReady, job enqueues — stays in TM |
| `get_options!` | Reads AR associations (game, tournament_monitor, gps) |
| `save_result`, `save_current_set` | Write to AR (game_participations, game.data) |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Method delegation from TM to ScoreEngine | Custom proxy objects, method_missing | Direct one-liner delegation (`score_engine.method_name(args)`) | Proxy patterns add indirection; direct calls are readable and grep-able |
| Logging migration | Custom debug helper module | `Rails.logger.debug` with `if Rails.logger.debug?` guard | Rails.logger is already available everywhere; `debug?` guard avoids string interpolation cost |
| Detecting when to call `terminate_current_inning` | Complex state inspection | Signal return value from ScoreEngine OR condition re-check in TM after mutation | Either is simpler than inspecting the data hash from outside |

## Common Pitfalls

### Pitfall 1: Copying the Data Hash
**What goes wrong:** `ScoreEngine.new(data.dup)` — mutations in ScoreEngine don't propagate back to the model. The model saves stale data.
**Why it happens:** Defensive copying habit applied in the wrong context.
**How to avoid:** Pass `data` by reference. Confirm in tests that mutations on `score_engine` are visible on `table_monitor.data` without any merge step.
**Warning signs:** Tests pass but scoreboard shows stale state after a score input.

### Pitfall 2: Moving PaperTrail Access into ScoreEngine
**What goes wrong:** `undo` and `redo` for "14.1 endlos" discipline access `self.versions`, `self.copy_from`, `prev_version.save!` — these are AR concerns. If these branches move to ScoreEngine, ScoreEngine needs an AR reference.
**Why it happens:** `undo` and `redo` mix hash-mutation logic with PaperTrail version traversal in the same method body.
**How to avoid:** Split `undo`/`redo` at the discipline branch. "14.1 endlos" PaperTrail logic stays in TableMonitor. Non-PaperTrail hash mutation moves to ScoreEngine.
**Warning signs:** ScoreEngine constructor receives `self` (the AR object) instead of just `data`.

### Pitfall 3: DEBUG Constant Removal Breaking Error Logging
**What goes wrong:** `DEBUG` also gates error-level logging (`Rails.logger.info "ERROR: ..."`) — removing `if DEBUG` from error log lines means they log in production too.
**Why it happens:** The original code used `DEBUG` uniformly, even for error rescue blocks.
**How to avoid:** Replace error log lines with `Rails.logger.error` (no guard needed — errors should always log). Replace info/debug trace lines with `Rails.logger.debug`. Audit each `if DEBUG` block to determine which log level applies.
**Warning signs:** Production log volume increases unexpectedly after DEBUG removal.

### Pitfall 4: `set_n_balls` Has a Hardcoded `debug = true`
**What goes wrong:** At line 2046, `set_n_balls` has `debug = true` (hardcoded, not `DEBUG`), meaning its verbose logging runs in production today. This is likely a leftover from debugging.
**Why it happens:** Developer set `debug = true` locally and committed it.
**How to avoid:** Remove the `debug = true` line and convert the logging to `Rails.logger.debug`. Do not carry it into ScoreEngine.
**Warning signs:** Failing to notice the local `debug` variable means verbose production logging continues.

### Pitfall 5: Calling score_engine on a New Record
**What goes wrong:** `score_engine` is initialized with `data` at construction time. If the TableMonitor is reloaded from the database (e.g., after `save!`), `@score_engine` holds a stale reference to the old data hash while `self.data` is a new object.
**Why it happens:** AR `reload` replaces `self.data` with a fresh deserialized hash; `@score_engine` still wraps the old one.
**How to avoid:** Override `reload` in TableMonitor to reset `@score_engine = nil`. Also reset it in `after_find` or `after_initialize` if needed.
**Warning signs:** Score state diverges between what the model saves and what the engine computed.

### Pitfall 6: Counting Line Reduction
**What goes wrong:** Counting raw lines removed from table_monitor.rb may not reach 500-600 if many methods still need one-liner wrappers.
**Why it happens:** Each extracted method still requires a delegation stub. With ~25 methods each averaging 5 lines of wrapper, that adds ~125 lines back.
**How to avoid:** Use `wc -l` before and after as the ground truth. The extraction of `add_n_balls` alone (~180 lines), `undo` (~140 lines), `redo` (~45 lines), all snooker methods (~280 lines), innings history (~190 lines), and innings manipulation (~320 lines) totals well over 600 lines. The target is achievable.
**Warning signs:** Underestimating wrapper overhead or forgetting to count DEBUG removal (which can remove 2-4 lines per method).

## Code Examples

### Lazy Accessor with Reload Invalidation
```ruby
# In TableMonitor — after extraction
# Source: Rails memoization convention (confirmed codebase pattern: lines 1737-1739)

def score_engine
  @score_engine ||= TableMonitor::ScoreEngine.new(data, discipline: discipline)
end

def reload(...)
  @score_engine = nil
  super
end
```

### ScoreEngine Constructor
```ruby
# app/models/table_monitor/score_engine.rb
# Source: pattern derived from characterization of add_n_balls, recompute_result, init_lists

# frozen_string_literal: true

class TableMonitor::ScoreEngine
  def initialize(data, discipline: nil)
    @data = data        # Lives Hash reference from TableMonitor#data
    @discipline = discipline
  end

  # Returns :goal_reached or nil (TableMonitor decides whether to call terminate_current_inning)
  def add_n_balls(n_balls, player = nil, skip_snooker_state_update: false)
    # ... pure hash mutation, no save!, no AASM ...
  end

  private

  attr_reader :data, :discipline

  def recompute_result(current_role)
    # ... identical to current recompute_result but uses @data ...
  end
end
```

### Replacing DEBUG Pattern
```ruby
# BEFORE (line 377-384):
if DEBUG
  Rails.logger.info "-----------m6[#{id}]---------->>> internal_name <<<---"
end
# ...
rescue StandardError => e
  Rails.logger.info "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}" if DEBUG
  raise StandardError

# AFTER:
Rails.logger.debug { "-----------m6[#{id}]---------->>> internal_name <<<---" }
# ...
rescue StandardError => e
  Rails.logger.error "ERROR: m6[#{id}]#{e}, #{e.backtrace&.join("\n")}"
  raise StandardError
```

Note: `Rails.logger.debug { block }` is the preferred form — the block is only evaluated if debug level is active, avoiding string interpolation cost in production. [VERIFIED: Rails documentation convention]

### Unit Testing ScoreEngine Without a Database
```ruby
# test/models/table_monitor/score_engine_test.rb
class TableMonitor::ScoreEngineTest < ActiveSupport::TestCase
  def playing_data(overrides = {})
    {
      "current_inning" => { "active_player" => "playera" },
      "balls_on_table" => 15,
      "balls_counter" => 0,
      "balls_counter_stack" => [],
      "extra_balls" => 0,
      "playera" => {
        "result" => 0, "innings" => 0, "innings_list" => [],
        "innings_redo_list" => [0], "innings_foul_list" => [],
        "innings_foul_redo_list" => [0], "hs" => 0, "gd" => 0.0,
        "balls_goal" => "100", "fouls_1" => 0, "discipline" => "Freie Partie"
      },
      "playerb" => {
        "result" => 0, "innings" => 0, "innings_list" => [],
        "innings_redo_list" => [0], "innings_foul_list" => [],
        "innings_foul_redo_list" => [0], "hs" => 0, "gd" => 0.0,
        "balls_goal" => "100", "fouls_1" => 0, "discipline" => "Freie Partie"
      },
      "allow_overflow" => nil,
      "innings_goal" => "0"
    }.merge(overrides)
  end

  test "add_n_balls increments active player innings_redo_list" do
    data = playing_data
    engine = TableMonitor::ScoreEngine.new(data, discipline: "Freie Partie")
    engine.add_n_balls(5)
    assert_equal 5, data.dig("playera", "innings_redo_list", -1)
  end
end
```

[ASSUMED] — This test structure assumes ScoreEngine mutates the passed hash by reference and has no database interaction. The test fixture hash structure is derived from the comment at lines 264-303 of table_monitor.rb.

## DEBUG Constant Audit

**Total `DEBUG` occurrences:** 151 [VERIFIED: grep]
**`DEBUG =` definition:** Line 39 (`DEBUG = Rails.env != "production"`)

Pattern breakdown (approximate, from grep review):
- `if DEBUG ... Rails.logger.info "--->>> method_name <<<---"` — method entry traces → `Rails.logger.debug { "..." }`
- `Rails.logger.info "ERROR: ..." if DEBUG` in rescue blocks → `Rails.logger.error "ERROR: ..."` (always log errors)
- `debug = DEBUG` local alias (several methods) → remove local variable, use `Rails.logger.debug?` guard if needed
- `debug = true` (line 2046, `set_n_balls`) — hardcoded override that ignores `DEBUG`, logs verbosely in production → remove entirely, convert to `Rails.logger.debug`

**Replacement mapping:**
| Before | After |
|--------|-------|
| `if DEBUG; Rails.logger.info "msg"; end` | `Rails.logger.debug { "msg" }` |
| `Rails.logger.info "msg" if DEBUG` | `Rails.logger.debug { "msg" }` |
| `Rails.logger.info "ERROR: ..." if DEBUG` | `Rails.logger.error "ERROR: ..."` |
| `debug = DEBUG` then `Rails.logger.info "..." if debug` | Remove local, use `Rails.logger.debug { "..." }` |
| `debug = true` then `Rails.logger.info "..." if debug` | `Rails.logger.debug { "..." }` |
| `Tournament.logger.info "[TableMonitor] ..." if DEBUG` | `Rails.logger.debug { "[TableMonitor] ..." }` |

The `DEBUG` constant should be removed from line 39. No other code in the project references `TableMonitor::DEBUG` from outside. [VERIFIED: grep — no cross-file `TableMonitor::DEBUG` references found]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Compile-time `DEBUG` constant gating all logs | `Rails.logger.debug {}` with block form | TMON-05 (this phase) | Production-safe, no redeployment needed to toggle log level |
| All score logic inline in AR model | ScoreEngine PORO + delegation | TMON-01 (this phase) | Score logic becomes unit-testable without database |
| Monolithic 3903-line model | Extracted services per phase | Phases 3-5 | Each phase reduces ~500-600 lines |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | ScoreEngine should live in `app/models/table_monitor/score_engine.rb` (not `app/services/`) | Architecture Patterns | Wrong location breaks Rails autoloading; must pick one consistent with project conventions |
| A2 | ScoreEngine returns a signal (`:goal_reached`) so TableMonitor knows when to call `terminate_current_inning` | Architecture Patterns | If wrong, must use check-after-mutation approach instead; affects wrapper method shape |
| A3 | Unit tests for ScoreEngine can use a plain fixture hash (no DB required) | Code Examples | If `data` structure is more complex in practice, fixture setup may need factories |
| A4 | No cross-file references to `TableMonitor::DEBUG` | DEBUG Audit | If other files reference it, removing the constant breaks them |

## Open Questions

1. **ScoreEngine file location: `app/models/table_monitor/` vs `app/services/table_monitor/`**
   - What we know: Phase 2 extraction went to `app/services/region_cc/`; ScoreEngine is a model collaborator not a standalone service
   - What's unclear: Project's preference for model sub-objects
   - Recommendation: Use `app/models/table_monitor/score_engine.rb` — it is a direct collaborator of the model, not a cross-cutting service

2. **`undo` and `redo` PaperTrail branches**
   - What we know: "14.1 endlos" discipline uses PaperTrail `versions` for undo/redo; other disciplines use hash manipulation
   - What's unclear: Whether the PaperTrail branches can be extracted without giving ScoreEngine an AR reference
   - Recommendation: Leave PaperTrail branches entirely in TableMonitor; ScoreEngine handles only the non-PaperTrail hash-mutation branches of `undo`/`redo`

3. **`terminate_current_inning` split**
   - What we know: It contains `TableMonitor.transaction`, hash mutation, `save!`, `evaluate_result`
   - What's unclear: Whether to split into two private methods in TM (`compute_inning_termination` → ScoreEngine, `commit_inning_termination` → TM) or keep the outer method in TM and delegate only the inner hash part
   - Recommendation: Extract the hash mutation portion into `ScoreEngine#terminate_current_inning_data` (pure); keep the outer TM method as the transaction/save/evaluate orchestrator

## Environment Availability

Step 2.6: SKIPPED — Phase 3 is pure code refactoring with no external dependencies beyond the existing Ruby/Rails stack.

## Validation Architecture

`workflow.nyquist_validation` is explicitly `false` in `.planning/config.json` — skipping this section.

## Security Domain

Phase 3 is an internal refactoring (no new network calls, no auth changes, no new endpoints). ASVS categories are not applicable. Security posture is unchanged by this extraction.

## Sources

### Primary (HIGH confidence)
- `app/models/table_monitor.rb` (lines 1-3903) — source of truth for all method boundaries and DEBUG usage
- `test/characterization/table_monitor_char_test.rb` — existing characterization tests (safety net)
- `app/services/application_service.rb` — confirmed `.call(kwargs)` base class
- `.planning/REQUIREMENTS.md` — TMON-01, TMON-05 definitions
- `.planning/phases/02-regioncc-extraction/02-CONTEXT.md` — D-04, D-05, D-06 patterns (ApplicationService, delegation, thin wrappers)

### Secondary (MEDIUM confidence)
- Rails logger documentation convention (block form `debug { }`) — standard Rails practice

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Method boundary map: HIGH — derived from direct code reading
- ScoreEngine interface design: MEDIUM — two open questions (return value, file location) are ASSUMED
- DEBUG replacement pattern: HIGH — mechanical, well-understood substitution
- Line reduction estimate: HIGH — individual method line counts verified

**Research date:** 2026-04-09
**Valid until:** Stable (refactoring target — no external API changes)
