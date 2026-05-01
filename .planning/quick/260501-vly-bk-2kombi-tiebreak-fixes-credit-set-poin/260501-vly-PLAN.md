---
phase: 260501-vly
quick_task: 260501-vly
plan: 01
type: execute
wave: 1
depends_on: []
autonomous: true
title: BK-2kombi tiebreak fixes — credit set point + Detail Page default + unified inning display
subsystem: scoring-engine, scoreboard-views
tags: [bk2-kombi, bk-2, tiebreak, set-credit, scoreboard, detail-form, inning-display, extend-before-build]
requirements: [QUICK-260501-vly-01, QUICK-260501-vly-02, QUICK-260501-vly-03]
files_modified:
  - app/services/table_monitor/result_recorder.rb
  - test/services/table_monitor/result_recorder_test.rb
  - app/views/locations/scoreboard_free_game_karambol_new.html.erb
  - app/views/table_monitors/_scoreboard.html.erb

must_haves:
  truths:
    - "Tiebreak winner pick (BK-2kombi BK-2-phase or pure BK-2) credits one set point to the picked side after evaluate_result, allowing match to complete"
    - "Detail Page (scoreboard_free_game_karambol_new) defaults the tiebreak_on_draw checkbox to checked when bk_selected_form is bk_2 / bk_2plus / bk2_kombi (matching Quickstart preset behaviour)"
    - "Detail Page tiebreak_on_draw checkbox stays unchecked by default for non-BK-family disciplines (karambol, kegel, snooker, pool) and for BK50 / BK100"
    - "Quickstart BK-family scoreboard inning display shows 'N of M' (M = bk2_options.serienspiel_max_innings_per_set) instead of bare 'N' when innings_goal is 0 and the SP-phase inning limit is configured"
    - "Existing Plan 38.7-05 / 38.7-07 behaviour preserved: ba_results['TiebreakWinner'] indicator still set for PDF; non-tied scores still credit Sets1/Sets2 from score comparison only (no double-counting)"
  artifacts:
    - path: app/services/table_monitor/result_recorder.rb
      provides: "Tied-score set-credit branch inside the existing tw is_a?(String) && whitelist guard"
      contains: "ba_results[\"Sets"
    - path: test/services/table_monitor/result_recorder_test.rb
      provides: "5 unit tests pinning tied/tiebreak_required/tw cross-product behaviour"
      min_lines: 40
    - path: app/views/locations/scoreboard_free_game_karambol_new.html.erb
      provides: "x-bind:checked Alpine binding on tiebreak_on_draw checkbox keyed off bk_selected_form"
      contains: "x-bind:checked"
    - path: app/views/table_monitors/_scoreboard.html.erb
      provides: "display_innings_goal local variable + fallback to bk2_options.serienspiel_max_innings_per_set when innings_goal=0 in BK-2 / BK-2kombi-SP context"
      contains: "display_innings_goal"
  key_links:
    - from: "result_recorder.rb#update_ba_results_with_set_result!"
      to: "ba_results['Sets1']/['Sets2'] / TiebreakWinner indicator"
      via: "tied + tiebreak_required==true + tw whitelist branch"
      pattern: "tiebreak_required.*Sets1|tiebreak_required.*Sets2"
    - from: "scoreboard_free_game_karambol_new.html.erb tiebreak_on_draw checkbox"
      to: "Alpine bk_selected_form state slot (line 220)"
      via: "x-bind:checked expression with 3-element whitelist"
      pattern: "x-bind:checked.*bk_selected_form"
    - from: "_scoreboard.html.erb inning-display lines 120 + 127"
      to: "options.dig(:bk2_options, 'serienspiel_max_innings_per_set')"
      via: "display_innings_goal ERB local"
      pattern: "display_innings_goal"
---

<objective>
Three independent BK-2kombi-tournament tiebreak/inning-display bugs, all blocking the BCW Grand Prix on 2026-05-02.

