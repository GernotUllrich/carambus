---
phase: 260505-fbb
plan: "01"
type: execute
wave: 1
depends_on: []
files_modified:
  - app/models/game.rb
  - app/controllers/table_monitors_controller.rb
  - app/controllers/tournament_monitors_controller.rb
  - app/views/tournament_monitors/_form.html.erb
  - app/views/locations/_quick_game_buttons.html.erb
  - app/views/locations/scoreboard_free_game_karambol_new.html.erb
  - app/services/table_monitor/game_setup.rb
  - app/services/table_monitor/result_recorder.rb
  - config/locales/de.yml
  - config/locales/en.yml
  - test/models/game_test.rb
  - test/controllers/tournament_monitors_controller_test.rb
  - test/controllers/table_monitors_controller_test.rb
  - test/services/table_monitor/game_setup_test.rb
  - test/system/tiebreak_test.rb
autonomous: false
requirements:
  - QUICK-260505-fbb-01
tags:
  - tiebreak
  - cleanup
  - dead-code
  - extend-before-build

must_haves:
  truths:
    - "Game.derive_tiebreak_required + Game.parse_data_hash no longer exist (zero callers across app/, test/, lib/, config/)."
    - "TableMonitorsController#start_game no longer permits :tiebreak_on_draw and no longer coerces it (controller param surface narrowed)."
    - "TournamentMonitorsController#new/#edit/#create/#update no longer set @tiebreak_on_draw_default; private helpers derive_tiebreak_default + persist_tournament_tiebreak_override are removed."
    - "_form.html.erb no longer renders the tournament_tiebreak_on_draw checkbox/label/hidden_field; rest of the form is visually intact."
    - "_quick_game_buttons.html.erb no longer emits hidden_field_tag :tiebreak_on_draw for BK presets."
    - "scoreboard_free_game_karambol_new.html.erb no longer renders the tiebreak_on_draw content_tag block; surrounding flex layout is preserved."
    - "i18n keys tournament_monitors.form.tiebreak_on_draw + locations.scoreboard_free_game.tiebreak_on_draw are removed from de.yml + en.yml (no remaining call sites once views are gutted)."
    - "GameSetup#perform_start_game's resolver-bake block (lines 366-405) is removed; preset/resolver branch no longer mutates game.data['tiebreak_required'] from @options."
    - "Comment in result_recorder.rb (line 453) that still references 'opts into tiebreak_on_draw' is updated to reference the playing_finals? override + bk2_kombi_tiebreak_auto_detect! as the canonical paths."
    - "Comment in game_setup.rb (line 368, removed wholesale with the bake block) goes away with its block."
    - "TableMonitor#playing_finals_force_tiebreak_required! still exists verbatim with its 2 call sites (table_monitor.rb#tiebreak_pending_block? + result_recorder.rb#tiebreak_pick_pending?)."
    - "ResultRecorder#bk2_kombi_tiebreak_auto_detect! still exists verbatim with its 1 call site (result_recorder.rb#tiebreak_pick_pending?)."
    - "Runtime reads/writes of game.data['tiebreak_required'] + game.data['tiebreak_winner'] are preserved everywhere they currently exist."
    - "Phase 38.7 D-04 resolver tests in test/models/game_test.rb are deleted entirely (resolver no longer exists). Phase 38.7-09 G1/G2/G3 tests in test/services/table_monitor/game_setup_test.rb are deleted (preset-override path no longer exists). Phase 38.7-10 G1/G2 tests in test/controllers/table_monitors_controller_test.rb are deleted (controller no longer permits :tiebreak_on_draw). Phase 38.7-12 Gap-04 G1/G2/G3/G4 tests in test/controllers/tournament_monitors_controller_test.rb are deleted (controller no longer persists)."
    - "test/system/tiebreak_test.rb stays; the doc comment header is updated to remove the 'Game.derive_tiebreak_required' chain reference (the system tests already directly seed game.data['tiebreak_required']=true, so they exercise the override path verbatim)."
    - "test/integration/tiebreak_modal_form_wiring_test.rb stays unchanged (tests view→reflex wiring, not the config plumbing)."
    - "test/concerns/local_protector_test.rb stays unchanged (no MIN_ID protector regression)."
    - "Quick-260505-auq's 5 regression tests (M1, M2, M3, M4 in table_monitor_test.rb, R1 in result_recorder_test.rb) stay GREEN — they only test the override path."
    - "Phase 38.9 + Phase 38.8 + Phase 38.7-02..08 + Phase 38.7-11 (BK-2kombi auto-detect) test suites stay GREEN."
    - "carambus.yml + carambus.yml.erb 'tiebreak_on_draw: true' keys on BK-2/BK-2kombi presets are LEFT AS-IS — they are now dead config but documented as such; no other code reads them. Removing them would conflict with the YAML-edit-in-pairs convention and is out of scope for this cleanup pass."
    - "standardrb is clean on every modified Ruby file."
  artifacts:
    - path: "app/models/game.rb"
      provides: "Game model WITHOUT derive_tiebreak_required + parse_data_hash class methods"
      contains: "frozen_string_literal"
    - path: "app/controllers/table_monitors_controller.rb"
      provides: "start_game whitelist without :tiebreak_on_draw and bool-coercion block"
      contains: "frozen_string_literal"
    - path: "app/controllers/tournament_monitors_controller.rb"
      provides: "controller without @tiebreak_on_draw_default + derive_tiebreak_default + persist_tournament_tiebreak_override"
      contains: "frozen_string_literal"
    - path: "app/views/tournament_monitors/_form.html.erb"
      provides: "form WITHOUT the tournament_tiebreak_on_draw checkbox group"
    - path: "app/views/locations/_quick_game_buttons.html.erb"
      provides: "BK-family quick-game branch WITHOUT the tiebreak_on_draw hidden_field"
    - path: "app/views/locations/scoreboard_free_game_karambol_new.html.erb"
      provides: "scoreboard detail-form WITHOUT the tiebreak_on_draw content_tag block"
    - path: "app/services/table_monitor/game_setup.rb"
      provides: "perform_start_game WITHOUT the resolver-bake + preset-override block (replaced by Quick-260505-auq playing_finals? override path)"
      contains: "BkParamResolver.bake!"
    - path: "app/services/table_monitor/result_recorder.rb"
      provides: "result_recorder.rb with line-453 comment refreshed to reference playing_finals? override + bk2_kombi_tiebreak_auto_detect! as the canonical paths"
      contains: "playing_finals_force_tiebreak_required!"
    - path: "config/locales/de.yml"
      provides: "DE translations WITHOUT tournament_monitors.form.tiebreak_on_draw + locations.scoreboard_free_game.tiebreak_on_draw"
    - path: "config/locales/en.yml"
      provides: "EN translations WITHOUT tournament_monitors.form.tiebreak_on_draw + locations.scoreboard_free_game.tiebreak_on_draw"
  key_links:
    - from: "app/models/table_monitor.rb#playing_finals_force_tiebreak_required! (Quick-260505-auq, ~line 1758)"
      to: "game.data['tiebreak_required']=true (write via deep_merge_data! + save!)"
      via: "first line of TableMonitor#tiebreak_pending_block?"
      pattern: "playing_finals_force_tiebreak_required!"
    - from: "app/services/table_monitor/result_recorder.rb#tiebreak_pick_pending? (~line 348)"
      to: "@tm.send(:playing_finals_force_tiebreak_required!) + @tm.bk2_kombi_tiebreak_auto_detect!"
      via: "two pre-mutation helpers; both pre-bake game.data['tiebreak_required']=true under their respective conditions before the gate check"
      pattern: "playing_finals_force_tiebreak_required!"
    - from: "config/carambus.yml (BK-2 + BK-2kombi quick_game_presets, key 'tiebreak_on_draw: true')"
      to: "(no consumer — dead config)"
      via: "previously read by _quick_game_buttons.html.erb hidden_field; that hidden_field is removed in this plan"
      pattern: "tiebreak_on_draw: true"
