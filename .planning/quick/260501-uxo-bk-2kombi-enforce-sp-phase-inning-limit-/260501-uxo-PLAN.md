---
phase: 260501-uxo
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - app/models/table_monitor.rb
  - app/views/locations/_quick_game_buttons.html.erb
  - config/carambus.yml.erb
  - config/carambus.yml
  - test/models/table_monitor_test.rb
autonomous: true
requirements:
  - QUICK-260501-uxo-01
must_haves:
  truths:
    - "BK-2kombi SP-Phase set closes when both players have completed 5 innings, neither at balls_goal."
    - "Pure BK-2 set closes when both players have completed 5 innings, neither at balls_goal."
    - "BK-2kombi DZ-Phase does NOT close on inning-limit (DZ has shot-limit per turn, not inning-limit per set)."
    - "Tied scores at the inning limit flow through the existing Plan 04 tiebreak modal (no new tiebreak path)."
    - "The inning limit (default 5) is configurable per quick-game preset via carambus.yml `bk2_sp_max_innings` key."
    - "When a preset omits `bk2_sp_max_innings`, the controller's existing default-5 in `clamp_bk_family_params!` (table_monitors_controller.rb:525) applies — no behavior change for pre-existing presets."
  artifacts:
    - path: "app/models/table_monitor.rb"
      provides: "Additive guard branch in `end_of_set?` reading `data['bk2_options']['serienspiel_max_innings_per_set']`"
      contains: "serienspiel_max_innings_per_set"
    - path: "app/views/locations/_quick_game_buttons.html.erb"
      provides: "Conditional emission of `bk2_options[serienspiel_max_innings_per_set]` hidden field when preset has `bk2_sp_max_innings`"
      contains: "bk2_sp_max_innings"
    - path: "config/carambus.yml.erb"
      provides: "BK-2kombi 2/5/70+NS preset carries `bk2_sp_max_innings: 5`"
      contains: "bk2_sp_max_innings: 5"
    - path: "config/carambus.yml"
      provides: "Same `bk2_sp_max_innings: 5` value (compiled file kept in sync per project convention)"
      contains: "bk2_sp_max_innings: 5"
    - path: "test/models/table_monitor_test.rb"
      provides: "4-5 unit tests around the new SP-Phase inning-limit branch in `end_of_set?`"
      contains: "serienspiel_max_innings_per_set"
  key_links:
    - from: "config/carambus.yml (BK-2kombi preset bk2_sp_max_innings)"
      to: "app/views/locations/_quick_game_buttons.html.erb hidden field bk2_options[serienspiel_max_innings_per_set]"
      via: "ERB render of `button['bk2_sp_max_innings']`"
      pattern: "bk2_sp_max_innings"
    - from: "_quick_game_buttons hidden field"
      to: "TableMonitorsController#clamp_bk_family_params! (table_monitors_controller.rb:521-525)"
      via: "params[:bk2_options][:serienspiel_max_innings_per_set]"
      pattern: "params\\[:bk2_options\\]\\[:serienspiel_max_innings_per_set\\]"
    - from: "TableMonitor.data['bk2_options']['serienspiel_max_innings_per_set']"
      to: "TableMonitor#end_of_set? new guard branch"
      via: "data.dig read"
      pattern: "data\\.dig\\(.*serienspiel_max_innings_per_set"
---

<objective>
Enforce the BK-2kombi SP-Phase Aufnahmegrenze (default 5 innings/set) so a tied or stalled SP set does not run unbounded. The limit must apply to BK-2kombi SP-phase AND pure BK-2 (same engine code). DZ-phase is exempt (DZ uses shot-limit per turn, not inning-limit per set). The limit must be configurable from `config/carambus.yml` per quick-game preset.

Purpose: Tomorrow's BCW Grand Prix (2026-05-02). Without this guard, an SP set where neither player reaches 70 balls runs forever; with this guard, set closes at 5 innings each — tied score flows through the existing Plan 04 tiebreak modal.