1. **Bug 1 (engine)** — Tiebreak winner pick records `ba_results["TiebreakWinner"]` indicator but does NOT increment `Sets1` / `Sets2`, so match never completes when picked tiebreak should decide a tied set. **Pre-existing latent defect** introduced when Plan 38.7-05 added the indicator without the credit branch.
2. **Bug 2 (Detail Page UX)** — `scoreboard_free_game_karambol_new.html.erb` defaults tiebreak_on_draw checkbox to UNCHECKED, while Quickstart preset gives it `tiebreak_on_draw: true` for BK-2 / BK-2kombi disciplines — divergent UX between the two start paths.
3. **Bug 3 (display)** — Detail Page sets `innings_goal: 5` (karambol-style), Quickstart hardcodes `innings_goal: 0` for BK-family. Result: "3 of 5" on Detail-Page-started games but bare "3" on Quickstart-started games for the SAME engine semantics. Display divergence only — engine already enforces the limit (Quick-260501-uxo) via `bk2_options.serienspiel_max_innings_per_set`.

Purpose: make tiebreak pick actually credit the set so matches close (Bug 1, blocker); align Detail Page tiebreak default with Quickstart preset (Bug 2, UX consistency); align inning-counter display across both start paths (Bug 3, UX consistency).

Output: 4 files modified (1 service, 1 test, 2 views); 5 new unit tests in result_recorder_test.rb; manual smoke notes for Bug 2 + Bug 3 captured in SUMMARY.md.

CONSERVATIVE GATES (user-confirmed "ja bitte"):
- Bug 1 set-credit only when `@tm.game.data["tiebreak_required"] == true` (legacy/edge data untouched).
- Bug 2 default-checked only for `bk_selected_form ∈ {bk_2, bk_2plus, bk2_kombi}` (BK50 / BK100 excluded — single-set games, no classical tiebreak shootout pattern).
</objective>

<execution_context>
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/workflows/execute-plan.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@.agents/skills/extend-before-build/SKILL.md
@.agents/skills/scenario-management/SKILL.md
@.planning/quick/260501-uxo-bk-2kombi-enforce-sp-phase-inning-limit-/260501-uxo-SUMMARY.md

<interfaces>
<!-- Key contracts the executor needs. Pre-extracted from the codebase so no scavenger hunt. -->

From app/services/table_monitor/result_recorder.rb (current — Phase 38.7 Plan 05):
```ruby
def update_ba_results_with_set_result!(game_set_result)
  ba_results = @tm.data&.[]("ba_results") || { ... defaults ... }
  if game_set_result["Ergebnis1"].to_i > game_set_result["Ergebnis2"].to_i
    ba_results["Sets1"] = ba_results["Sets1"].to_i + 1
  end
  if game_set_result["Ergebnis1"].to_i < game_set_result["Ergebnis2"].to_i
    ba_results["Sets2"] = ba_results["Sets2"].to_i + 1
  end
  ba_results["Ergebnis1"] = ba_results["Ergebnis1"].to_i + game_set_result["Ergebnis1"].to_i
  ba_results["Ergebnis2"] = ba_results["Ergebnis2"].to_i + game_set_result["Ergebnis2"].to_i
  ba_results["Aufnahmen1"] = ba_results["Aufnahmen1"].to_i + game_set_result["Aufnahmen1"].to_i
  ba_results["Aufnahmen2"] = ba_results["Aufnahmen2"].to_i + game_set_result["Aufnahmen2"].to_i
  ba_results["Höchstserie1"] = [...].max
  ba_results["Höchstserie2"] = [...].max
  # Phase 38.7 Plan 05 — D-08:
  tw = @tm.game.data&.[]("tiebreak_winner")
  if tw.is_a?(String) && %w[playera playerb].include?(tw)
    ba_results["TiebreakWinner"] = {"playera" => 1, "playerb" => 2}[tw]
    # ← NEW BRANCH GOES HERE: credit Sets1/Sets2 if tied AND tiebreak_required.
  end
  @tm.deep_merge_data!("ba_results" => ba_results)
end
```

From app/views/locations/scoreboard_free_game_karambol_new.html.erb (Alpine x-data scope, line ~220):
```javascript
{
  bk_selected_form: null,           // 'bk_2' | 'bk_2plus' | 'bk2_kombi' | 'bk50' | 'bk100' | null
  get is_bk_family() { return ['bk2_kombi','bk_2plus','bk_2','bk50','bk100'].includes(this.bk_selected_form); },
  get is_bk_dz_configurable() { return this.bk_selected_form === 'bk_2plus' || this.bk_selected_form === 'bk2_kombi'; },
  get is_bk_sp_configurable() { return this.bk_selected_form === 'bk_2' || this.bk_selected_form === 'bk2_kombi'; },
  // ... no existing 3-way "supports tiebreak" predicate; inline whitelist needed
}
```