---

<objective>
Remove the dead `tiebreak_on_draw` configuration plumbing now that
`TableMonitor#playing_finals_force_tiebreak_required!` (Quick-260505-auq, HEAD
94c488df) is the canonical tiebreak-trigger path. The user has scrubbed the
matching data from carambus_api production.

Per the user task brief: the architectural-mismatch finding (Phase 38.7-04
resolver only ever read `g{N}` keys, while real tournament plans also carry the
key under `hf*`/`fin`/`p<*>`) confirms the data path was already broken before
the override. Combined with the override, the entire chain
(carambus.yml/preset → controller params → GameSetup bake →
Game.derive_tiebreak_required resolver → game.data) is dead code today.

This plan deletes:
- The Phase 38.7-04 resolver: `Game.derive_tiebreak_required` +
  `Game.parse_data_hash`.
- The Phase 38.7-09/10 controller plumbing in
  `TableMonitorsController#start_game` (whitelist + bool-coercion).
- The Phase 38.7-12 Gap-04 controller plumbing in
  `TournamentMonitorsController` (`@tiebreak_on_draw_default`,
  `derive_tiebreak_default`, `persist_tournament_tiebreak_override`).
- The corresponding form checkbox in `_form.html.erb`.
- The hidden_field in `_quick_game_buttons.html.erb` (BK preset chain).
- The content_tag in `scoreboard_free_game_karambol_new.html.erb` (free-game
  detail form).
- The two i18n strings (`tournament_monitors.form.tiebreak_on_draw`,
  `locations.scoreboard_free_game.tiebreak_on_draw`) from de.yml + en.yml.
- The `GameSetup#perform_start_game` bake block (lines 366-405) that fed the
  resolver/preset chain into `game.data`.
- All tests that exercise the removed config paths (Phase 38.7-04, 38.7-09 G1,
  38.7-10 G1, 38.7-12 G1/G2/G3/G4 — see scope below for full list).
- Updates the now-misleading comment in `result_recorder.rb:453`.

Hard constraints (preserved verbatim — explicit `do not touch` list):
- `TableMonitor#playing_finals_force_tiebreak_required!` and its 2 call sites.
- `TableMonitor#tiebreak_pending_block?` (override-prepended first line stays).
- `ResultRecorder#tiebreak_pick_pending?` and its two pre-mutation helpers
  (`bk2_kombi_tiebreak_auto_detect!`, `playing_finals_force_tiebreak_required!`).
- `ResultRecorder#bk2_kombi_tiebreak_auto_detect!` body.
- All runtime reads/writes of `game.data['tiebreak_required']` + 
  `game.data['tiebreak_winner']`.
- `Discipline` rows / data — forbidden per project memory
  `feedback_no_discipline_tiebreak.md`.
