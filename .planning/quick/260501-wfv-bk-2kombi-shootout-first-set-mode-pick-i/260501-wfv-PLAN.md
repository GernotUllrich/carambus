---
phase: 260501-wfv
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - app/reflexes/table_monitor_reflex.rb
  - test/services/bk2/advance_match_state_test.rb
autonomous: true
requirements:
  - QUICK-260501-WFV-01
tags: [bk2, scoreboard, reflex, bug-fix]

must_haves:
  truths:
    - "Clicking 'BK-2 first' (serienspiel) at the BK-2kombi shootout transition results in the playing scoreboard rendering BK-2 (serienspiel) for set 1 — not BK-2plus."
    - "After the shootout reflex fires, table_monitor.data['bk2_state']['first_set_mode'] equals the just-picked mode (matches bk2_options.first_set_mode)."
    - "After the shootout reflex fires, bk2_state.current_phase, shots_left_in_turn, and innings_left_in_set are consistent with the just-picked first_set_mode."
    - "The same correctness holds symmetrically for switch_players_and_start_game (Anstoßer-swap variant)."
    - "A unit test in advance_match_state_test.rb pins the re-init contract: deleting data['bk2_state'] before re-calling initialize_bk2_state! produces a fresh state seeded from the current bk2_options.first_set_mode."
  artifacts:
    - path: app/reflexes/table_monitor_reflex.rb
      provides: "Stale-bk2_state guard in start_game and switch_players_and_start_game (one-line @table_monitor.data.delete('bk2_state') inside the existing bk2_kombi+valid-mode block)."
      contains: "@table_monitor.data.delete(\"bk2_state\")"
    - path: test/services/bk2/advance_match_state_test.rb
      provides: "Re-init test covering: existing DZ-seeded bk2_state + bk2_options switched to serienspiel + delete + initialize_bk2_state! → SP-seeded bk2_state."
      contains: "re-init"
  key_links:
    - from: app/reflexes/table_monitor_reflex.rb (start_game, switch_players_and_start_game)
      to: app/services/bk2/advance_match_state.rb (initialize_bk2_state!)
      via: "data.delete('bk2_state') BEFORE the existing initialize_bk2_state! call so the early-return guard at line 58 does not block re-seed"
      pattern: "data\\.delete\\(\"bk2_state\"\\).*initialize_bk2_state!"
    - from: app/reflexes/table_monitor_reflex.rb (bk2_options write block)
      to: app/views/table_monitors/_scoreboard.html.erb:63 (bk2_state['first_set_mode'])
      via: "bk2_state is rebuilt from refreshed bk2_options.first_set_mode by initialize_bk2_state!"
      pattern: "bk2_state\\[\"first_set_mode\"\\]"
---

<objective>
Fix the BK-2kombi shootout regression where picking "BK-2 first" (serienspiel) at the shootout transition is ignored: the playing scoreboard still renders BK-2plus (direkter_zweikampf) for set 1.

Purpose: A volunteer operator at tomorrow's tournament must be able to pick the first-set mode at the shootout transition and have the scoreboard reflect their choice. Today, a stale `bk2_state` (seeded earlier in `TableMonitor::GameSetup#perform_start_game`) survives the second `initialize_bk2_state!` call because the service early-returns when `data["bk2_state"]` is already a Hash. The phase chip and initial config (current_phase, shots_left_in_turn, innings_left_in_set) therefore lag behind the user's pick.

Output: Two one-line additions to `app/reflexes/table_monitor_reflex.rb` (one in each of `switch_players_and_start_game` and `start_game`) that delete the stale `bk2_state` immediately after writing the refreshed `bk2_options.first_set_mode`, plus one new unit test in `test/services/bk2/advance_match_state_test.rb` pinning the re-init contract.

Approach: Extend-before-build. NO new method, NO `force:` keyword on `initialize_bk2_state!`, NO new state slot, NO refactor of the duplicated reflex blocks. Smallest possible additive guard inside the existing `if %w[direkter_zweikampf serienspiel].include?(bk2_mode)` blocks.
</objective>

