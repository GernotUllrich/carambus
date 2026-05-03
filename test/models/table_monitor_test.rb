# frozen_string_literal: true

require "test_helper"

# Unit tests for TableMonitor model-level predicates introduced in Phase 38.2
# Plan 01. Distinct from `test/characterization/table_monitor_char_test.rb`
# which pins AASM + after_commit behavior.
#
# Phase 38.2 D-18 / UAT-GAP-05: bk2_state_uninitialized? predicate signals
# that a TableMonitor in BK2-Kombi mode has no (or empty) bk2_state Hash.
# Consumed by _show_bk2_kombi.html.erb (Plan 03) to render a fallback banner.
class TableMonitorTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Setup / Teardown
  # ---------------------------------------------------------------------------

  setup do
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
    TableMonitor.allow_change_tables = nil

    @tm = TableMonitor.create!(state: "new", data: {})
  end

  teardown do
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
    TableMonitor.allow_change_tables = nil
  end

  # ---------------------------------------------------------------------------
  # bk2_state_uninitialized? predicate
  # ---------------------------------------------------------------------------

  test "bk2_state_uninitialized? returns true when free_game_form is bk2_kombi and bk2_state is missing" do
    @tm.update!(data: {"free_game_form" => "bk2_kombi"})
    assert @tm.bk2_state_uninitialized?,
      "Missing bk2_state Hash must be flagged as uninitialized"
  end

  test "bk2_state_uninitialized? returns true when bk2_state is nil" do
    @tm.update!(data: {"free_game_form" => "bk2_kombi", "bk2_state" => nil})
    assert @tm.bk2_state_uninitialized?,
      "Nil bk2_state must be flagged as uninitialized"
  end

  test "bk2_state_uninitialized? returns true when bk2_state is an empty hash" do
    @tm.update!(data: {"free_game_form" => "bk2_kombi", "bk2_state" => {}})
    assert @tm.bk2_state_uninitialized?,
      "Empty bk2_state Hash must be flagged as uninitialized"
  end

  test "bk2_state_uninitialized? returns true when bk2_state is not a Hash" do
    @tm.update!(data: {"free_game_form" => "bk2_kombi", "bk2_state" => "not-a-hash"})
    assert @tm.bk2_state_uninitialized?,
      "Non-Hash bk2_state must be flagged as uninitialized"
  end

  test "bk2_state_uninitialized? returns false when bk2_state is a populated Hash" do
    @tm.update!(data: {
      "free_game_form" => "bk2_kombi",
      "bk2_state" => {"current_set_number" => 1, "current_phase" => "direkter_zweikampf"}
    })
    refute @tm.bk2_state_uninitialized?,
      "Populated bk2_state must be recognised as initialized"
  end

  test "bk2_state_uninitialized? returns false for non-bk2 games (karambol)" do
    @tm.update!(data: {"free_game_form" => "karambol"})
    refute @tm.bk2_state_uninitialized?,
      "Non-BK2 games must not be flagged regardless of bk2_state presence"
  end

  test "bk2_state_uninitialized? returns false for non-bk2 games (pool)" do
    @tm.update!(data: {"free_game_form" => "pool"})
    refute @tm.bk2_state_uninitialized?
  end

  test "bk2_state_uninitialized? returns false when data is empty" do
    @tm.update!(data: {})
    refute @tm.bk2_state_uninitialized?,
      "Empty data hash must not raise and must not flag"
  end

  test "bk2_state_uninitialized? returns false when data is nil-equivalent (raw write)" do
    # Simulate a raw write that yields non-Hash data. We cannot persist nil via
    # update!, but we can verify the predicate handles it in-memory.
    @tm.instance_variable_set(:@attributes, @tm.instance_variable_get(:@attributes))
    def @tm.data; nil; end
    refute @tm.bk2_state_uninitialized?,
      "Non-Hash data must not raise and must not flag"
  end

  # ---------------------------------------------------------------------------
  # Phase 38.7 Plan 02 — D-02 BK-2 game-end-fix RED-then-GREEN.
  # See .planning/phases/38.7-…/38.7-CONTEXT.md D-02 + D-16.
  # ---------------------------------------------------------------------------

  # Phase 38.7 Plan 02 helper: builds a minimal TableMonitor.data Hash that
  # satisfies end_of_set?'s GUARD (innings + points must be > 0).
  def build_bk_data(free_game_form:, balls_goal:, playera_result:, playera_innings:,
                    playerb_result:, playerb_innings:, allow_follow_up: true,
                    bk2_options: nil)
    d = {
      "free_game_form" => free_game_form,
      "allow_follow_up" => allow_follow_up,
      "playera" => {"result" => playera_result, "innings" => playera_innings, "balls_goal" => balls_goal},
      "playerb" => {"result" => playerb_result, "innings" => playerb_innings, "balls_goal" => balls_goal},
      "current_inning" => {"active_player" => "playerb", "balls" => 0}
    }
    d["bk2_options"] = bk2_options if bk2_options
    d
  end

  test "end_of_set? closes BK-2 set when both reach balls_goal at equal innings (TR-B baseline)" do
    @tm.data = build_bk_data(free_game_form: "bk_2", balls_goal: 50,
                             playera_result: 50, playera_innings: 5,
                             playerb_result: 50, playerb_innings: 5)
    assert @tm.end_of_set?,
      "BK-2 with both players at balls_goal=50 and equal innings=5 must end_of_set " \
      "(regression guard for the bk_2 legacy karambol gate path)"
  end

  test "end_of_set? closes BK-2 set when nachstoss-spieler reaches balls_goal in his nachstoss-aufnahme (D-02 fix)" do
    # Anstoss=playera reached 50 in inning 5; Nachstoss=playerb plays his inning 6 (Nachstoss-Aufnahme)
    # and ALSO reaches 50. Today: end_of_set? returns false (deadlock). After fix: returns true.
    @tm.data = build_bk_data(free_game_form: "bk_2", balls_goal: 50,
                             playera_result: 50, playera_innings: 5,
                             playerb_result: 50, playerb_innings: 6)
    assert @tm.end_of_set?,
      "D-02 BK-2 fix: Nachstoss-Aufnahme completed with both at balls_goal must end the set " \
      "(today returns false — deadlock — TEST EXPECTED TO FAIL BEFORE TASK 2 LANDS)"
  end

  test "end_of_set? closes BK-2kombi SP-phase when nachstoss-spieler reaches balls_goal in his nachstoss-aufnahme (D-02 fix, multiset)" do
    # BK-2kombi second set is the SP-Phase when first_set_mode=direkter_zweikampf.
    # We simulate by giving data["sets"] one prior entry so set-counter shows set #2 (SP).
    @tm.data = build_bk_data(free_game_form: "bk2_kombi", balls_goal: 70,
                             playera_result: 70, playera_innings: 5,
                             playerb_result: 70, playerb_innings: 6,
                             bk2_options: {"first_set_mode" => "direkter_zweikampf"})
    @tm.data["sets"] = [{"Ergebnis1" => 70, "Ergebnis2" => 50, "Aufnahmen1" => 4, "Aufnahmen2" => 4,
                         "Höchstserie1" => 0, "Höchstserie2" => 0}]
    assert_equal "serienspiel", @tm.bk2_kombi_current_phase,
      "Sanity: this scenario must place us in SP-Phase (set 2 with first_set_mode=DZ)"
    assert @tm.end_of_set?,
      "D-02 BK-2kombi-SP fix: Nachstoss-Aufnahme completed with both at balls_goal must end the set"
  end

  test "end_of_set? does NOT fire when Nachstoss has not reached balls_goal (regression guard)" do
    # Anstoss=playera reached 50; Nachstoss=playerb at result=49 in his 6th inning (Nachstoss-Aufnahme
    # done, but goal NOT reached). Legacy: end_of_set? must fire because innings-equal-or-Anstoss-+1
    # gate fires for the Anstoss reaching goal. We expect TRUE here per legacy semantics.
    @tm.data = build_bk_data(free_game_form: "bk_2", balls_goal: 50,
                             playera_result: 50, playera_innings: 5,
                             playerb_result: 49, playerb_innings: 6)
    assert @tm.end_of_set?,
      "Regression guard: BK-2 with Anstoss at goal AND Nachstoss-Aufnahme done (no goal) must end_of_set " \
      "via the existing legacy karambol path (this is the TR-B success path, NOT a tiebreak)"
  end

  test "end_of_set? does NOT fire when neither player reached balls_goal (regression guard)" do
    @tm.data = build_bk_data(free_game_form: "bk_2", balls_goal: 50,
                             playera_result: 49, playera_innings: 5,
                             playerb_result: 49, playerb_innings: 5)
    refute @tm.end_of_set?,
      "Regression guard: no player at balls_goal must NOT end_of_set"
  end

  # ---------------------------------------------------------------------------
  # Phase 38.9 Plan 01 — BK-2 / BK-2kombi-SP end-of-set Anstoss-at-goal-in-inning-2 fix.
  # See .planning/phases/38.9-…/38.9-CONTEXT.md and
  # .planning/debug/bk2-nachstoss-banner-missing.md.
  #
  # Symmetric to the follow_up? Erste-Aufnahme-Gate (table_monitor.rb:1205-1210):
  # when Anstoss-Spieler reaches balls_goal in inning >= 2, Nachstoss-Aufnahme is
  # rule-disallowed (he had his table time), so the set MUST close immediately.
  # Today: end_of_set? returns false (latent defect). Player B silently plays an
  # unauthorized inning before the legacy parity gate closes the set without ever
  # showing the red "Nachstoß" banner.
  # ---------------------------------------------------------------------------

  test "end_of_set? closes BK-2 set immediately when Anstoss reaches balls_goal in inning 2 (Erste-Aufnahme-Gate fails — SC-1)" do
    # Anstoss=playera reaches balls_goal=50 in his 2nd inning. Nachstoss=playerb
    # has NOT played yet (innings=0). Per the BK-2 rule, Nachstoss-Aufnahme is
    # only granted if Anstoss reached the goal in his 1st inning (Erste-Aufnahme-
    # Gate). Reaching it in inning 2+ means Anstoss already had table time;
    # opponent gets NO equalizer chance. Therefore: end_of_set? must return true.
    #
    # Today: returns false. Branch 1 (no_followup_phase) excludes bk_2; Branch 2
    # (Plan 38.7-02 D-02) requires nachstoss_innings == anstoss_innings+1 (0 != 3);
    # Branch 3 (legacy karambol) requires innings parity OR !allow_follow_up
    # (2 != 0 and allow_follow_up=true). Set stays open silently → terminate_inning_data
    # swaps active_player → Player B plays unauthorized inning → no red "Nachstoß"
    # banner (correctly suppressed by follow_up? Erste-Aufnahme-Gate).
    #
    # After Task 3 fix lands: new 4th branch fires (bk_with_nachstoss && anstoss_at_goal
    # && anstoss_innings >= 2) and returns true.
    @tm.data = build_bk_data(free_game_form: "bk_2", balls_goal: 50,
                             playera_result: 50, playera_innings: 2,
                             playerb_result: 0, playerb_innings: 0)
    assert @tm.end_of_set?,
      "SC-1: BK-2 with Anstoss=playera reaching balls_goal=50 in inning 2 must close " \
      "the set IMMEDIATELY (Erste-Aufnahme-Gate fails on the close-side, mirroring " \
      "follow_up? at table_monitor.rb:1205-1210). " \
      "TODAY THIS FAILS — proves the latent defect (commit 79328663). " \
      "TEST EXPECTED TO FAIL BEFORE TASK 3 LANDS."
  end

  test "end_of_set? does NOT close BK-2 set when Anstoss reaches balls_goal in inning 1 (Erste-Aufnahme-Gate happy path — SC-2)" do
    # Anstoss=playera reaches balls_goal=50 in his 1ST inning (Erste-Aufnahme satisfied).
    # Nachstoss=playerb has NOT played yet (innings=0). Per BK-2 rule, Nachstoss-Aufnahme
    # IS granted in this case — red "Nachstoß" banner must appear, set stays open until
    # Nachstoss completes his single follow-up inning (whereupon Plan 38.7-02 D-02
    # branch closes it).
    #
    # Therefore: end_of_set? must return FALSE here — both today AND after the Task 3
    # fix lands. This pins the boundary condition: the new 4th branch's
    # `anstoss_innings >= 2` predicate must NOT over-fire when anstoss_innings == 1.
    @tm.data = build_bk_data(free_game_form: "bk_2", balls_goal: 50,
                             playera_result: 50, playera_innings: 1,
                             playerb_result: 0, playerb_innings: 0)
    refute @tm.end_of_set?,
      "SC-2: BK-2 with Anstoss=playera reaching balls_goal=50 in inning 1 must KEEP " \
      "the set open (Erste-Aufnahme-Gate happy path — Nachstoss-Aufnahme still permitted, " \
      "red banner still renders via follow_up?). Set closes only after Nachstoss-Aufnahme " \
      "completes (Plan 38.7-02 D-02 branch). " \
      "REGRESSION GUARD — passes today AND must continue passing after Task 3."
  end

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

  # ---------------------------------------------------------------------------
  # Quick-260503-hay — BK-2plus / BK-2kombi DZ-Phase MUST NOT close on
  # innings_goal=5 (legacy karambol close branch is phase-blind).
  #
  # Background: commit 1491385f (2026-04-26) set innings_goal=5 for the
  # entire BK-* family as an SP-phase safety net. The legacy karambol close
  # branch at table_monitor.rb:1583-1587 has no phase awareness — it fires
  # whenever both players reach innings_goal (allow_follow_up=true) or any
  # one player does (allow_follow_up=false). For BK-2plus (no Nachstoss, no
  # inning limit) and BK-2kombi DZ-Phase (shot-limit per turn, not inning
  # limit per set) this is wrong — those phases must keep playing until
  # balls_goal is reached.
  #
  # SKILL extend-before-build: regression tests for a one-line guard added
  # to the existing legacy branch. NO new predicate, NO refactor.
  # ---------------------------------------------------------------------------

  test "end_of_set? does NOT close BK-2plus standalone when both reach 5 innings without balls_goal (260503-hay)" do
    # BK-2plus: allow_follow_up=false (controller line 329). innings_goal=5
    # (controller fallback line 305 / 100). Today the legacy branch at
    # table_monitor.rb:1583-1587 fires because !allow_follow_up AND
    # playera.innings(5) >= innings_goal(5) — closes the set prematurely.
    # After Task 2 fix lands: branch is skipped because free_game_form=="bk_2plus".
    @tm.data = build_bk_data(free_game_form: "bk_2plus", balls_goal: 50,
                             playera_result: 30, playera_innings: 5,
                             playerb_result: 30, playerb_innings: 5,
                             allow_follow_up: false)
    @tm.data["innings_goal"] = 5
    refute @tm.end_of_set?,
      "BK-2plus has NO Aufnahmenbegrenzung — set must stay open until balls_goal reached " \
      "(TODAY THIS FAILS — legacy karambol branch is phase-blind, fires on " \
      "!allow_follow_up && playera.innings >= innings_goal). " \
      "TEST EXPECTED TO FAIL BEFORE TASK 2 LANDS."
  end

  test "end_of_set? does NOT close BK-2kombi DZ-Phase when both reach 5 innings without balls_goal (260503-hay)" do
    # BK-2kombi DZ-Phase: allow_follow_up=true (controller line 327). innings_goal=5
    # (controller fallback). Today the legacy branch fires because
    # playera.innings(5) == playerb.innings(5) AND playera.innings(5) >= innings_goal(5)
    # — closes DZ-Phase set prematurely even though DZ uses shot-limit per turn.
    # After Task 2 fix lands: branch is skipped because bk2_kombi_current_phase=="direkter_zweikampf".
    @tm.data = build_bk_data(free_game_form: "bk2_kombi", balls_goal: 70,
                             playera_result: 40, playera_innings: 5,
                             playerb_result: 40, playerb_innings: 5,
                             allow_follow_up: true,
                             bk2_options: {"first_set_mode" => "direkter_zweikampf",
                                           "serienspiel_max_innings_per_set" => 5})
    @tm.data["innings_goal"] = 5
    # data["sets"] left empty → set #1 → DZ-Phase
    assert_equal "direkter_zweikampf", @tm.bk2_kombi_current_phase,
      "Sanity: empty data['sets'] with first_set_mode=DZ must place us in direkter_zweikampf"
    refute @tm.end_of_set?,
      "DZ-Phase has shot-limit per turn, NOT inning-limit per set — set must stay open " \
      "(TODAY THIS FAILS — legacy karambol branch fires on innings parity + innings_goal). " \
      "TEST EXPECTED TO FAIL BEFORE TASK 2 LANDS."
  end

  test "end_of_set? STILL closes karambol when innings_goal reached at equal innings (legacy branch regression guard, 260503-hay)" do
    # Pure karambol: balls_goal=250, both at result=200/innings=30, innings_goal=30.
    # Result < balls_goal so the balls_goal branch never fires. Legacy karambol
    # branch must continue to close the set. This guards against over-broad
    # exclusion in Task 2 — the guard must scope to BK-* phases only.
    @tm.data = build_bk_data(free_game_form: "karambol", balls_goal: 250,
                             playera_result: 200, playera_innings: 30,
                             playerb_result: 200, playerb_innings: 30,
                             allow_follow_up: true)
    @tm.data["innings_goal"] = 30
    assert @tm.end_of_set?,
      "karambol legacy branch must keep firing — Task 2 guard must scope to BK-* only " \
      "(regression guard against over-broad exclusion)"
  end

  test "end_of_set? STILL closes BK-2kombi SP-Phase via the existing 260501-uxo SP-inning-limit branch (260503-hay sanity)" do
    # BK-2kombi SP-Phase fixture mirrors test on lines 252-266: data["sets"] has
    # one prior entry → set #2 → SP-Phase. Both players at result=50 / innings=5,
    # sp_max=5. The 260501-uxo SP-inning-limit branch (lines 1568-1575) fires
    # BEFORE reaching the legacy karambol branch — so even after Task 2's guard
    # lands, this test still passes (close fires earlier, the guard never matters
    # for this fixture).
    @tm.data = build_bk_data(free_game_form: "bk2_kombi", balls_goal: 70,
                             playera_result: 50, playera_innings: 5,
                             playerb_result: 50, playerb_innings: 5,
                             allow_follow_up: true,
                             bk2_options: {"first_set_mode" => "direkter_zweikampf",
                                           "serienspiel_max_innings_per_set" => 5})
    @tm.data["sets"] = [{"Ergebnis1" => 70, "Ergebnis2" => 50, "Aufnahmen1" => 4, "Aufnahmen2" => 4,
                         "Höchstserie1" => 0, "Höchstserie2" => 0}]
    @tm.data["innings_goal"] = 5
    assert_equal "serienspiel", @tm.bk2_kombi_current_phase,
      "Sanity: SP-Phase fixture must place us in serienspiel"
    assert @tm.end_of_set?,
      "260501-uxo SP-Phase inning-limit branch fires before legacy branch — " \
      "this test stays GREEN before AND after Task 2 (BK-2kombi SP path unchanged)"
  end

  # ---------------------------------------------------------------------------
  # Phase 38.7 Plan 05 T9 — D-08 AASM acknowledge_result guard (defense-in-depth).
  # See .planning/phases/38.7-…/38.7-CONTEXT.md D-08.
  #
  # Verifies that direct calls to acknowledge_result! and may_acknowledge_result?
  # honour the tiebreak_pending_block? predicate, regardless of caller path.
  # ---------------------------------------------------------------------------

  test "acknowledge_result! AASM guard blocks transition when tiebreak pending (D-08 defense-in-depth)" do
    game = Game.create!(data: {"tiebreak_required" => true}, group_no: 1, seqno: 1, table_no: 1)
    @tm.update!(
      data: {
        "free_game_form" => "karambol",
        "playera" => {"result" => 80, "innings" => 30, "balls_goal" => 80},
        "playerb" => {"result" => 80, "innings" => 30, "balls_goal" => 80},
        "innings_goal" => 30,
        "allow_follow_up" => false
      }
    )
    @tm.update_columns(game_id: game.id, state: "set_over")
    @tm.reload

    # PHASE 1 — guard blocks while pick is pending.
    assert @tm.tiebreak_pending_block?,
      "Sanity: pending-block predicate must report true (tiebreak_required + tied + no winner)"
    refute @tm.may_acknowledge_result?,
      "may_acknowledge_result? must return false while tiebreak winner is pending"
    assert_raises(AASM::InvalidTransition,
                  "acknowledge_result! must raise AASM::InvalidTransition while tiebreak pending") do
      @tm.acknowledge_result!
    end
    @tm.reload
    assert_equal "set_over", @tm.state,
      "State must NOT have transitioned while the guard blocks the event"

    # PHASE 2 — once the operator picks, the guard releases.
    game.update!(data: {"tiebreak_required" => true, "tiebreak_winner" => "playera"})
    @tm.reload
    refute @tm.tiebreak_pending_block?,
      "Sanity: pending-block predicate must report false after pick lands"
    assert @tm.may_acknowledge_result?,
      "may_acknowledge_result? must return true after pick lands"
    assert_nothing_raised do
      @tm.acknowledge_result!
    end
    @tm.reload
    assert_equal "final_set_score", @tm.state,
      "State must transition to final_set_score after the pick releases the guard"
  end

  # T9 supplemental: guard does NOT block when scores are NOT tied (regression).
  test "acknowledge_result! AASM guard allows transition when scores NOT tied (regression)" do
    game = Game.create!(data: {"tiebreak_required" => true}, group_no: 1, seqno: 1, table_no: 1)
    @tm.update!(
      data: {
        "free_game_form" => "karambol",
        "playera" => {"result" => 80, "innings" => 30, "balls_goal" => 80},
        "playerb" => {"result" => 70, "innings" => 30, "balls_goal" => 80},
        "innings_goal" => 30,
        "allow_follow_up" => false
      }
    )
    @tm.update_columns(game_id: game.id, state: "set_over")
    @tm.reload

    refute @tm.tiebreak_pending_block?,
      "Untied scores: pending-block predicate must report false (no tiebreak required)"
    assert @tm.may_acknowledge_result?
    assert_nothing_raised { @tm.acknowledge_result! }
    @tm.reload
    assert_equal "final_set_score", @tm.state
  end

  # ---------------------------------------------------------------------------
  # Phase 38.8 Plan 06 — AASM :start_rematch event tests (added by Plan 38.8-02).
  # Locks: from-state guard (only :final_match_score), positive transition to
  # :playing, after-callbacks revert_players + do_play execute in order.
  # ---------------------------------------------------------------------------

  test "may_start_rematch? returns true only when state is final_match_score" do
    @tm.update!(state: "final_match_score", data: {"playera" => {"result" => 100, "innings" => 5, "balls_goal" => 100}, "playerb" => {"result" => 60, "innings" => 5, "balls_goal" => 100}})
    assert @tm.may_start_rematch?, "from final_match_score may_start_rematch? must be true"

    %w[new ready warmup playing set_over final_set_score ready_for_new_match].each do |bad_state|
      tm2 = TableMonitor.create!(state: bad_state, data: {})
      refute tm2.may_start_rematch?, "from #{bad_state} may_start_rematch? must be false"
    end
  end

  test "start_rematch! from final_match_score transitions to playing" do
    # Setup minimal data hash so revert_players + do_play do not crash on missing keys.
    # revert_players (table_monitor.rb:1389) reads playera/playerb hashes; do_play reads timer fields.
    @tm.update!(
      state: "final_match_score",
      data: {
        "fixed_display_left" => "playera",
        "playera" => {"balls_goal" => 100, "discipline" => "Freie Partie klein"},
        "playerb" => {"balls_goal" => 100, "discipline" => "Freie Partie klein"},
        "timeouts" => 0,
        "timeout" => 0,
        "innings_goal" => 0,
        "sets_to_play" => 1,
        "sets_to_win" => 1,
        "kickoff_switches_with" => "set",
        "free_game_form" => "standard",
        "current_kickoff_player" => "playera"
      }
    )

    # Stub revert_players + do_play to avoid touching game/GameParticipation chain
    # (those associations are not set on this minimal fixture).
    @tm.define_singleton_method(:revert_players) { @revert_called = true }
    @tm.define_singleton_method(:do_play) { @do_play_called = true }

    assert_nothing_raised { @tm.start_rematch! }
    assert_equal "playing", @tm.state, "AASM transition :final_match_score -> :playing must succeed"
    assert @tm.instance_variable_get(:@revert_called), "after-callback :revert_players must fire"
    assert @tm.instance_variable_get(:@do_play_called), "after-callback :do_play must fire"
  end

  test "start_rematch! from non-final_match_score state raises AASM::InvalidTransition" do
    @tm.update!(state: "playing", data: {})
    assert_raises(AASM::InvalidTransition, "start_rematch! from :playing must be rejected by AASM from-state guard") do
      @tm.start_rematch!
    end
    assert_equal "playing", @tm.reload.state, "state must remain :playing after rejected transition"
  end

end