- `carambus.yml` + `carambus.yml.erb` `tiebreak_on_draw: true` lines on BK-2 +
  BK-2kombi presets — left AS-IS as documented dead config (no other code reads
  them; removing forces a YAML edit pair that's out of scope here).
- `BkParamResolver.bake!` call at `game_setup.rb:364` — this is for BK family
  scoring params (effective_discipline, allow_negative_score_input,
  negative_credits_opponent), NOT tiebreak. Stays verbatim.

Purpose: collapse the config plumbing that's no longer load-bearing, so future
maintainers don't try to "fix" the broken resolver/plumbing instead of trusting
the override.

Output: a 4-task plan: T1 deletes/rewrites the failing/dead tests; T2 deletes
the production code (controllers, views, services, model, i18n, comment update)
in one atomic commit; T3 runs the full regression sweep + standardrb; T4 is a
checkpoint:human-verify gate before final commit/sync.
</objective>

<execution_context>
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/workflows/execute-plan.md
@/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@./CLAUDE.md
@.agents/skills/scenario-management/SKILL.md
@.agents/skills/extend-before-build/SKILL.md
@.planning/quick/260505-auq-tiebreak-tournamentmonitor-state-playing/260505-auq-PLAN.md
@.planning/quick/260505-auq-tiebreak-tournamentmonitor-state-playing/260505-auq-SUMMARY.md
@app/models/game.rb
@app/models/table_monitor.rb
@app/controllers/table_monitors_controller.rb
@app/controllers/tournament_monitors_controller.rb
@app/views/tournament_monitors/_form.html.erb
@app/views/locations/_quick_game_buttons.html.erb
@app/views/locations/scoreboard_free_game_karambol_new.html.erb
@app/services/table_monitor/game_setup.rb
@app/services/table_monitor/result_recorder.rb
@config/locales/de.yml
@config/locales/en.yml
@test/models/game_test.rb
@test/services/table_monitor/game_setup_test.rb
@test/controllers/tournament_monitors_controller_test.rb
@test/controllers/table_monitors_controller_test.rb
@test/system/tiebreak_test.rb
@test/integration/tiebreak_modal_form_wiring_test.rb

<interfaces>
<!--
Investigation findings — exact file:line anchors verified 2026-05-05 via grep at
plan time. Executors should re-grep before deletion to catch any drift.

Re-verify with:
  grep -rn "derive_tiebreak_required\|parse_data_hash\|derive_tiebreak_default\|persist_tournament_tiebreak\|tournament_tiebreak_on_draw\|@tiebreak_on_draw_default" app/ test/ lib/ config/

Expected hits (snapshot 2026-05-05):
  app/models/game.rb:81,83,88,105,110          (defs to delete + parse_data_hash internal use)
  app/controllers/tournament_monitors_controller.rb:155,160,178,192,221,253...284
  app/controllers/table_monitors_controller.rb:107,125-133
  app/views/tournament_monitors/_form.html.erb:39-53
  app/views/locations/_quick_game_buttons.html.erb:157-162
  app/views/locations/scoreboard_free_game_karambol_new.html.erb:642-660
  app/services/table_monitor/game_setup.rb:366-405                (bake block)
  app/services/table_monitor/result_recorder.rb:453               (stale comment)
  config/locales/de.yml:361, 758
  config/locales/en.yml:344, 718
  test/models/game_test.rb:7-92                                   (whole resolver test block)
  test/services/table_monitor/game_setup_test.rb:367-532          (Plan-04/09 tests)
  test/controllers/tournament_monitors_controller_test.rb:115-196 (Plan-12 G1-G4)
  test/controllers/table_monitors_controller_test.rb:741-789      (Plan-10 G1-G2)
  test/system/tiebreak_test.rb:8-9                                (doc comment lines)
  test/integration/tiebreak_modal_form_wiring_test.rb             (NO change — tests view→reflex wiring)
  test/concerns/local_protector_test.rb                           (NO change)
  test/models/table_monitor_test.rb                               (NO change — Quick-260505-auq tests stay)
  test/services/table_monitor/result_recorder_test.rb             (NO change — Quick-260505-auq R1 + Plan-11 G3 tests stay)

# parse_data_hash callers (verified):
  app/models/game.rb:83 — only caller (inside derive_tiebreak_required)
  app/models/game.rb:88 — only caller (inside derive_tiebreak_required)
  test/models/game_test.rb:89 — only test reference (in deleted block)
→ parse_data_hash is dead-with-derive_tiebreak_required. Remove BOTH.
→ NB: distinct from Game.safe_decode_data (line 43) which is used by Game#data
   getter (line 117) — KEEP that.

# carambus.yml.erb / carambus.yml dead-config note (LEAVE AS-IS):
  config/carambus.yml.erb:50-69, config/carambus.yml:50-69 still carry
  `tiebreak_on_draw: true` on BK-2 + BK-2kombi presets. The hidden_field is
  the only consumer; once removed, those YAML keys are dead config. We do
  NOT remove them in this plan to avoid a YAML-edit-pair (per Phase 38.4
  decision: carambus.yml.erb + carambus.yml MUST stay synchronized — see
  STATE.md decision "[Phase 38.4]: carambus.yml (compiled/ignored) must be
  kept in sync with carambus.yml.erb manually"). A future quick task can do
  the YAML cleanup; flagging it in the SUMMARY's "Known dead config" note.

# Quick-260505-auq override (DO NOT MODIFY):
  app/models/table_monitor.rb:1716   tiebreak_pending_block?
  app/models/table_monitor.rb:1717   playing_finals_force_tiebreak_required! (call)
  app/models/table_monitor.rb:1758   def playing_finals_force_tiebreak_required!
  app/models/table_monitor.rb:1770   private :playing_finals_force_tiebreak_required!
  app/services/table_monitor/result_recorder.rb:348   tiebreak_pick_pending?
  app/services/table_monitor/result_recorder.rb:349   bk2_kombi_tiebreak_auto_detect!
  app/services/table_monitor/result_recorder.rb:352   @tm.send(:playing_finals_force_tiebreak_required!)

# game_setup.rb bake block boundary (lines 366-405 — to be deleted):
  Line 366 begins a comment "# Phase 38.7 Plan 04 — D-04, D-05 bake game.data['tiebreak_required']."
  Line 405 is the closing `end` of the `if @tm.game.present?` block.
  This block is between BkParamResolver.bake!(@tm) (line 364, KEEP) and the
  `if @tm.data["free_game_form"] == "bk2_kombi"` block (line 414, KEEP).
  Confirm by grep: lines 366-405 match the deleted block exactly.

# game_setup_test.rb tests to delete (lines 367-532):
  Lines 367-376: doc comment header for Plan-04 tests
  Lines 378-403: build_mock_tm_with_plan helper (only used by deleted tests)
  Lines 405-414: "start_game writes game.data['tiebreak_required']=false for training BK-2 match"
  Lines 416-423: "start_game writes game.data['tiebreak_required']=false for training Karambol match"
  Lines 425-436: "start_game tiebreak_required bake is idempotent"
  Lines 438-452: "derive_tiebreak_required returns true when only TournamentPlan group says so"
  Lines 454-465: doc comment for Plan-09 Gap-01 tests
  Lines 467-487: G1 (Gap-01)
  Lines 489-510: G2 (Gap-01)
  Lines 512-532: G3 (Gap-01)
  ALL of these target the deleted bake block. Delete the entire range 367-532.
  The next test "assign assigns game_id..." (line 539) starts a fresh block.

# tiebreak_test.rb (system) doc comment update (lines 8-9):
  CURRENT:
    #   Discipline.data['tiebreak_on_draw']  (Plan 01 seed/fixture)
    #   → Game.derive_tiebreak_required + bake at start_game (Plan 04)
  REPLACE WITH:
    #   game.data['tiebreak_required']  (seeded directly in test setup, or via
    #                                    bk2_kombi_tiebreak_auto_detect! at
    #                                    runtime, or via the playing_finals?
    #                                    override Quick-260505-auq)
  The actual test bodies seed game.data['tiebreak_required'] directly via
  Game.create!(data: {"tiebreak_required" => true}, ...) — no resolver call —
  so they remain valid after the deletion.

# i18n key boundaries (verified — no other call sites):
  config/locales/de.yml:361: under en/de "locations.scoreboard_free_game.tiebreak_on_draw"
  config/locales/de.yml:758: under "tournament_monitors.form.tiebreak_on_draw"
  config/locales/en.yml:344: under "locations.scoreboard_free_game.tiebreak_on_draw"
  config/locales/en.yml:718: under "tournament_monitors.form.tiebreak_on_draw"
  Both keys must be removed. After removal, run i18n consistency check (rails
  will warn at boot if any t() call references a missing key).
-->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Delete dead-code tests + update tiebreak_test.rb doc header</name>
  <files>
    test/models/game_test.rb,
    test/services/table_monitor/game_setup_test.rb,
    test/controllers/tournament_monitors_controller_test.rb,
    test/controllers/table_monitors_controller_test.rb,
    test/system/tiebreak_test.rb
  </files>
  <action>
    Tests removed FIRST so Task 2's production-code deletion does not produce
    cascading red tests in the same commit. After this task, the deleted tests
    no longer reference symbols that Task 2 will delete; the test suite stays
    GREEN throughout.

    Re-grep at the START of this task to catch any drift since plan time:

    ```
    grep -rn "derive_tiebreak_required\|parse_data_hash\|derive_tiebreak_default\|persist_tournament_tiebreak\|tournament_tiebreak_on_draw" test/
    ```

    Expected hits match the interfaces block above. If new test files have
    appeared (e.g., from a sibling quick task), STOP and surface to user.

    ## Edit 1.1 — test/models/game_test.rb

    Delete the entire `Game.derive_tiebreak_required` test block (lines 7-92 in
    the 2026-05-05 snapshot). After deletion the file should still contain any
    other Game tests that may exist (verify before deleting that nothing else
    in this file depends on derive_tiebreak_required).

    Concretely: replace the file's content with whatever it has BEFORE line 7
    (`# Phase 38.7 Plan 04 — Game.derive_tiebreak_required tests (D-04, D-05).`)
    and AFTER the closing `end` of the last derive_tiebreak_required test.
    If the file becomes effectively empty (only `class GameTest <
    ActiveSupport::TestCase` + `end`), keep the empty class definition + a
    single comment marker `# Tests for Game model. Phase 38.7-04 resolver
    tests removed Quick-260505-fbb (resolver deleted; playing_finals?
    override is canonical now).`

    ## Edit 1.2 — test/services/table_monitor/game_setup_test.rb

    Delete lines 367-532 (the entire Phase-38.7-04 + Phase-38.7-09 Gap-01 test
    block including the `build_mock_tm_with_plan` helper, which is only used
    by these deleted tests). The next test (`"assign assigns game_id..."` at
    line 539 in the snapshot) must remain. Verify visually that the resulting
    file has no orphaned `private` markers, no orphaned helper methods, and the
    remaining tests still parse.

    Re-grep after edit:

    ```
    grep -n "derive_tiebreak\|build_mock_tm_with_plan\|tiebreak_on_draw\|tiebreak_required" test/services/table_monitor/game_setup_test.rb
    ```

    Should return ZERO hits.

    ## Edit 1.3 — test/controllers/tournament_monitors_controller_test.rb

    Delete the Phase-38.7-12 Gap-04 test block: lines 115-196 in the snapshot
    (the doc comment block starting at "# Phase 38.7 Plan 12 — Gap-04..." and
    the four tests G1, G2, G3, G4, ending at the file's terminating `end`
    statement at line 197 BEFORE the class's closing `end`).

    Concretely: locate the line `class TournamentMonitorsControllerTest < ...`
    early in the file. The four Gap-04 tests + their doc comment must be
    removed from inside that class body, leaving the class structure intact
    and the file ending with a balanced `end`.

    Re-grep after edit:

    ```
    grep -n "tournament_tiebreak_on_draw\|derive_tiebreak_required\|tiebreak_on_draw" test/controllers/tournament_monitors_controller_test.rb
    ```

    Should return ZERO hits.

    ## Edit 1.4 — test/controllers/table_monitors_controller_test.rb

    Delete the Phase-38.7-10 Gap-02 test block: lines 741-789 in the snapshot
    (the doc comment block starting at "# Phase 38.7 Plan 10 — Gap-02..." and
    the two tests G1, G2). The class's closing `end` (line 790) must remain
    balanced with the class declaration.

    Re-grep after edit:

    ```
    grep -n "tiebreak_on_draw\|tiebreak_required" test/controllers/table_monitors_controller_test.rb
    ```

    Should return ZERO hits.

    ## Edit 1.5 — test/system/tiebreak_test.rb

    DO NOT delete this file or any test bodies. They are the canonical
    end-to-end tests for the tiebreak modal flow and they directly seed
    `game.data['tiebreak_required']=true` via `Game.create!(data: {...})` —
    they exercise the override path's downstream consumers without ever
    touching the deleted resolver.

    Update the doc-comment header (lines 5-15 of the snapshot). Replace lines
    8-9:

    ```
    #   Discipline.data['tiebreak_on_draw']  (Plan 01 seed/fixture)
    #   → Game.derive_tiebreak_required + bake at start_game (Plan 04)
    ```

    with:

    ```
    #   game.data['tiebreak_required']  (seeded directly in test setup, or via
    #                                    bk2_kombi_tiebreak_auto_detect! at
    #                                    runtime, or via the playing_finals?
    #                                    override — Quick-260505-auq + Quick-260505-fbb
    #                                    cleanup of dead config plumbing)
    ```

    Leave the rest of the comment block (the test matrix description) intact.

    ## Verify Task 1 — full test sweep stays GREEN

    Run the affected test files. They MUST be GREEN after deletions (the
    deletions are pure removals — no production code has changed yet, so the
    remaining tests still pass against the still-present resolver/plumbing):

    ```
    bin/rails test test/models/game_test.rb \
      test/services/table_monitor/game_setup_test.rb \
      test/controllers/tournament_monitors_controller_test.rb \
      test/controllers/table_monitors_controller_test.rb \
      test/system/tiebreak_test.rb \
      test/integration/tiebreak_modal_form_wiring_test.rb \
      test/concerns/local_protector_test.rb \
      test/models/table_monitor_test.rb \
      test/services/table_monitor/result_recorder_test.rb
    ```

    All test files MUST pass with 0 failures, 0 errors. The total test count
    will be LOWER than before (we removed ~16 tests). Document the new
    expected counts in commit message.

    ## Commit

    Conventional commit message:

    ```
    test(quick-260505-fbb): remove dead-code tests for tiebreak_on_draw config plumbing

    Removes Phase 38.7-04 resolver tests (test/models/game_test.rb),
    Phase 38.7-04+09 GameSetup bake tests (test/services/table_monitor/
    game_setup_test.rb lines 367-532), Phase 38.7-12 Gap-04 controller
    tests (test/controllers/tournament_monitors_controller_test.rb), and
    Phase 38.7-10 Gap-02 controller tests (test/controllers/
    table_monitors_controller_test.rb). Updates the test/system/
    tiebreak_test.rb doc header to reference Quick-260505-auq's
    playing_finals? override + bk2_kombi_tiebreak_auto_detect! as the
    canonical tiebreak-trigger paths.

    Production code deletion follows in the next commit.
    ```
  </action>
  <verify>
    <automated>bin/rails test test/models/game_test.rb test/services/table_monitor/game_setup_test.rb test/controllers/tournament_monitors_controller_test.rb test/controllers/table_monitors_controller_test.rb test/integration/tiebreak_modal_form_wiring_test.rb test/concerns/local_protector_test.rb test/models/table_monitor_test.rb test/services/table_monitor/result_recorder_test.rb 2>&amp;1 | tail -30</automated>
  </verify>
  <done>
    All listed test files pass with 0 failures, 0 errors. Targeted greps for
    the deleted symbols return zero matches in the test/ tree. tiebreak_test.rb
    doc header updated. Test deletion committed (separate commit from
    production code).
  </done>
</task>

<task type="auto">
  <name>Task 2: Delete dead production code (model + controllers + views + service block + i18n + comment update)</name>
  <files>
    app/models/game.rb,
    app/controllers/table_monitors_controller.rb,
    app/controllers/tournament_monitors_controller.rb,
    app/views/tournament_monitors/_form.html.erb,
    app/views/locations/_quick_game_buttons.html.erb,
    app/views/locations/scoreboard_free_game_karambol_new.html.erb,
    app/services/table_monitor/game_setup.rb,
    app/services/table_monitor/result_recorder.rb,
    config/locales/de.yml,
    config/locales/en.yml
  </files>
  <action>
    Single atomic commit. Order: model → service → controllers → views → i18n →
    comment update. Pre-flight grep confirms scope.

    Re-grep before starting:

    ```
    grep -rn "derive_tiebreak_required\|parse_data_hash\|derive_tiebreak_default\|persist_tournament_tiebreak\|tournament_tiebreak_on_draw\|@tiebreak_on_draw_default" app/ config/locales/
    ```

    Expected hits match the interfaces block. If the count is HIGHER than
    expected, a new caller has appeared since plan time — STOP and surface.

    ## Edit 2.1 — app/models/game.rb

    Delete the `derive_tiebreak_required` class method (lines 60-98 in
    snapshot — the doc comment block at lines 60-79 PLUS the def body at
    lines 80-98). Then delete the `parse_data_hash` class method (lines
    100-112 — the doc comment at lines 100-104 PLUS the def body at lines
    105-112).

    Verify with a final grep that NEITHER `derive_tiebreak_required` NOR
    `parse_data_hash` appears anywhere in app/, test/, lib/, config/:

    ```
    grep -rn "derive_tiebreak_required\|parse_data_hash" app/ test/ lib/ config/
    ```

    Should return ZERO hits. NB: leave `Game.safe_decode_data` (line 43)
    UNTOUCHED — it's the data getter helper used by the `def data` instance
    method (line 117) and is unrelated to the resolver.

    ## Edit 2.2 — app/services/table_monitor/game_setup.rb

    Delete the resolver-bake block at lines 366-405 (snapshot). The block
    starts with the comment `# Phase 38.7 Plan 04 — D-04, D-05 bake
    game.data['tiebreak_required'].` and ends with the closing `end` of the
    `if @tm.game.present?` block.

    Concretely: the block sits BETWEEN `BkParamResolver.bake!(@tm)` (line 364
    — KEEP) and the comment `# Phase 38.5: für BK-2kombi muss bk2_state hier
    initialisiert werden...` (line 407 — KEEP).

    After deletion, `BkParamResolver.bake!(@tm)` should be IMMEDIATELY followed
    by the existing blank line and the BK-2kombi initialize_bk2_state! block.
    No replacement; the playing_finals? override + bk2_kombi_tiebreak_auto_detect!
    handle the runtime tiebreak triggering.

    Re-grep after edit:

    ```
    grep -n "tiebreak_required\|tiebreak_on_draw\|derive_tiebreak" app/services/table_monitor/game_setup.rb
    ```

    Should return ZERO hits.

    ## Edit 2.3 — app/services/table_monitor/result_recorder.rb (comment only)

    On line 453 (snapshot — inside the `is_simple_set && was_playing &&
    @tm.may_end_of_set?` branch), the current comment reads:

    ```ruby
    # Phase 38.7 Plan 05 — D-03 trigger detection (simple-set branch).
    # Same marker-switch as inning-based branch above; covers BK-2/BK-2kombi-SP
    # and any future simple-set discipline that opts into tiebreak_on_draw.
    ```

    Replace the third line ("...opts into tiebreak_on_draw.") with:

    ```ruby
    # Same marker-switch as inning-based branch above; covers BK-2/BK-2kombi-SP
    # tiebreak — triggered by bk2_kombi_tiebreak_auto_detect! (BK-2kombi runtime
    # auto-detect) or playing_finals_force_tiebreak_required! (Quick-260505-auq
    # tournament-finals override) inside tiebreak_pick_pending?.
    ```

    Do NOT modify any code. Do NOT modify any other comment in this file.

    ## Edit 2.4 — app/controllers/table_monitors_controller.rb

    On line 107 (snapshot), the `params.permit(...)` ends with
    `:tiebreak_on_draw)`. Remove `:tiebreak_on_draw` and its preceding doc
    comment block (lines 103-106 snapshot — the comment starting "# Phase 38.7
    Plan 09 (Gap-01): per-preset tiebreak source." through the `:tiebreak_on_draw)`
    line). The closing paren must move up to whatever was the last whitelisted
    key on the previous line — specifically, the previous key on line 102 is
    `:bk2_first_set_mode,` — change that trailing comma to a closing paren so
    the permit list ends cleanly with `:bk2_first_set_mode)`.

    Then delete the bool-coercion block at lines 125-133 (snapshot). The
    block starts with `# Phase 38.7 Plan 09 (Gap-01): Bool coercion for the
    hidden :tiebreak_on_draw` and ends with the line:
    `p[:tiebreak_on_draw] = (...)`.

    The lines BEFORE (line 124 — `p[:allow_follow_up] = (...)`) and AFTER
    (line 134 — `# 38.4-04 D-04/D-06: BK-family quick-start...`) MUST be
    preserved.

    Re-grep after edit:

    ```
    grep -n "tiebreak_on_draw" app/controllers/table_monitors_controller.rb
    ```

    Should return ZERO hits.

    ## Edit 2.5 — app/controllers/tournament_monitors_controller.rb

    1. In `def new` (line 153 snapshot), delete line 155:
       `@tiebreak_on_draw_default = derive_tiebreak_default(@tournament_monitor)`.

    2. In `def edit` (line 158 snapshot), delete line 160:
       `@tiebreak_on_draw_default = derive_tiebreak_default(@tournament_monitor)`.

    3. In `def create` (line 163 snapshot), delete the comment block lines
       168-175 (the Phase 38.7 Plan 12 (Gap-04) auth-gate explanation) — the
       comment is ABOUT not persisting, but with the helper gone the comment
       is also obsolete. Then delete line 178 inside the `else` arm
       (`@tiebreak_on_draw_default = derive_tiebreak_default(@tournament_monitor)`).

    4. In `def update` (line 183 snapshot), delete the call site
       `persist_tournament_tiebreak_override(@tournament_monitor)` (line 189)
       and its preceding comment block (lines 186-188). Delete line 192 inside
       the `else` arm
       (`@tiebreak_on_draw_default = derive_tiebreak_default(@tournament_monitor)`).

    5. Delete the entire `derive_tiebreak_default` private method (lines
       216-236 in snapshot — the doc comment block at lines 216-220 PLUS the
       def body at lines 221-236).

    6. Delete the entire `persist_tournament_tiebreak_override` private method
       (lines 238-284 in snapshot — the doc comment block at lines 238-252
       PLUS the def body at lines 253-284).

    Verify the resulting controller has balanced `def`/`end` pairs. Re-grep
    after edit:

    ```
    grep -n "tiebreak\|derive_tiebreak" app/controllers/tournament_monitors_controller.rb
    ```

    Should return ZERO hits.

    ## Edit 2.6 — app/views/tournament_monitors/_form.html.erb

    Delete lines 39-53 (snapshot — the entire form-group div for
    tournament_tiebreak_on_draw, including the comment block at lines 39-48
    and the actual `<div class="form-group">` at lines 49-53). Ensure the
    flex-justify-between div for the submit button (line 55) follows directly
    after the balls_goal form-group (line 37).

    Re-grep after edit:

    ```
    grep -n "tiebreak" app/views/tournament_monitors/_form.html.erb
    ```

    Should return ZERO hits.

    ## Edit 2.7 — app/views/locations/_quick_game_buttons.html.erb

    Delete lines 157-162 (snapshot — the comment block at lines 157-161
    explaining "Phase 38.7 Plan 09 (Gap-01)..." plus the `hidden_field_tag
    :tiebreak_on_draw` line at 162). The lines BEFORE (line 156 —
    `<%= hidden_field_tag :kickoff_switches_with, 'set' %>`) and AFTER
    (line 163 — `<% else %>`) MUST be preserved.

    Re-grep after edit:

    ```
    grep -n "tiebreak" app/views/locations/_quick_game_buttons.html.erb
    ```

    Should return ZERO hits.

    ## Edit 2.8 — app/views/locations/scoreboard_free_game_karambol_new.html.erb

    Delete lines 642-660 (snapshot — the comment block at lines 642-646
    plus the `<div class="flex flex-row text-white">...</div>` block at
    lines 647-660 containing the `content_tag :div, id: "tiebreak_on_draw"...`
    + label).

    The line BEFORE (line 641 — closing `</div>` of allow_overflow block)
    and AFTER (line 661 — opening `<div class="flex flex-col text-white">`
    of fixed_display_left block) MUST be preserved.

    Re-grep after edit:

    ```
    grep -n "tiebreak" app/views/locations/scoreboard_free_game_karambol_new.html.erb
    ```

    Should return ZERO hits.

    ## Edit 2.9 — config/locales/de.yml

    Delete two lines:
    - Line 361 (snapshot): `      tiebreak_on_draw: "Stechen bei Unentschieden"`
      (under `locations.scoreboard_free_game`).
    - Line 758 (snapshot): `      tiebreak_on_draw: "Stechen bei Unentschieden"`
      (under `tournament_monitors.form`).

    NB: line numbers shift after the first deletion. Use the parent key context
    (`scoreboard_free_game:` parent vs `form:` parent) to disambiguate.

    Verify the surrounding YAML structure is balanced. The
    `scoreboard_free_game:` parent (line 360) becomes an empty mapping after
    deletion — leave it as `scoreboard_free_game: {}` if YAML strictness
    requires, or remove the parent key as well if no other children exist.
    Re-check after first deletion.

    Re-grep after edit:

    ```
    grep -n "tiebreak" config/locales/de.yml
    ```

    Should return ZERO hits (the only tiebreak key in this file is the one
    we deleted).

    ## Edit 2.10 — config/locales/en.yml

    Mirror Edit 2.9 in the EN locale:
    - Line 344 (snapshot): `      tiebreak_on_draw: "Tiebreak on draw"`
      (under `locations.scoreboard_free_game`).
    - Line 718 (snapshot): `      tiebreak_on_draw: "Tiebreak on draw"`
      (under `tournament_monitors.form`).

    Same parent-key cleanup rule as Edit 2.9.

    Re-grep after edit:

    ```
    grep -n "tiebreak" config/locales/en.yml
    ```

    Should return ZERO hits.

    ## Final verification + commit (inside Task 2)

    1. Standardrb on all modified Ruby files:

       ```
       bundle exec standardrb \
         app/models/game.rb \
         app/controllers/table_monitors_controller.rb \
         app/controllers/tournament_monitors_controller.rb \
         app/services/table_monitor/game_setup.rb \
         app/services/table_monitor/result_recorder.rb
       ```

       Any new violations = fix before commit. Pre-existing violations on
       lines unrelated to our edits = leave alone (consistent with
       Quick-260505-auq's standardrb policy in its SUMMARY).

    2. erblint on all modified ERB files:

       ```
       bundle exec erblint \
         app/views/tournament_monitors/_form.html.erb \
         app/views/locations/_quick_game_buttons.html.erb \
         app/views/locations/scoreboard_free_game_karambol_new.html.erb
       ```

    3. App boot smoke test:

       ```
       bin/rails runner 'puts "i18n DE form-tiebreak: #{I18n.t("tournament_monitors.form.tiebreak_on_draw", default: "REMOVED")}"; puts "i18n EN scoreboard-tiebreak: #{I18n.t("locations.scoreboard_free_game.tiebreak_on_draw", default: "REMOVED", locale: :en)}"'
       ```

       Both lines must print `REMOVED`. Confirms i18n keys are gone AND no
       residual `t()` call in code references them (Rails would warn at
       boot or print missing-key on translate).

    4. Commit:

       ```
       fix(quick-260505-fbb): remove dead tiebreak_on_draw config plumbing

       Quick-260505-auq's TableMonitor#playing_finals_force_tiebreak_required!
       is the canonical tiebreak-trigger path for tournament finals (HEAD
       94c488df). The user has scrubbed matching data from carambus_api
       production. Phase 38.7-04 resolver only ever read 'g{N}' executor_param
       buckets while real tournament plans carry the key under hf*/fin/p<*>
       — confirming the plumbing was already broken before the override.

       Removed:
       - Game.derive_tiebreak_required + Game.parse_data_hash class methods
       - GameSetup#perform_start_game resolver-bake block (lines 366-405)
       - TableMonitorsController :tiebreak_on_draw permit + bool-coercion
       - TournamentMonitorsController @tiebreak_on_draw_default,
         derive_tiebreak_default, persist_tournament_tiebreak_override
       - Form checkbox in tournament_monitors/_form.html.erb
       - Hidden field in locations/_quick_game_buttons.html.erb
       - Content_tag block in locations/scoreboard_free_game_karambol_new.html.erb
       - i18n keys tournament_monitors.form.tiebreak_on_draw +
         locations.scoreboard_free_game.tiebreak_on_draw (de.yml + en.yml)
       - All tests exercising these paths (preceding commit)
       - Updated stale comment in result_recorder.rb:453

       Preserved verbatim:
       - TableMonitor#playing_finals_force_tiebreak_required! + 2 call sites
       - ResultRecorder#bk2_kombi_tiebreak_auto_detect!
       - All runtime reads/writes of game.data['tiebreak_required'] +
         game.data['tiebreak_winner']
       - BkParamResolver.bake! (BK family scoring params, not tiebreak)
       - test/system/tiebreak_test.rb (directly seeds game.data —
         exercises the override path's downstream consumers)
       - test/integration/tiebreak_modal_form_wiring_test.rb (view→reflex)

       Known dead config (deferred — out of scope for this cleanup):
       - carambus.yml + carambus.yml.erb 'tiebreak_on_draw: true' on BK-2 +
         BK-2kombi presets (no consumer left). YAML-edit-pair convention
         (Phase 38.4 decision) makes this a separate quick task.
       ```
  </action>
  <verify>
    <automated>bundle exec standardrb app/models/game.rb app/controllers/table_monitors_controller.rb app/controllers/tournament_monitors_controller.rb app/services/table_monitor/game_setup.rb app/services/table_monitor/result_recorder.rb &amp;&amp; bundle exec erblint app/views/tournament_monitors/_form.html.erb app/views/locations/_quick_game_buttons.html.erb app/views/locations/scoreboard_free_game_karambol_new.html.erb &amp;&amp; bin/rails runner 'puts I18n.t("tournament_monitors.form.tiebreak_on_draw", default: "REMOVED"); puts I18n.t("locations.scoreboard_free_game.tiebreak_on_draw", default: "REMOVED", locale: :en)' 2>&amp;1 | tail -20</automated>
  </verify>
  <done>
    All targeted greps for derive_tiebreak_required / parse_data_hash /
    derive_tiebreak_default / persist_tournament_tiebreak /
    tournament_tiebreak_on_draw / @tiebreak_on_draw_default / 'tiebreak_on_draw'
    return ZERO hits in app/ and config/locales/. Standardrb clean on edited
    Ruby files, erblint clean on edited ERBs, i18n smoke test prints REMOVED
    for both keys. Single atomic commit landed on go_back_to_stable branch.
  </done>
</task>

<task type="auto">
  <name>Task 3: Full regression sweep</name>
  <files></files>
  <action>
    Run the full tiebreak-adjacent test suite to confirm zero regressions.
    The test deletions in Task 1 already removed the failing tests, so this
    sweep validates that nothing ELSE depended on the removed code.

    ## Step 3.1 — Tiebreak override + Phase 38.7 + Phase 38.8 + Phase 38.9
    + protector regression

    ```
    bin/rails test \
      test/models/game_test.rb \
      test/models/table_monitor_test.rb \
      test/services/table_monitor/result_recorder_test.rb \
      test/services/table_monitor/game_setup_test.rb \
      test/controllers/table_monitors_controller_test.rb \
      test/controllers/tournament_monitors_controller_test.rb \
      test/integration/tiebreak_modal_form_wiring_test.rb \
      test/concerns/local_protector_test.rb
    ```

    All MUST pass with 0 failures, 0 errors. Skips OK (the project has 2
    pre-existing baseline skips per Quick-260505-auq SUMMARY).

    ## Step 3.2 — System tiebreak tests

    ```
    bin/rails test test/system/tiebreak_test.rb
    ```

    Should pass with 0 failures (Quick-260505-auq baseline: 4/4 GREEN).

    ## Step 3.3 — Wider protector / bk2 / final-match-score sweep

    ```
    bin/rails test \
      test/system/final_match_score_operator_gate_test.rb \
      test/reflexes/game_protocol_reflex_test.rb 2>/dev/null || true
    ```

    Last `|| true` covers the case where the file path differs slightly. If
    the reflex test file doesn't exist at that path, locate via:

    ```
    find test -name "*reflex*tiebreak*" -o -name "*tiebreak*reflex*" 2>/dev/null
    find test -name "game_protocol_reflex_test.rb" 2>/dev/null
    ```

    Run whatever the find produces. All discovered tests MUST pass.

    ## Step 3.4 — Critical concerns + scraping

    ```
    bin/rails test:critical
    ```

    The `test:critical` rake task runs concerns + scraping tests. Should pass
    cleanly (no tiebreak code touched in concerns).

    ## Step 3.5 — Boot smoke

    ```
    bin/rails runner 'p TableMonitor.first&.id; p Game.method_defined?(:data); puts "OK"'
    ```

    Should print without raising (confirms model class loads, no NameError
    from removed methods).

    ## Step 3.6 — Search for any straggler refs

    Final grep across the entire repo (excluding planning docs):

    ```
    grep -rn "derive_tiebreak_required\|parse_data_hash\|derive_tiebreak_default\|persist_tournament_tiebreak\|tournament_tiebreak_on_draw\|@tiebreak_on_draw_default" app/ test/ lib/ config/ db/ 2>/dev/null | grep -v ".planning/"
    ```

    MUST return zero hits. Any survivor = a missed file in Task 2 — fix and
    add to the same commit (`git commit --amend` is acceptable here since the
    previous commit hasn't been pushed yet; if already pushed, NEW commit).

    ## Step 3.7 — Document results

    No commit in this task. Record the test counts (passed / skipped) for the
    SUMMARY.md that will be written after Task 4 approval. Sample format:

    ```
    test/models/game_test.rb: N runs, N assertions, 0 failures, 0 errors
    test/services/table_monitor/result_recorder_test.rb: N runs, ...
    ...
    ```

    Surface any unexpected failures to the user IMMEDIATELY before
    proceeding to Task 4.
  </action>
  <verify>
    <automated>bin/rails test test/models/game_test.rb test/models/table_monitor_test.rb test/services/table_monitor/result_recorder_test.rb test/services/table_monitor/game_setup_test.rb test/controllers/table_monitors_controller_test.rb test/controllers/tournament_monitors_controller_test.rb test/integration/tiebreak_modal_form_wiring_test.rb test/concerns/local_protector_test.rb 2>&amp;1 | tail -20 &amp;&amp; bin/rails test test/system/tiebreak_test.rb 2>&amp;1 | tail -10 &amp;&amp; grep -rn "derive_tiebreak_required\|parse_data_hash\|derive_tiebreak_default\|persist_tournament_tiebreak\|tournament_tiebreak_on_draw\|@tiebreak_on_draw_default" app/ test/ lib/ config/ db/ 2>/dev/null | grep -v ".planning/" | wc -l</automated>
  </verify>
  <done>
    All listed test files pass with 0 failures, 0 errors. Final grep for the
    deleted symbols returns 0 hits across app/ test/ lib/ config/ db/ (with
    .planning/ excluded). Test counts recorded for SUMMARY.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>
    Removed the dead `tiebreak_on_draw` config plumbing (resolver, controllers,
    views, i18n strings, related tests). The canonical tiebreak-trigger path
    is now ONLY:

    1. `TableMonitor#playing_finals_force_tiebreak_required!` (Quick-260505-auq)
       — fires when `TournamentMonitor#playing_finals?`.
    2. `ResultRecorder#bk2_kombi_tiebreak_auto_detect!` (Phase 38.7-11) — fires
       when BK-2kombi BK-2-phase tied at goal in 1+1 innings.

    Both helpers mutate `game.data['tiebreak_required']=true` at decision
    time inside `tiebreak_pick_pending?` and `tiebreak_pending_block?`. No
    config knobs survive on the path; the override is state-driven.

    Files touched (12 production, 5 test):
    - Production: app/models/game.rb, app/controllers/{table,tournament}_monitors_controller.rb,
      app/views/tournament_monitors/_form.html.erb,
      app/views/locations/_quick_game_buttons.html.erb,
      app/views/locations/scoreboard_free_game_karambol_new.html.erb,
      app/services/table_monitor/{game_setup,result_recorder}.rb,
      config/locales/{de,en}.yml.
    - Test: test/models/game_test.rb,
      test/services/table_monitor/game_setup_test.rb,
      test/controllers/{table,tournament}_monitors_controller_test.rb,
      test/system/tiebreak_test.rb (doc-comment-only update).

    Two atomic commits on go_back_to_stable:
    - `test(quick-260505-fbb): remove dead-code tests for tiebreak_on_draw config plumbing`
    - `fix(quick-260505-fbb): remove dead tiebreak_on_draw config plumbing`

    Known dead config (out of scope, flagged in SUMMARY):
    - `config/carambus.yml` + `config/carambus.yml.erb` retain
      `tiebreak_on_draw: true` lines on BK-2 + BK-2kombi presets. With the
      hidden_field gone, these YAML keys have no consumer. Removing them
      requires a YAML-edit-pair (per Phase 38.4 decision); deferred to a
      future quick task.
  </what-built>
  <how-to-verify>
    1. Static checks (already automated in Tasks 2 + 3, but verify in this
       working tree):
       ```
       cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
       grep -rn "derive_tiebreak_required\|parse_data_hash\|derive_tiebreak_default\|persist_tournament_tiebreak\|tournament_tiebreak_on_draw\|@tiebreak_on_draw_default" app/ test/ lib/ config/ db/ 2>/dev/null | grep -v ".planning/"
       ```
       Expected output: empty.

    2. Test sweep (re-run if you want belt + suspenders):
       ```
       bin/rails test \
         test/models/game_test.rb \
         test/models/table_monitor_test.rb \
         test/services/table_monitor/result_recorder_test.rb \
         test/services/table_monitor/game_setup_test.rb \
         test/controllers/table_monitors_controller_test.rb \
         test/controllers/tournament_monitors_controller_test.rb \
         test/system/tiebreak_test.rb \
         test/integration/tiebreak_modal_form_wiring_test.rb \
         test/concerns/local_protector_test.rb
       ```
       Expected: 0 failures, 0 errors.

    3. Diff review (skim the two commits):
       ```
       git log --oneline -2
       git show HEAD~1 --stat
       git show HEAD --stat
       ```
       Expected: previous-1 = test deletions; previous = production deletions.
       Both on go_back_to_stable.

    4. UI sanity (optional, only if convenient — full regression suite is the
       primary verification):
       a) Visit /tournament_monitors/new (or /edit) — the
          "Stechen bei Unentschieden" checkbox should be ABSENT. Form should
          render cleanly with no Stimulus / ERB errors in the console.
       b) Visit /locations/{ID} small-billard panel — the BK-2 + BK-2kombi
          quick-game buttons should still work (start_game POST with the
          BK-2 70 button) but the resulting `game.data["tiebreak_required"]`
          should be ABSENT (was previously baked to `true` via the now-deleted
          GameSetup block). For non-finals, that's the intended new
          behaviour: tiebreak does not fire in training mode for plain BK-2.
       c) Visit a free-game detail form (scoreboard_free_game_karambol_new)
          — the "Stechen bei Unentschieden" checkbox should be ABSENT;
          surrounding flex layout (allow_overflow, fixed_display_left)
          should be visually intact.
       d) Tournament Finale phase reproduction (the original Quick-260505-auq
          fix surface): TournamentMonitor in `playing_finals` state, tied
          score at goal — tiebreak modal MUST still appear (override path
          unchanged). Visual or test confirmation OK.

    5. Cross-checkout precondition (per scenario-management SKILL):
       The user is currently on go_back_to_stable in carambus_bcw. The other
       scenario checkouts (carambus_master, carambus_phat, carambus_api) are
       outside this plan's scope. The user will manage cross-checkout
       sync per the SKILL's debugging-mode workflow (lines 113-131) AFTER
       approval.

    6. Decision point: do we want to attempt the YAML cleanup
       (`tiebreak_on_draw: true` on BK-2 + BK-2kombi preset entries in
       carambus.yml + carambus.yml.erb) in a follow-up step right now, or
       leave it for a separate quick task? The plan defers it to keep this
       atomic. Confirm whether to leave or chain.
  </how-to-verify>
  <resume-signal>
    Type "approved" to mark the quick task complete (SUMMARY.md write +
    STATE.md update), or describe any regressions / surprise diffs / leftover
    references you spotted.
  </resume-signal>
</task>

</tasks>

<verification>
- All deleted callable symbols (derive_tiebreak_required, parse_data_hash,
  derive_tiebreak_default, persist_tournament_tiebreak_override) verified
  zero callers via repo-wide grep before deletion AND zero residual references
  after deletion.
- All deleted controller params (`:tiebreak_on_draw`,
  `:tournament_tiebreak_on_draw`) verified absent from app/controllers/ +
  config/ after deletion.
- All deleted i18n keys (tournament_monitors.form.tiebreak_on_draw,
  locations.scoreboard_free_game.tiebreak_on_draw) verified absent via
  `bin/rails runner 'I18n.t(...)'` smoke test (returns "REMOVED").
- Quick-260505-auq override path (TableMonitor#playing_finals_force_tiebreak_required!,
  ResultRecorder#bk2_kombi_tiebreak_auto_detect!) preserved verbatim — its
  5 regression tests (M1, M2, M3, M4, R1) stay GREEN.
- Phase 38.7 Plan 11 BK-2kombi auto-detect tests stay GREEN.
- Phase 38.8 final_match_score operator gate tests stay GREEN.
- Phase 38.9 end-of-set fourth branch tests stay GREEN.
- test/concerns/local_protector_test.rb stays GREEN (MIN_ID protector
  surface unchanged).
- test/system/tiebreak_test.rb stays GREEN (doc-comment-only update;
  test bodies seed game.data['tiebreak_required'] directly via
  Game.create!(data: {...})).
- test/integration/tiebreak_modal_form_wiring_test.rb stays GREEN (tests
  view → reflex DOM wiring, NOT the deleted config plumbing).
- standardrb + erblint clean on all modified files.
- Two atomic commits on go_back_to_stable: test deletion + production deletion.
- Per CLAUDE.md: frozen_string_literal preserved on all modified Ruby files.
- Per scenario-management SKILL: this run targets carambus_bcw (debugging-mode-style
  edit on feature branch go_back_to_stable, independent of master). Cross-checkout
  sync deferred to user post-approval.
- Per extend-before-build SKILL: deletion is the inverse of extension — we
  collapse a parallel state-machine-like config plumbing chain back into the
  override path. The override path itself was already an extend-before-build
  win (see Quick-260505-auq SUMMARY) and stays untouched.
- Project memory `feedback_no_discipline_tiebreak.md` honored: NO Discipline
  rows or seed data touched.
- Project memory `feedback_extend_before_build.md` honored: dead code
  collapsed back to the canonical override path.
</verification>

<success_criteria>
- All must_haves.truths hold against the running codebase + test suite.
- Zero greps for deleted callable / param / i18n symbols return any hits in
  app/ test/ lib/ config/ db/.
- Quick-260505-auq's 5 regression tests + Phase 38.7-11 BK-2kombi auto-detect
  tests + Phase 38.8 + Phase 38.9 + tiebreak_modal_form_wiring + system
  tiebreak suite + concerns/local_protector all stay GREEN.
- Two atomic commits landed on go_back_to_stable (test deletion before
  production deletion).
- Diff review by user surfaces no regressions or leftover references.
- The dead-config note in carambus.yml + carambus.yml.erb is documented in
  the SUMMARY for a follow-up cleanup quick task.
</success_criteria>

<output>
After completion + checkpoint approval, create
`.planning/quick/260505-fbb-remove-dead-tiebreak-on-draw-config-plum/260505-fbb-SUMMARY.md`
documenting:

- Final test counts (deleted / passing / regressions = 0).
- Final LOC delta (Ruby + ERB + YAML, additions ~zero, deletions per task).
- The exact files modified and what was removed from each.
- Why this cleanup is safe NOW (Quick-260505-auq's playing_finals? override
  + Phase 38.7-11 bk2_kombi_tiebreak_auto_detect! cover all real-world
  tiebreak triggers; data side scrubbed in carambus_api production
  2026-05-05).
- Known dead config note: carambus.yml + carambus.yml.erb still carry
  `tiebreak_on_draw: true` on BK-2 + BK-2kombi presets. No consumer. Future
  YAML-edit-pair task.
- Scenario-management note: ran on carambus_bcw / go_back_to_stable
  (debugging-mode-style edit on feature branch). User to handle cross-checkout
  sync per SKILL workflow lines 113-131 after master promotion.
- Any deviations from this plan (encoding issues, lint surprises, test
  ordering surprises, etc.).
</output>