<execution_context>
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/workflows/execute-plan.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.agents/skills/extend-before-build/SKILL.md
@app/services/bk2/advance_match_state.rb
@app/reflexes/table_monitor_reflex.rb
@app/services/table_monitor/game_setup.rb
@app/views/table_monitors/_scoreboard.html.erb
@test/services/bk2/advance_match_state_test.rb

<interfaces>
<!-- Key contract: Bk2::AdvanceMatchState.initialize_bk2_state! is idempotent — it
     EARLY-RETURNS when data["bk2_state"] is already a Hash. The fix exploits this
     by clearing bk2_state right before the second call so re-seeding happens. -->

From app/services/bk2/advance_match_state.rb:
```ruby
# Class method (lines 24-28):
def self.initialize_bk2_state!(table_monitor)
  new(table_monitor: table_monitor).send(:init_state_if_missing!)
  table_monitor.save!
  table_monitor.data["bk2_state"]
end

# Private (lines 57-82): early-returns if state already exists.
def init_state_if_missing!
  return if @tm.data["bk2_state"].is_a?(Hash)

  first_mode = derive_first_set_mode  # reads @tm.data["bk2_options"]["first_set_mode"]
  initial_phase = phase_for_set(1, first_mode)
  dz_max = derive_dz_max_shots
  sp_max = derive_sp_max_innings
  balls_goal_val = derive_balls_goal

  @tm.data["bk2_state"] = {
    "current_set_number"  => 1,
    "current_phase"       => initial_phase,
    "first_set_mode"      => first_mode,
    "player_at_table"     => @tm.data["current_kickoff_player"].presence || "playera",
    "shots_left_in_turn"  => (initial_phase == "direkter_zweikampf") ? dz_max : 0,
    "innings_left_in_set" => (initial_phase == "serienspiel") ? sp_max : 0,
    # ...sets, sets_won, balls_goal, set_target_points
  }
end
```

From app/reflexes/table_monitor_reflex.rb (the two affected reflex methods, EXISTING shape):
```ruby
def switch_players_and_start_game
  morph :nothing
  @table_monitor = TableMonitor.find(element.andand.dataset[:id])
  if @table_monitor.data["free_game_form"] == "bk2_kombi"
    bk2_mode = element.andand.dataset[:bk2_first_set_mode].to_s
    if %w[direkter_zweikampf serienspiel].include?(bk2_mode)
      @table_monitor.data["bk2_options"] ||= {}
      @table_monitor.data["bk2_options"]["first_set_mode"] = bk2_mode
      # <<< NEW LINE GOES HERE >>>
    end
  end
  @table_monitor.suppress_broadcast = true
  if bk_family?
    Bk2::AdvanceMatchState.initialize_bk2_state!(@table_monitor)  # without fix: early-returns
  end
  # ...switch_players, finish_shootout!, do_play, save!
end

def start_game
  morph :nothing
  @table_monitor = TableMonitor.find(element.andand.dataset[:id])
  if @table_monitor.data["free_game_form"] == "bk2_kombi"
    bk2_mode = element.andand.dataset[:bk2_first_set_mode].to_s
    if %w[direkter_zweikampf serienspiel].include?(bk2_mode)
      @table_monitor.data["bk2_options"] ||= {}
      @table_monitor.data["bk2_options"]["first_set_mode"] = bk2_mode
      # <<< NEW LINE GOES HERE >>>
    end
  end
  @table_monitor.suppress_broadcast = true
  if bk_family?
    Bk2::AdvanceMatchState.initialize_bk2_state!(@table_monitor)  # without fix: early-returns
  end
  # ...reset_timer!, etc.
end
```
</interfaces>