Output: One additive guard branch in `TableMonitor#end_of_set?`, one preset key threaded through the quick-game form, two YAML files updated, one test stanza locking the behavior.
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@.agents/skills/extend-before-build/SKILL.md
@.agents/skills/scenario-management/SKILL.md
@app/models/table_monitor.rb
@app/views/locations/_quick_game_buttons.html.erb
@app/controllers/table_monitors_controller.rb
@config/carambus.yml.erb
@config/carambus.yml
@test/models/table_monitor_test.rb

<interfaces>
<!-- Existing types/contracts the executor must not break. -->

# `TableMonitor#bk2_kombi_current_phase` (table_monitor.rb:1165-1170)
# Returns "direkter_zweikampf" | "serienspiel" | nil
# Source of truth: data["sets"].length + bk2_options.first_set_mode (default "direkter_zweikampf")

# `TableMonitor#end_of_set?` (table_monitor.rb:1447-1567)
# Existing predicate. Sub-branches today:
#   - GUARD: total_innings + total_points must be > 0
#   - Snooker frame_complete check
#   - Branch 1 (no_followup_phase, lines 1481-1491): bk_2plus / bk50 / bk100 / bk2_kombi-DZ → close immediately on goal
#   - Branch 2 (bk_with_nachstoss, lines 1508-1553): bk_2 / bk2_kombi-SP
#       2a (D-02, lines 1521-1527): Anstoss at goal AND nachstoss_innings == anstoss_innings + 1 → close
#       2b (Phase 38.9, lines 1546-1552): Anstoss at goal AND anstoss_innings >= 2 → close
#   - Branch 3 (legacy karambol, lines 1555-1559): balls_goal reached AND innings parity OR !allow_follow_up → close
#   - Branch 4 (innings_goal, lines 1560-1563): innings_goal reached AND parity OR !allow_follow_up → close
#
# The new branch added by Task 1 sits as branch 2c, INSIDE the existing
# `if bk_with_nachstoss && data["playera"]["balls_goal"].to_i.positive?` block,
# alongside 2a (1521-1527) and 2b (1546-1552). Reuses anstoss_role/anstoss_innings
# locals already in scope (zero recomputation).

# `TableMonitor.data["bk2_options"]` shape (set by clamp_bk_family_params!, table_monitors_controller.rb:534-538)
# {
#   "balls_goal" => Integer,
#   "direkter_zweikampf_max_shots_per_turn" => Integer (1..99, default 2),
#   "serienspiel_max_innings_per_set" => Integer (1..99, default 5)
# }
# Note: this controller helper ALWAYS writes a default 5 if no value submitted (line 525). So
# the new branch can safely rely on the key being present and positive on every BK-family game
# started post-fix. Pre-fix in-flight games whose data was set without going through
# clamp_bk_family_params! must also be tolerated → the `sp_max.positive?` gate handles it.

# Quick-game preset hash (carambus.yml.erb:52)
# - { discipline: "BK2-Kombi", balls_goal: 70, sets_to_win: 2, sets_to_play: 3,
#     label: "BK-2kombi 2/5/70+NS", tiebreak_on_draw: true }
# After Task 2: same hash + bk2_sp_max_innings: 5