From app/views/table_monitors/_scoreboard.html.erb (locals already in scope at lines 120/127):
```erb
options[:innings_goal]            # int — 0 for Quickstart BK-family, 5 for Detail-Page
options[:free_game_form]          # 'bk_2' | 'bk2_kombi' | 'bk50' | ...
options[:bk2_options]              # Hash with STRING keys (JSON round-trip via tm.data)
                                   # options.dig(:bk2_options, 'serienspiel_max_innings_per_set')
bk2_current_phase                 # 'direkter_zweikampf' | 'serienspiel' (line 65)
is_bk2                            # boolean — 5-BK-family check (line 53)
is_bk2_kombi                      # boolean — single-form bk2_kombi check (line 55)
```

Verified key shape: `bk2_options` is round-tripped through `TableMonitor.data` (JSON column) — STRING keys, NOT symbol keys. Reach via `options.dig(:bk2_options, "serienspiel_max_innings_per_set")` — `:bk2_options` key on the options hash itself is a symbol (set by the controller serializer); the inner key is the string from JSON.

From test/services/table_monitor/result_recorder_test.rb (existing structure to mirror):
```ruby
# Existing tests use stub-and-restore via @tm = TableMonitor.find(...) helper +
# game.update!(data: …) to seed @tm.game.data['tiebreak_winner']/['tiebreak_required'].
# Look for existing tests touching update_ba_results_with_set_result! for the helper
# pattern. Add the 5 new tests under a clearly labeled "Quick-260501-vly Plan 01"
# header per the project convention used in 260501-uxo.
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Bug 1 — Credit Sets1/Sets2 on tiebreak winner pick (engine fix + 5 tests)</name>
  <files>app/services/table_monitor/result_recorder.rb, test/services/table_monitor/result_recorder_test.rb</files>
  <behavior>
    Inside the existing `if tw.is_a?(String) && %w[playera playerb].include?(tw)` block at lines 148-150 of result_recorder.rb, add a tied-score + tiebreak_required gate that credits Sets1 / Sets2 alongside the existing TiebreakWinner indicator assignment.

    Test contract (5 RED-then-GREEN tests, all in test/services/table_monitor/result_recorder_test.rb under a "# Quick-260501-vly Plan 01" header):

    - Test 1 (close branch playera): tied (Ergebnis1 == Ergebnis2 == 50), tiebreak_required=true, tiebreak_winner='playera' → ba_results['Sets1'] = 1, ba_results['Sets2'] = 0, ba_results['TiebreakWinner'] = 1
    - Test 2 (close branch playerb): tied (50 == 50), tiebreak_required=true, tiebreak_winner='playerb' → ba_results['Sets2'] = 1, ba_results['Sets1'] = 0, ba_results['TiebreakWinner'] = 2
    - Test 3 (regression — missing tw): tied, tiebreak_required=true, tiebreak_winner missing/nil → neither Sets1 nor Sets2 incremented; TiebreakWinner key absent (preserves Plan 38.7-05 contract)
    - Test 4 (conservative gate — tiebreak_required=false): tied, tiebreak_required=false, tiebreak_winner='playera' → neither Sets1 nor Sets2 incremented; TiebreakWinner indicator IS still set to 1 (legacy/edge data preserved per user-confirmed Q1 "ja bitte")
    - Test 5 (no double-count — non-tied path): Ergebnis1=70 > Ergebnis2=45, tiebreak_required=true, tiebreak_winner='playera' → ba_results['Sets1'] = 1 (from score comparison), NOT 2 (regression guard against double-counting)

    Test execution: RED first (without the new branch), then GREEN after Task 1 implementation. Document RED-then-GREEN proof in commit message body.
  </behavior>
  <action>
    **Step A — Locate exact insertion point.** Read app/services/table_monitor/result_recorder.rb lines 130-152. The existing `if tw.is_a?(String) && %w[playera playerb].include?(tw)` block at line 148 closes at line 150. Insert the new branch INSIDE the block, after the TiebreakWinner indicator assignment at line 149, BEFORE the closing `end` at line 150.

    **Step B — Write the 5 RED tests first.** In test/services/table_monitor/result_recorder_test.rb, find the existing test for `update_ba_results_with_set_result!` (grep for `update_ba_results_with_set_result` — it has at least one test from Phase 38.7 Plan 05). Reuse that test's setup helper if one exists, or seed @tm.game.data with `'tiebreak_required' => true/false` and `'tiebreak_winner' => 'playera'/'playerb'/nil` directly via `@tm.game.update_columns(data: {...}.to_json)` mirroring the Phase 38.7-05 stub-and-restore pattern. Run RED:
    ```
    bin/rails test test/services/table_monitor/result_recorder_test.rb -n /Quick.260501.vly/
    ```
    Expect Tests 1, 2 to FAIL (close branch missing). Tests 3, 4, 5 may PASS by current behaviour — they are regression guards. Document actual RED count in commit body.

    **Step C — Implement the new branch.** Edit app/services/table_monitor/result_recorder.rb. Inside the `if tw.is_a?(String) && %w[playera playerb].include?(tw)` block (line 148), add this branch AFTER `ba_results["TiebreakWinner"] = ...` and BEFORE the closing `end`:

    ```ruby
    # Quick-260501-vly Plan 01 — Bug 1: credit Sets1/Sets2 when picked tiebreak
    # decides a tied set. Conservative gate: tiebreak_required==true only,
    # leaves legacy/edge data unchanged (user-confirmed Q1 2026-05-01 "ja bitte").
    # Existing TiebreakWinner indicator above is preserved for Plan 38.7-07 PDF.
    if game_set_result["Ergebnis1"].to_i == game_set_result["Ergebnis2"].to_i &&
       @tm.game.data&.[]("tiebreak_required") == true
      if tw == "playera"
        ba_results["Sets1"] = ba_results["Sets1"].to_i + 1
      else  # tw == "playerb" — whitelist already enforced by outer if-condition
        ba_results["Sets2"] = ba_results["Sets2"].to_i + 1
      end
    end
    ```

    Note 1: `@tm.game.data&.[]("tiebreak_required") == true` is strict — only Boolean-true gates the credit. Truthy strings ("true", "1") do NOT pass; they need to be normalized upstream (already handled by Phase 38.7 Plan 09's controller normalization).

    Note 2: outer if-condition (`tw.is_a?(String) && %w[playera playerb].include?(tw)`) already enforces the whitelist, so `else` is safe to mean playerb without re-checking.

    **Step D — Run GREEN.**
    ```
    bin/rails test test/services/table_monitor/result_recorder_test.rb -n /Quick.260501.vly/
    bin/rails test test/services/table_monitor/result_recorder_test.rb
    ```
    Expect 5/5 new tests GREEN, full test file GREEN (no regressions).

    **Step E — RED-then-GREEN proof for SUMMARY.** Temporarily comment out the new `if … == game_set_result …` block, re-run the 5 tests, confirm Tests 1+2 FAIL (Tests 3,4,5 still GREEN), restore the branch. Document failure count in SUMMARY (mirrors 260501-uxo Self-Check pattern).

    **Skill compliance — extend-before-build:** ONE additive guard branch INSIDE the existing block. NO new method extraction. NO parallel state machine. Existing TiebreakWinner indicator unchanged. Lines 130-147 unchanged. Outer if-condition (148) unchanged.
  </action>
  <verify>
    <automated>bin/rails test test/services/table_monitor/result_recorder_test.rb</automated>
  </verify>
  <done>
    - app/services/table_monitor/result_recorder.rb has the new tied + tiebreak_required + tw branch inside the existing `tw.is_a?(String) && whitelist` block (between current lines 149 and 150)
    - test/services/table_monitor/result_recorder_test.rb has 5 new tests under "# Quick-260501-vly Plan 01" header
    - `bin/rails test test/services/table_monitor/result_recorder_test.rb` GREEN (preserves all pre-existing tests)
    - RED-then-GREEN proof documented in commit body (Tests 1+2 fail before fix; 5/5 GREEN after)
    - Existing Plan 38.7-05 contract preserved: TiebreakWinner indicator still set; non-tied score path UNCHANGED (Test 5)
  </done>
</task>

<task type="auto">
  <name>Task 2: Bug 2 — Detail Page tiebreak_on_draw default-checked for BK-2 / BK-2plus / BK-2kombi</name>
  <files>app/views/locations/scoreboard_free_game_karambol_new.html.erb</files>
  <action>
    **Step A — Locate.** Read app/views/locations/scoreboard_free_game_karambol_new.html.erb lines 642-653 (the `tiebreak_on_draw` div block). Confirm the structure matches the Phase 38.7 Plan 10 (Gap-02) pattern: hidden_field_tag '0' + check_box_tag '1' false.

    **Step B — Edit ONLY line 650.** Add an `x-bind:checked` Alpine binding using a 3-element inline whitelist (matches user-confirmed Q2 "ja bitte" — BK50 / BK100 explicitly excluded):

    Before (current line 650):
    ```erb
    <%= check_box_tag :tiebreak_on_draw, "1", false, class: "p-1 text-2vw mr-4" %>
    ```

    After:
    ```erb
    <%= check_box_tag :tiebreak_on_draw, "1", false,
        class: "p-1 text-2vw mr-4",
        "x-bind:checked": "['bk_2', 'bk_2plus', 'bk2_kombi'].includes(bk_selected_form)" %>
    ```

    Notes:
    - Alpine `bk_selected_form` lives in the singular x-data wrapper at line 184 (Phase 38.2-02 GAP-02 invariant; line 220 in current file). Confirmed in scope.
    - Inline whitelist (NOT `is_bk_family`) because we EXCLUDE bk50/bk100 by user policy. No new Alpine getter needed — inline is shorter, more honest about coupling, matches extend-before-build's "small guard" preference.
    - The visible checkbox is the user-bound element; user can still uncheck manually if they want — only the DEFAULT changes. Hidden field at line 649 (`<%= hidden_field_tag :tiebreak_on_draw, "0" %>`) UNCHANGED — it provides the explicit-false sparse override per Plan 38.7-10 D-decision.
    - The third positional arg to `check_box_tag` (`false` for "checked?") stays — Rails uses it as the server-render default before Alpine hydrates. Alpine's x-bind:checked overrides on hydration. Brief flash of unchecked state on slow JS loads is acceptable for the BCW operator UX.

    **Step C — ERB lint check:**
    ```
    bundle exec erblint app/views/locations/scoreboard_free_game_karambol_new.html.erb
    ```
    Expect clean (no new violations).

    **Step D — Manual smoke (write notes, do not block on the smoke test):** In SUMMARY, document the manual smoke procedure for the user — verifier loads `/scoreboards/free_game_karambol/new` for a BCW location, picks Kegel→BK-2kombi, observes the tiebreak_on_draw checkbox is now CHECKED by default; switches to BK50/BK100 — observes the checkbox UNCHECKS; switches to Kegel→EUROK (sets bk_selected_form=null) — observes the checkbox UNCHECKS. Verifier runs a single Detail-Page-started BK-2kombi match through to a tied set + tiebreak modal pick + match-close to validate the full Bug 1 + Bug 2 chain end-to-end.

    **Skill compliance — extend-before-build:** ONE attribute added to ONE existing element. Hidden field UNCHANGED. Surrounding div / label / i18n key UNCHANGED. NO new Alpine getter (inline whitelist preferred over polluting x-data scope with `is_bk_supports_tiebreak`).
  </action>
  <verify>
    <automated>bundle exec erblint app/views/locations/scoreboard_free_game_karambol_new.html.erb</automated>
  </verify>
  <done>
    - Line 650 of scoreboard_free_game_karambol_new.html.erb carries `"x-bind:checked": "['bk_2', 'bk_2plus', 'bk2_kombi'].includes(bk_selected_form)"`
    - Hidden field at line 649 unchanged (sparse-override semantics preserved)
    - erblint clean
    - Manual smoke procedure documented in SUMMARY for the user (3 cases: BK-2kombi → checked; BK50/BK100 → unchecked; EUROK → unchecked)
  </done>
</task>

<task type="auto">
  <name>Task 3: Bug 3 — Quickstart BK-family inning display "N of M" fallback</name>
  <files>app/views/table_monitors/_scoreboard.html.erb</files>
  <action>
    **Step A — Locate.** Read app/views/table_monitors/_scoreboard.html.erb lines 110-130. Confirm two display sites:
    - Line 120: BK-2kombi serienspiel inning counter (Quick-260501-sbz path)
    - Line 127: karambol-style inning-of-goal counter (legacy path; Detail Page uses this with innings_goal=5)

    NOTE: line 131 in `_player_score_panel.html.erb` uses `innings_goal` for the "1 left" warning — DO NOT modify that path. It's a different display semantic (warning that current player has 1 inning left to reach goal); falls back to no-warning when innings_goal=0, which is correct for BK-family. Bug 3 fix is scoped to `_scoreboard.html.erb` lines 120 + 127 only.

    **Step B — Add ERB local at top of relevant section.** Insert immediately AFTER line 56 (or wherever `is_bk2_kombi` is defined; locate via grep `is_bk2_kombi = options[:free_game_form]`), BEFORE the existing inning-display markup. The local should compute the display ceiling once, used by both lines 120 and 127:

    ```erb
    <%# Quick-260501-vly Plan 01 — Bug 3: unified inning display.
        Quickstart hardcodes innings_goal=0 for BK-family (preset _quick_game_buttons.html.erb:149);
        Detail Page sets it via karambol-style innings_choice radio (typically 5).
        Display divergence: Detail-Page games show "3 of 5", Quickstart games show bare "3"
        for IDENTICAL engine semantics. Fall back to bk2_options.serienspiel_max_innings_per_set
        when innings_goal is 0 in BK-2 / BK-2kombi-SP context (set by Quick-260501-uxo via
        clamp_bk_family_params! and round-tripped through tm.data as STRING-keyed Hash).

        Pure view-layer change — engine semantics UNAFFECTED. %>
    <%- bk_sp_inning_phase = options[:free_game_form] == "bk_2" ||
        (options[:free_game_form] == "bk2_kombi" && bk2_current_phase == "serienspiel") %>
    <%- display_innings_goal = options[:innings_goal].to_i.positive? ?
        options[:innings_goal].to_i :
        (bk_sp_inning_phase ? options.dig(:bk2_options, "serienspiel_max_innings_per_set").to_i : 0) %>
    ```

    Rationale for predicate:
    - `bk_2` (pure BK-2 single-set): always inning-limited, fallback applies
    - `bk2_kombi` + `bk2_current_phase == "serienspiel"`: SP-phase inning-limited, fallback applies
    - `bk2_kombi` + DZ-phase: DZ has no inning limit (Plan 38.7-02 D-02 follow_up logic, not bk2_options); fallback DOES NOT apply, display falls back to no "of M"
    - bk50/bk100/bk_2plus: single-set fixed-goal, no SP inning limit; no fallback

    **Step C — Update line 120 (BK-2kombi serienspiel inning counter):**

    Before:
    ```erb
    <%= bk2_current_inning %><%- if options[:innings_goal].to_i > 0 %> <%= t("of") %> <%= options[:innings_goal].to_i %><%- end %>
    ```

    After:
    ```erb
    <%= bk2_current_inning %><%- if display_innings_goal > 0 %> <%= t("of") %> <%= display_innings_goal %><%- end %>
    ```

    **Step D — Update line 127 (karambol-style inning-of-goal counter):**

    Before:
    ```erb
    <%- unless (table_monitor.tournament_monitor.is_a?(TournamentMonitor) && table_monitor.tournament_monitor.andand.tournament.andand.handicap_tournier?) || options[:innings_goal].to_i == 0 %>
      <div class="h-1/6 items-center text-<%= vw2 %> justify-center text-center"><%= t('of') %> <%= options[:innings_goal].to_i %></div>
    <%- end %>
    ```

    After:
    ```erb
    <%- unless (table_monitor.tournament_monitor.is_a?(TournamentMonitor) && table_monitor.tournament_monitor.andand.tournament.andand.handicap_tournier?) || display_innings_goal == 0 %>
      <div class="h-1/6 items-center text-<%= vw2 %> justify-center text-center"><%= t('of') %> <%= display_innings_goal %></div>
    <%- end %>
    ```

    Note: line 127 also gates on `table_monitor.tournament_monitor.is_a?(TournamentMonitor) && handicap_tournier?` — that gate UNCHANGED (handicap suppresses the display regardless of fallback). Only the `options[:innings_goal].to_i == 0` clause and the value reference are swapped to `display_innings_goal`.

    **Step E — String-key shape verification.** Confirm `options[:bk2_options]` is a Hash with STRING keys (NOT symbols). Inspection: `tm.data` is a JSON column, round-tripped via `JSON.parse(... { symbolize_names: false })` (Rails default for JSON columns). The controller serializer copies `tm.data["bk2_options"]` straight into `options[:bk2_options]`, preserving string keys. Therefore:
    - WORKS: `options.dig(:bk2_options, "serienspiel_max_innings_per_set")` ✓
    - DOES NOT WORK: `options.dig(:bk2_options, :serienspiel_max_innings_per_set)` ✗

    The implementation in Step B uses the string key. If a future runtime check shows symbol keys (unlikely but possible), the executor must verify by running a Quickstart BK-2kombi 2/5/70+NS match in BCW dev and confirming the "3 of 5" display appears in inning 3. This shape-check is the verifier's primary smoke test.

    **Step F — ERB lint check:**
    ```
    bundle exec erblint app/views/table_monitors/_scoreboard.html.erb
    ```

    **Step G — Manual smoke notes for SUMMARY:** Verifier starts a Quickstart BK-2kombi 2/5/70+NS match, drives to inning 3, observes "3 of 5" display in the inning panel; switches to a Detail-Page-started BK-2kombi match (innings_goal=5 explicit), observes "3 of 5" UNCHANGED (regression guard); starts a karambol match (no bk2_options), observes "3 of 5" UNCHANGED via Detail Page or no display via Quickstart (no SP-phase predicate match, fallback no-op).

    **Skill compliance — extend-before-build:** ONE local variable added at section top + 2 line-edits at sites 120 + 127. NO new partial. NO new helper method. NO engine semantic change. Existing handicap-tournier guard at line 127 preserved verbatim.
  </action>
  <verify>
    <automated>bundle exec erblint app/views/table_monitors/_scoreboard.html.erb</automated>
  </verify>
  <done>
    - app/views/table_monitors/_scoreboard.html.erb defines `display_innings_goal` ERB local near top of section (after `is_bk2_kombi` ~line 56)
    - Line 120 references `display_innings_goal` instead of `options[:innings_goal].to_i`
    - Line 127 references `display_innings_goal` instead of `options[:innings_goal].to_i` (handicap-tournier gate preserved)
    - Predicate `bk_sp_inning_phase` correctly excludes BK-2kombi DZ-phase, BK-2plus, BK50, BK100, karambol, snooker, pool
    - String-key shape note in SUMMARY: `options.dig(:bk2_options, "serienspiel_max_innings_per_set")` is the canonical access pattern (JSON-column round-trip)
    - erblint clean
    - Manual smoke procedure documented in SUMMARY (3 cases: Quickstart BK-2kombi shows "3 of 5"; Detail Page BK-2kombi unchanged; karambol unchanged)
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| operator → check_box_tag (Bug 2) | Operator can manually uncheck even when defaulted-checked — operator-trust boundary, not adversarial |
| operator → tiebreak_winner radio (Bug 1 indirect) | Operator picks playera/playerb; whitelist enforced upstream by Phase 38.7-06 reflex (allowlist guard at confirm_result reflex) |
| `tm.game.data` JSON read (Bug 1) | Phase 38.7-04 Game.derive_tiebreak_required + Plan 09 controller normalization populate `tiebreak_required` as Boolean true/false; Bug 1 strictly compares `== true` so non-canonical truthy values do NOT credit |
| `options[:bk2_options]` JSON read (Bug 3) | Set by TableMonitorsController#clamp_bk_family_params! (table_monitors_controller.rb:521-525, Phase 38.4 D-07 — clamps to 1..99, defaults to 5 if missing); shape: STRING-keyed Hash from JSON round-trip |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-vly-01 | Tampering | result_recorder.rb update_ba_results_with_set_result! tied-credit branch | mitigate | Outer guard `tw.is_a?(String) && %w[playera playerb].include?(tw)` (line 148) UNCHANGED — whitelist enforces playera/playerb only; new branch inherits this whitelist via the if/else split. Strict `== true` comparison on `tiebreak_required` rejects non-Boolean truthy values. |
| T-vly-02 | Tampering | tiebreak_required Boolean field | accept | Already mitigated by Phase 38.7 Plan 09 controller normalization + Plan 04 Game.derive_tiebreak_required (4-level resolver with sparse-override). Bug 1 only adds a strict-Boolean read. No new attack surface. |
| T-vly-03 | Information Disclosure | Detail Page tiebreak default-checked (Bug 2) | accept | No PII; UI default change only. Worst case: operator unchecks manually if they want non-tiebreak semantics on a BK-2kombi match. Hidden field at line 649 still provides the explicit-false fallback. |
| T-vly-04 | Denial of Service | display_innings_goal computation (Bug 3) | accept | Pure-function ERB local computed once per render; constant-time; no DB access. `options.dig` returns nil safely on missing keys; `.to_i` on nil returns 0; predicate `bk_sp_inning_phase` is short-circuit boolean. No DoS surface. |
| T-vly-05 | Repudiation | Set-credit on tiebreak winner pick (Bug 1) | mitigate | PaperTrail UNCHANGED — Game.update! (which writes `tiebreak_winner` upstream in Phase 38.7-06 reflex) creates a paper_trail version. The Bug 1 fix only modifies `@tm.data` via `deep_merge_data!` (existing line 151), already paper-trailed via TableMonitor's PaperTrail config. Auditability preserved. |
| T-vly-06 | Elevation of Privilege | Bug 2 default-checked bypass | n/a | Bug 2 is operator-facing UX default change, not an authz boundary. Hidden `tiebreak_on_draw=0` field at line 649 + check_box_tag's '1' value yield identical sparse-override semantics regardless of default-checked state. Reflex/controller validation (Plan 38.7-09 / -10) UNCHANGED. |
</threat_model>

<verification>
- `bin/rails test test/services/table_monitor/result_recorder_test.rb` — 5 new tests GREEN; entire file GREEN (no regressions in pre-existing Plan 38.7-05 tests)
- `bundle exec erblint app/views/locations/scoreboard_free_game_karambol_new.html.erb` clean
- `bundle exec erblint app/views/table_monitors/_scoreboard.html.erb` clean
- `bin/rails test test/models/table_monitor_test.rb` GREEN (regression guard for Quick-260501-uxo's 26 tests — bk2_options pipeline UNCHANGED)
- `bin/rails test test/system/tiebreak_test.rb` GREEN (Phase 38.7-08 system test must pass — confirms tiebreak modal flow still works end-to-end)
- Manual smoke (user-driven, not gated):
  - Bug 1: Quickstart BK-2kombi 2/5/70+NS, drive both players to tied SP-phase inning limit, pick tiebreak winner via modal, confirm match closes (Sets1=2 or Sets2=2 in ba_results, depending on full match outcome)
  - Bug 2: Open `/scoreboards/free_game_karambol/new`, switch Kegel→BK-2kombi, observe tiebreak_on_draw checkbox is CHECKED; switch to BK50, observe UNCHECKED; switch to BK-2plus, observe CHECKED
  - Bug 3: Quickstart BK-2kombi 2/5/70+NS in inning 3, observe "3 of 5" in inning panel (not bare "3")
</verification>

<success_criteria>
- All 3 bugs fixed in 1 single quick plan, 3 tasks, ≤4 files modified
- 5 RED-then-GREEN unit tests for Bug 1 in test/services/table_monitor/result_recorder_test.rb
- All existing tests preserved (no regressions in result_recorder_test.rb, table_monitor_test.rb, tiebreak_test.rb)
- erblint clean on both modified .html.erb files
- extend-before-build SKILL upheld: NO parallel state machine, NO new method extraction, NO new helper, additive guards / inline x-bind / single ERB local only
- Memory hint "Tiebreak independent from Discipline" upheld: NO Discipline schema or seed changes (all 3 fixes ride existing per-game `Game.data['tiebreak_required']` + per-TM `bk2_options` paths)
- Memory hint "carambus.yml gitignored locally" upheld: NO carambus.yml or carambus.yml.erb edits in this plan (no new YAML keys needed)
- Manual smoke notes documented in SUMMARY for user verification before tournament 2026-05-02 morning
- 3 commits (one per task, conventional commit format) on master branch ready for `git push` + Capistrano deploy
</success_criteria>

<output>
After completion, create `.planning/quick/260501-vly-bk-2kombi-tiebreak-fixes-credit-set-poin/260501-vly-SUMMARY.md` mirroring the 260501-uxo SUMMARY structure:
- Frontmatter: quick_task, plan, title, subsystem, tags, requirements, status, completed_at, duration_minutes, commits[], files_modified[], test_results { before / after / delta }, red_then_green
- Sections: One-liner / Goal / Files Changed table / Test Results (with RED-then-GREEN proof for Bug 1) / SKILL Compliance (extend-before-build, scenario-management, memory hints) / Manual smoke procedure (Bugs 2 + 3) / Self-Check checklist / Ready for tournament 2026-05-02 user actions
</output>