<root_cause>
1. `TableMonitor::GameSetup#perform_start_game` (game_setup.rb:415) seeds `data["bk2_state"]` with `first_set_mode = "direkter_zweikampf"` (default).
2. After warmup, user clicks "BK-2 first" (serienspiel) at the shootout. The reflex updates `bk2_options.first_set_mode = "serienspiel"` correctly, then calls `initialize_bk2_state!`.
3. `init_state_if_missing!` early-returns at line 58 because `bk2_state` already exists. The stale DZ-seeded `bk2_state` survives.
4. `_scoreboard.html.erb:63` reads `bk2_state["first_set_mode"]` (still "direkter_zweikampf") → wrong phase chip and wrong initial config.
5. `BkParamResolver.compute_effective_discipline` reads `bk2_options.first_set_mode` directly so per-set effective_discipline is correct — but the visible phase chip and initial state slots in `bk2_state` are wrong.
</root_cause>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add stale-bk2_state delete guard in both shootout reflex methods</name>
  <files>app/reflexes/table_monitor_reflex.rb</files>
  <behavior>
    After this change, when the shootout transition fires (start_game OR switch_players_and_start_game) on a BK-2kombi TableMonitor whose `bk2_state` was already initialized during warmup:

    - If the operator clicks "BK-2 first" (`bk2_first_set_mode = "serienspiel"`):
      * `bk2_options.first_set_mode == "serienspiel"` (already correct today)
      * `data["bk2_state"]` is deleted before `initialize_bk2_state!` is called
      * After `initialize_bk2_state!`: `bk2_state.first_set_mode == "serienspiel"`, `current_phase == "serienspiel"`, `innings_left_in_set == 5`, `shots_left_in_turn == 0`
    - If the operator clicks "BK-2plus first" (`bk2_first_set_mode = "direkter_zweikampf"`):
      * Symmetric: `bk2_state.first_set_mode == "direkter_zweikampf"`, `current_phase == "direkter_zweikampf"`, `shots_left_in_turn == 2`, `innings_left_in_set == 0`
    - If the shootout button carries no/invalid `bk2_first_set_mode` payload: behavior UNCHANGED (the inner `if %w[...].include?` block does not execute, so no delete happens — the stale bk2_state is preserved exactly as today; non-bk2_kombi families are also untouched).
    - For non-`bk2_kombi` `free_game_form`: outer `if` does not match → no change.
  </behavior>
  <action>
Edit `app/reflexes/table_monitor_reflex.rb` and add ONE line in each of the two reflex methods, inside the existing `if %w[direkter_zweikampf serienspiel].include?(bk2_mode)` block, immediately AFTER the line `@table_monitor.data["bk2_options"]["first_set_mode"] = bk2_mode`.

**Method 1: `switch_players_and_start_game`** (around line 365, between current line 365 and 366):

Existing block:
```ruby
if @table_monitor.data["free_game_form"] == "bk2_kombi"
  bk2_mode = element.andand.dataset[:bk2_first_set_mode].to_s
  if %w[direkter_zweikampf serienspiel].include?(bk2_mode)
    @table_monitor.data["bk2_options"] ||= {}
    @table_monitor.data["bk2_options"]["first_set_mode"] = bk2_mode
  end
end
```

After fix:
```ruby
if @table_monitor.data["free_game_form"] == "bk2_kombi"
  bk2_mode = element.andand.dataset[:bk2_first_set_mode].to_s
  if %w[direkter_zweikampf serienspiel].include?(bk2_mode)
    @table_monitor.data["bk2_options"] ||= {}
    @table_monitor.data["bk2_options"]["first_set_mode"] = bk2_mode
    # Quick 260501-wfv: clear stale bk2_state seeded earlier in GameSetup so the
    # subsequent initialize_bk2_state! call (line 375) actually re-seeds with the
    # operator-picked first_set_mode. Safe at shootout transition — no play yet,
    # only initial values (sets_won 0:0, all set_scores zero) would be lost.
    @table_monitor.data.delete("bk2_state")
  end
end
```

**Method 2: `start_game`** (around line 401, between current line 401 and 402): apply the IDENTICAL one-line addition with the IDENTICAL comment block, in the same position relative to the same surrounding code.