# `_quick_game_buttons` BK-family branch (lines 133-157)
# Currently hardcodes innings_goal: 0. Has tiebreak_on_draw passthrough (line 157) as
# precedent for conditional preset-key passthrough.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add inning-limit guard branch to TableMonitor#end_of_set? (engine fix)</name>
  <files>app/models/table_monitor.rb</files>
  <behavior>
    The new branch is **additive** — it only ADDS a new return path. Existing branches MUST continue to work as today.

    Test coverage (delivered in Task 3):
    - BK-2kombi SP-Phase, both players at inning 5, neither at balls_goal, sp_max=5 → returns true.
    - BK-2kombi SP-Phase, playera inning 5, playerb inning 4 (parity NOT met), sp_max=5 → returns false (defer to other branches).
    - BK-2kombi DZ-Phase (current_phase == "direkter_zweikampf"), both at inning 5, neither at balls_goal, sp_max=5 → returns false (DZ-phase exempt).
    - Pure BK-2 (free_game_form == "bk_2"), both at inning 5, neither at balls_goal, sp_max=5 → returns true.
    - Tied score at inning-limit (BK-2kombi SP, both 60/70 at inning 5, sp_max=5) → returns true (tiebreak gate at the level above handles the tie).
    - Regression guard: when sp_max is missing or 0, the new branch is a no-op (existing behavior preserved).

    SKILL extend-before-build is mandatory: ONE small guard branch inside the existing `bk_with_nachstoss` block. NO new method. NO parallel state machine. NO refactor of branches 1-4.
  </behavior>
  <action>
    Edit `app/models/table_monitor.rb` inside `end_of_set?`, **inside** the existing `if bk_with_nachstoss && data["playera"]["balls_goal"].to_i.positive?` block (currently spans lines 1510-1553). Add the new branch **after** the Phase 38.9 branch (line 1552) but **before** the closing `end` at line 1553.

    The locals `anstoss_role`, `nachstoss_role`, `anstoss_innings`, `nachstoss_innings` are already defined at lines 1516-1519 — REUSE them, do NOT recompute.

    Insert this branch (paste verbatim, indentation matches surrounding code):

    ```ruby
          # Quick-260501-uxo: BK-2 / BK-2kombi-SP Aufnahmegrenze (per-set inning limit) close.
          # When `bk2_options.serienspiel_max_innings_per_set` is positive AND both players
          # have completed that many innings, the SP-Phase set MUST close — even if neither
          # reached balls_goal. Tied scores at the limit flow through the existing per-game
          # tiebreak gate (Game.data['tiebreak_required'] set by Plan 04, modal opens at the
          # level above when scores are equal). Non-tied → set closes, higher score wins.
          #
          # Scope: gated by the outer `bk_with_nachstoss` predicate, so this only fires for
          # BK-2 and BK-2kombi SP-Phase. DZ-Phase of BK-2kombi is excluded by construction
          # (bk_with_nachstoss is false there). DZ uses shot-limit per turn, not inning-limit.
          #
          # SKILL extend-before-build: additive branch on existing predicate, NO parallel state
          # machine (validated 2026-04-29: -1463 LOC after rolling back a parallel state machine
          # on this exact surface).
          sp_max = data.dig("bk2_options", "serienspiel_max_innings_per_set").to_i
          if sp_max.positive? && anstoss_innings >= sp_max && nachstoss_innings >= sp_max
            Rails.logger.info "[TableMonitor#end_of_set?] Quick-260501-uxo BK-SP-inning-limit-close: " \
              "form=#{data["free_game_form"]} anstoss=#{anstoss_role}(#{a_result}/#{anstoss_innings}) " \
              "nachstoss=#{nachstoss_role}(#{b_result}/#{nachstoss_innings}) goal=#{goal} " \
              "sp_max=#{sp_max} — both players completed #{sp_max} innings"
            return true
          end
    ```

    DO NOT modify branches 1, 2a, 2b, 3, or 4. DO NOT extract a helper. DO NOT add bk2_kombi_current_phase checks (already gated by bk_with_nachstoss).

    Honors:
    - Memory hint "Extend before build" — additive guard, NO parallel state machine.
    - Memory hint "Tiebreak independent from Discipline" — no new Discipline fields, no new tiebreak path; tied case rides existing Plan 04 `Game.data['tiebreak_required']` gate.
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw && bin/rails test test/models/table_monitor_test.rb 2>&1 | tail -30</automated>
  </verify>
  <done>
    1. `app/models/table_monitor.rb` contains the new guard branch (grep `serienspiel_max_innings_per_set` shows 1 occurrence in `end_of_set?` body).
    2. `bin/rails test test/models/table_monitor_test.rb` returns 0 failures, 0 errors.
    3. The 6 pre-existing `end_of_set?` tests (lines 121-235) continue to pass — regression-clean.
    4. Logger entry on close fires (verifiable via test logs).
  </done>
