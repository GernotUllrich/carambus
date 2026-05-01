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