DO NOT touch the `key_d` reflex (different code path, out of scope).
DO NOT extract a helper or refactor the duplicated block (out of scope per user preference — pure fix only).
DO NOT modify `initialize_bk2_state!` or add a `force:` keyword (out of scope).
DO NOT change line ordering or any other code in either reflex.
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw && bundle exec standardrb app/reflexes/table_monitor_reflex.rb && grep -c '@table_monitor.data.delete("bk2_state")' app/reflexes/table_monitor_reflex.rb | grep -q '^2$' && echo "OK: 2 delete sites"</automated>
  </verify>
  <done>
    - `app/reflexes/table_monitor_reflex.rb` contains exactly 2 occurrences of `@table_monitor.data.delete("bk2_state")` (one in each shootout reflex method).
    - Each occurrence sits inside the existing `if %w[direkter_zweikampf serienspiel].include?(bk2_mode)` block, immediately after the `bk2_options["first_set_mode"] = bk2_mode` write.
    - `bundle exec standardrb app/reflexes/table_monitor_reflex.rb` passes.
    - No other lines in the file changed (verifiable by `git diff` showing only +5 lines per method = +10 total: 2 code lines and the 4-line German comment block × 2).
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Pin re-init contract with unit test in advance_match_state_test.rb</name>
  <files>test/services/bk2/advance_match_state_test.rb</files>
  <behavior>
    A new test in the existing `Bk2::AdvanceMatchStateTest` class proves the operator-flip contract end-to-end at the service level (no reflex involved):

    1. Setup TableMonitor with `bk2_options.first_set_mode = "direkter_zweikampf"`, call `initialize_bk2_state!` → state seeded as DZ.
    2. Operator picks SP at the shootout: tests rewrites `bk2_options.first_set_mode = "serienspiel"` AND deletes `data["bk2_state"]` (mirroring the new reflex guard).
    3. Calls `initialize_bk2_state!` again.
    4. Asserts that the freshly seeded `bk2_state` reflects SP: `first_set_mode == "serienspiel"`, `current_phase == "serienspiel"`, `innings_left_in_set == 5`, `shots_left_in_turn == 0`.

    This is the exact regression guard for the "stale bk2_state survives second call" bug. It is a unit-level test of the service contract — the reflex itself is not exercised here.
  </behavior>
  <action>
Add ONE new test method to the existing `Bk2::AdvanceMatchStateTest` class in `test/services/bk2/advance_match_state_test.rb`. Place it AFTER the existing test at line 48 ("initialize_bk2_state! seeds SP-first config when first_set_mode=serienspiel") and BEFORE the existing test at line 58 ("initialize_bk2_state! falls back to defaults when bk2_options missing").

Test body:
```ruby
test "initialize_bk2_state! re-seeds with new first_set_mode after caller deletes stale bk2_state" do
  # Quick 260501-wfv regression: shootout reflex flips bk2_options.first_set_mode
  # from DZ to SP and must wipe the stale bk2_state (seeded earlier in GameSetup)
  # so the re-call actually re-seeds. Without the delete, init_state_if_missing!
  # early-returns and bk2_state.first_set_mode stays "direkter_zweikampf" — the
  # exact bug this test pins.

  # Step 1: initial DZ-seed (mirrors GameSetup#perform_start_game).
  Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
  initial = @tm.reload.data["bk2_state"]
  assert_equal "direkter_zweikampf", initial["first_set_mode"]
  assert_equal "direkter_zweikampf", initial["current_phase"]
  assert_equal 2, initial["shots_left_in_turn"]
  assert_equal 0, initial["innings_left_in_set"]

  # Step 2: operator picks SP at the shootout — reflex updates bk2_options
  # AND clears stale bk2_state (the fix this test pins).
  @tm.data["bk2_options"]["first_set_mode"] = "serienspiel"
  @tm.data.delete("bk2_state")
  @tm.save!

  # Step 3: subsequent initialize_bk2_state! call (still in the reflex) must re-seed.
  Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
  state = @tm.reload.data["bk2_state"]

  # Step 4: bk2_state reflects the operator's SP pick, not the stale DZ seed.
  assert_equal "serienspiel", state["first_set_mode"],
    "bk2_state.first_set_mode must follow the just-picked mode"
  assert_equal "serienspiel", state["current_phase"],
    "current_phase for set 1 must equal the just-picked first_set_mode"
  assert_equal 5, state["innings_left_in_set"],
    "SP-mode set 1 must seed innings_left_in_set from sp_max"
  assert_equal 0, state["shots_left_in_turn"],
    "SP-mode set 1 must zero shots_left_in_turn"
end
```

The existing `setup` block at lines 9-22 already creates a TableMonitor with `bk2_options.first_set_mode = "direkter_zweikampf"`, `serienspiel_max_innings_per_set = 5`, `direkter_zweikampf_max_shots_per_turn = 2` — perfect fixture for this test, no setup changes needed.