</task>

<task type="auto">
  <name>Task 2: Thread bk2_sp_max_innings preset key through quick-game form + carambus.yml</name>
  <files>app/views/locations/_quick_game_buttons.html.erb, config/carambus.yml.erb, config/carambus.yml</files>
  <action>
    **Edit 1 — `app/views/locations/_quick_game_buttons.html.erb`** (BK-family branch, around line 149):

    After the existing `<%= hidden_field_tag :innings_goal, 0 %>` line (currently line 149), and before the `<%= hidden_field_tag :first_break_choice, 0 %>` line (currently line 150), add a conditional emission. The cleanest insertion point is between line 149 and line 150. Use the same conditional pattern as the existing `tiebreak_on_draw` precedent (line 157):

    ```erb
              <% if button['bk2_sp_max_innings'].present? %>
                <%# Quick-260501-uxo: per-preset SP-Phase Aufnahmegrenze. When absent,
                    controller#clamp_bk_family_params! applies its default 5 (line 525). %>
                <%= hidden_field_tag 'bk2_options[serienspiel_max_innings_per_set]', button['bk2_sp_max_innings'] %>
              <% end %>
    ```

    Note the form name uses bracket-string syntax `'bk2_options[serienspiel_max_innings_per_set]'` (NOT a symbol) so Rails parses it into nested params — matches the controller's read at table_monitors_controller.rb:521-523.

    DO NOT change the hardcoded `innings_goal: 0` line — that field controls a different (legacy karambol) limit, not the SP-Phase Aufnahmegrenze.

    **Edit 2 — `config/carambus.yml.erb`** (BK-2kombi 2/5/70+NS preset, line 52):

    Add `bk2_sp_max_innings: 5` to the hash. The line currently reads:

    ```yaml
              - { discipline: "BK2-Kombi", balls_goal: 70, sets_to_win: 2, sets_to_play: 3, label: "BK-2kombi 2/5/70+NS", tiebreak_on_draw: true }
    ```

    Change to:

    ```yaml
              - { discipline: "BK2-Kombi", balls_goal: 70, sets_to_win: 2, sets_to_play: 3, label: "BK-2kombi 2/5/70+NS", tiebreak_on_draw: true, bk2_sp_max_innings: 5 }
    ```

    Do NOT modify the other 3 BK-2kombi preset rows (lines 53-55) — those are alternate-config rows the user did not ask to touch in this scope. The "BK-2kombi 2/5/70+NS" preset at line 52 is the canonical tournament preset.

    **Edit 3 — `config/carambus.yml`** (same line 52):

    Apply the identical edit. Per the scenario-management SKILL and the v7.1 Phase 38.4 decision: "carambus.yml (compiled/ignored) must be kept in sync with carambus.yml.erb manually — Carambus.config reads the local .yml, not the .erb template" — both files MUST carry the same value or the runtime won't see the new key.

    **Verification of pass-through (no controller change needed):**
    - The form posts `bk2_options[serienspiel_max_innings_per_set] = 5`.
    - `TableMonitorsController#clamp_bk_family_params!` (lines 521-525) already reads `params[:bk2_options][:serienspiel_max_innings_per_set]`, clamps to 1..99, defaults to 5 if missing.
    - The clamped value lands in `data["bk2_options"]["serienspiel_max_innings_per_set"]` (lines 534-538).
    - Task 1's guard reads it via `data.dig`.

    Honors memory hint: "Scenario management — edits to YAML config go to BOTH carambus.yml.erb AND carambus.yml since both are tracked in this scenario."
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw && bundle exec erblint app/views/locations/_quick_game_buttons.html.erb && grep -n "bk2_sp_max_innings" config/carambus.yml.erb config/carambus.yml app/views/locations/_quick_game_buttons.html.erb</automated>
  </verify>
  <done>
    1. `grep -c "bk2_sp_max_innings: 5" config/carambus.yml.erb` returns 1.
    2. `grep -c "bk2_sp_max_innings: 5" config/carambus.yml` returns 1.
    3. `grep -c "bk2_sp_max_innings" app/views/locations/_quick_game_buttons.html.erb` returns at least 1 (the conditional check).
    4. `grep -c "bk2_options\\[serienspiel_max_innings_per_set\\]" app/views/locations/_quick_game_buttons.html.erb` returns 1.
    5. `bundle exec erblint app/views/locations/_quick_game_buttons.html.erb` returns clean (no new lint failures).
    6. The other 3 BK-2kombi preset rows (yml lines 53-55) are unchanged — no `bk2_sp_max_innings` key on those rows, so they fall through to the controller default 5 unchanged.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Add unit tests for SP-Phase inning-limit branch in end_of_set?</name>
  <files>test/models/table_monitor_test.rb</files>
  <behavior>
    Add 4-5 tests under a new clearly-marked section, immediately after the Phase 38.9 SC-2 test (currently ends around line 235). Use the existing `build_bk_data` helper (lines 107-119) — it already accepts `bk2_options:` keyword.

    Cases:
    1. BK-2kombi SP-Phase, both at inning 5, neither at balls_goal (50 / 60), sp_max=5 → `end_of_set?` returns true.
    2. BK-2kombi SP-Phase, playera inning 5, playerb inning 4, sp_max=5 → returns false (parity not yet met).
    3. BK-2kombi DZ-Phase, both at inning 5, neither at balls_goal, sp_max=5 → returns false (bk_with_nachstoss is false → branch never enters).
    4. Pure BK-2 (free_game_form == "bk_2"), both at inning 5, neither at balls_goal, sp_max=5 → returns true.
    5. Optional regression guard: BK-2kombi SP, both at inning 5, sp_max absent (or 0) → existing legacy behavior (returns false; falls through to legacy karambol gate which also fails because no balls_goal hit) — proves the new branch is a no-op when not configured.
  </behavior>
  <action>
    Edit `test/models/table_monitor_test.rb`. Insert the new test stanza after the Phase 38.9 SC-2 test (currently ending at line 235), before the next section header (currently the Phase 38.7 Plan 05 T9 D-08 section header at ~line 237).

    Pattern to follow: mirror the existing Phase 38.7 + 38.9 test bodies (lines 121-235). Use `build_bk_data` helper. For BK-2kombi SP-Phase scenarios, also set `@tm.data["sets"]` to a 1-entry array (mirrors line 148-149) so `bk2_kombi_current_phase` returns "serienspiel". For BK-2kombi DZ-Phase, leave `data["sets"]` empty (so set_number=1 → DZ-phase per `bk2_kombi_current_phase` logic).

    Test stanza to insert (paste verbatim — adjust only if surrounding line numbers shift):

    ```ruby
      # ---------------------------------------------------------------------------
      # Quick-260501-uxo Plan 01 — BK-2 / BK-2kombi-SP per-set inning limit
      # (Aufnahmegrenze) enforcement.
      #
      # Reads `data["bk2_options"]["serienspiel_max_innings_per_set"]` (default 5,
      # set by TableMonitorsController#clamp_bk_family_params! line 525). When both
      # players have completed sp_max innings, the set MUST close even if neither
      # reached balls_goal. Tied scores flow through the Plan 04 tiebreak gate at
      # the level above; non-tied → higher score wins via standard set-close flow.
      #
      # SKILL extend-before-build: additive branch in the existing bk_with_nachstoss
      # block of end_of_set?. DZ-Phase is exempt by construction (bk_with_nachstoss
      # is false there).
      # ---------------------------------------------------------------------------

      test "end_of_set? closes BK-2kombi SP-Phase when both players reach sp_max innings (260501-uxo)" do
        # SP-Phase: data["sets"] has 1 entry (set #2 with first_set_mode=DZ → SP).
        @tm.data = build_bk_data(free_game_form: "bk2_kombi", balls_goal: 70,
                                 playera_result: 50, playera_innings: 5,
                                 playerb_result: 60, playerb_innings: 5,
                                 bk2_options: {"first_set_mode" => "direkter_zweikampf",
                                               "serienspiel_max_innings_per_set" => 5})
        @tm.data["sets"] = [{"Ergebnis1" => 70, "Ergebnis2" => 50, "Aufnahmen1" => 4, "Aufnahmen2" => 4,
                             "Höchstserie1" => 0, "Höchstserie2" => 0}]
        assert_equal "serienspiel", @tm.bk2_kombi_current_phase,
          "Sanity: SP-Phase fixture must place us in serienspiel"
        assert @tm.end_of_set?,
          "260501-uxo: BK-2kombi SP-Phase with both at inning 5 and sp_max=5 must end_of_set " \
          "(neither at balls_goal — pure inning-limit close, tiebreak modal handles the tied score above)"
      end

      test "end_of_set? does NOT close BK-2kombi SP-Phase when only one player reached sp_max innings (parity guard, 260501-uxo)" do
        @tm.data = build_bk_data(free_game_form: "bk2_kombi", balls_goal: 70,
                                 playera_result: 60, playera_innings: 5,
                                 playerb_result: 50, playerb_innings: 4,
                                 bk2_options: {"first_set_mode" => "direkter_zweikampf",
                                               "serienspiel_max_innings_per_set" => 5})
        @tm.data["sets"] = [{"Ergebnis1" => 70, "Ergebnis2" => 50, "Aufnahmen1" => 4, "Aufnahmen2" => 4,
                             "Höchstserie1" => 0, "Höchstserie2" => 0}]
        refute @tm.end_of_set?,
          "260501-uxo: SP-Phase parity guard — playerb has not yet completed his 5th inning, set stays open"
      end

      test "end_of_set? does NOT close BK-2kombi DZ-Phase on inning limit (DZ-Phase exempt, 260501-uxo)" do
        # DZ-Phase: data["sets"] empty → set_number=1 → first_set_mode=DZ.
        # bk_with_nachstoss is false here, so the new branch never enters. Branches 1
        # and 3 also do not fire (no goal reached). Result: false.
        @tm.data = build_bk_data(free_game_form: "bk2_kombi", balls_goal: 70,
                                 playera_result: 50, playera_innings: 5,
                                 playerb_result: 60, playerb_innings: 5,
                                 bk2_options: {"first_set_mode" => "direkter_zweikampf",
                                               "serienspiel_max_innings_per_set" => 5})
        assert_equal "direkter_zweikampf", @tm.bk2_kombi_current_phase,
          "Sanity: DZ-Phase fixture must place us in direkter_zweikampf"
        refute @tm.end_of_set?,
          "260501-uxo: DZ-Phase has shot-limit per turn (not inning-limit per set) — " \
          "the new SP-Phase guard MUST NOT fire here"
      end

      test "end_of_set? closes pure BK-2 set when both players reach sp_max innings (260501-uxo)" do
        @tm.data = build_bk_data(free_game_form: "bk_2", balls_goal: 50,
                                 playera_result: 40, playera_innings: 5,
                                 playerb_result: 35, playerb_innings: 5,
                                 bk2_options: {"serienspiel_max_innings_per_set" => 5})
        assert @tm.end_of_set?,
          "260501-uxo: pure BK-2 (same engine code as BK-2kombi SP) with both at inning 5 " \
          "and sp_max=5 must end_of_set"
      end

      test "end_of_set? new branch is a no-op when sp_max is missing (regression guard, 260501-uxo)" do
        # No bk2_options at all. Both at inning 5, neither at balls_goal. The new branch
        # gate is `sp_max.positive?` → 0 → branch skipped. Branch 3 (legacy karambol)
        # also fails (no goal). Branch 4 (innings_goal) fails (innings_goal=0). Result: false.
        # This proves the new branch is purely additive — pre-existing in-flight games
        # without bk2_options are unaffected.
        @tm.data = build_bk_data(free_game_form: "bk_2", balls_goal: 50,
                                 playera_result: 40, playera_innings: 5,
                                 playerb_result: 35, playerb_innings: 5)
        refute @tm.end_of_set?,
          "260501-uxo: missing bk2_options.serienspiel_max_innings_per_set must NOT trigger " \
          "the new branch (regression guard for in-flight pre-fix games)"
      end
    ```

    DO NOT modify any pre-existing tests (lines 41-235) or the `build_bk_data` helper (lines 107-119). Order in file: place this section AFTER the Phase 38.9 SC-2 test (which ends with `refute @tm.end_of_set?, "SC-2: ..."` at line 234) and BEFORE the Phase 38.7 Plan 05 T9 section header (currently around line 237).
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw && bin/rails test test/models/table_monitor_test.rb 2>&1 | tail -15</automated>
  </verify>
  <done>
    1. `bin/rails test test/models/table_monitor_test.rb` returns 0 failures, 0 errors.
    2. The new 5 tests show in the runner output (run-count increments by exactly 5).
    3. All pre-existing tests (lines 41-235) continue to pass.
    4. Tests fail RED if Task 1 is reverted (proven by removing Task 1 branch and re-running — should produce 2 failures from "BK-2kombi SP-Phase closes" and "pure BK-2 closes" tests).
  </done>