DO NOT modify the existing 4 tests in the file.
DO NOT add a separate test class — the regression belongs in the existing service-test file.
DO NOT mock or stub anything — this is a pure data-roundtrip test against real `initialize_bk2_state!`.
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw && bin/rails test test/services/bk2/advance_match_state_test.rb -v 2>&1 | tail -20</automated>
  </verify>
  <done>
    - New test `test_initialize_bk2_state!_re-seeds_with_new_first_set_mode_after_caller_deletes_stale_bk2_state` exists in `Bk2::AdvanceMatchStateTest`.
    - Running `bin/rails test test/services/bk2/advance_match_state_test.rb` passes ALL 5 tests (4 pre-existing + 1 new) — 0 failures, 0 errors.
    - Running JUST the new test (`bin/rails test test/services/bk2/advance_match_state_test.rb -n /re_seeds_with_new_first_set_mode/`) passes with 4 assertions on the post-re-init state.
    - Test placement: between the existing line-48 test and the existing line-58 test (logical: it builds on the SP-config test by adding the delete-and-re-init step).
  </done>
</task>

</tasks>

<verification>
End-to-end smoke for the bug:

1. Touched-area regression sweep:
   ```
   bin/rails test test/services/bk2/advance_match_state_test.rb test/services/table_monitor/game_setup_test.rb
   ```
   All tests pass; new re-init test is GREEN.

2. Style:
   ```
   bundle exec standardrb app/reflexes/table_monitor_reflex.rb test/services/bk2/advance_match_state_test.rb
   ```
   No offenses.

3. Diff size sanity check:
   ```
   git diff --stat
   ```
   Should show approximately:
   - `app/reflexes/table_monitor_reflex.rb` — +10 lines (5 per method × 2 methods)
   - `test/services/bk2/advance_match_state_test.rb` — +30-35 lines (one new test method)
   No other files modified.

4. Manual smoke (volunteer-runnable, optional, NOT gating since tournament is tomorrow morning):
   - Start dev server: `foreman start -f Procfile.dev`
   - Quickstart a BK-2kombi training match; confirm warmup loads.
   - Click "BK-2 first" (serienspiel) at the shootout.
   - Expect: scoreboard for set 1 shows BK-2 (Serienspiel) phase chip — NOT BK-2plus.
   - Repeat with "BK-2plus first" — set 1 chip should be BK-2plus (DZ).
</verification>

<success_criteria>
- ✅ `bk2_state.first_set_mode` matches `bk2_options.first_set_mode` after the shootout reflex fires (both DZ→SP and SP→DZ flips).
- ✅ Phase chip for set 1 reflects the operator's pick on the playing scoreboard.
- ✅ `bk2_state.current_phase`, `shots_left_in_turn`, `innings_left_in_set` are all consistent with the picked first_set_mode.
- ✅ New unit test in `advance_match_state_test.rb` is GREEN.
- ✅ All pre-existing 4 tests in `advance_match_state_test.rb` remain GREEN.
- ✅ `bundle exec standardrb` clean on both touched files.
- ✅ Total diff: +1 production code line per reflex method (2 total) + comment block + 1 new test (~30 lines). No other code changed.
- ✅ extend-before-build SKILL honored: NO new method on `Bk2::AdvanceMatchState`, NO new state slot, NO `force:` keyword, NO refactor of duplicated reflex blocks. Single additive guard in the existing branch.
</success_criteria>

<output>
After completion, create `.planning/quick/260501-wfv-bk-2kombi-shootout-first-set-mode-pick-i/260501-wfv-01-SUMMARY.md` capturing:
- Diff stats (lines added/removed per file)
- Test count before/after (4 → 5 in `advance_match_state_test.rb`)
- Confirmation that `key_d` reflex was deliberately left untouched (out-of-scope note for any future replay of this bug class)
- Note on the residual code smell: two reflex methods carry an identical 7-line block. A future cleanup pass could DRY this into a private `apply_bk2_first_set_mode_pick!(@table_monitor)` helper. NOT done here per pure-fix scope and tomorrow's tournament deadline.
</output>