</task>

</tasks>

<verification>
End-to-end verification (covers all 3 tasks):

1. **Engine guard fires:** `bin/rails test test/models/table_monitor_test.rb` → 0 failures, run-count = previous + 5.
2. **Form passthrough:** `grep -nE "bk2_sp_max_innings|bk2_options\\[serienspiel_max_innings_per_set\\]" app/views/locations/_quick_game_buttons.html.erb config/carambus.yml.erb config/carambus.yml` shows the key in all 3 files (yml × 2, erb × 1, view × 2).
3. **No regression:** `bin/rails test test/models/table_monitor_test.rb test/system/bk2_scoreboard_test.rb` → no NEW failures (the 19 pre-existing bk2_scoreboard_test failures noted in STATE.md "Phase 38.9 Plan 01" entry are out of scope and remain as-is).
4. **Lint:** `bundle exec erblint app/views/locations/_quick_game_buttons.html.erb` clean.
5. **Manual sanity (user-driven, not gated):** start a BK-2kombi 2/5/70+NS game, drive both players to inning 5 without reaching 70, observe set closes (Logger line `Quick-260501-uxo BK-SP-inning-limit-close` in `log/development.log`).
</verification>

<success_criteria>
- BK-2kombi SP-Phase set closes when both players have completed `bk2_options.serienspiel_max_innings_per_set` innings (default 5).
- DZ-Phase of BK-2kombi remains unchanged (no inning-limit fire).
- Pure BK-2 also benefits (same engine code).
- Tied score at inning limit triggers the existing Plan 04 tiebreak modal (no new tiebreak path added).
- Inning limit is configurable per preset via `bk2_sp_max_innings` key in `config/carambus.yml` (and `.erb`).
- All 5 new unit tests pass.
- All pre-existing `end_of_set?` tests (lines 121-235 of table_monitor_test.rb) still pass.
- No parallel state machine introduced (SKILL extend-before-build honored).
- Both `config/carambus.yml.erb` and `config/carambus.yml` carry the new key (scenario-management SKILL honored).
</success_criteria>

<output>
After completion, create `.planning/quick/260501-uxo-bk-2kombi-enforce-sp-phase-inning-limit-/260501-uxo-SUMMARY.md` documenting:
- Files changed + line counts
- Test results (run-count, assertions, failures)
- Confirmation that the 5 new tests turned RED before Task 1 and GREEN after
- Confirmation of the SKILL extend-before-build compliance (no parallel state machine, additive branch only)
- Note: ready for BCW Grand Prix on 2026-05-02 once user pulls/deploys
</output>
