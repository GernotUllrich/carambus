# frozen_string_literal: true

require "test_helper"

class Bk2Kombi::CommitInningTest < ActiveSupport::TestCase
  setup do
    @tm = table_monitors(:free)
    # Base bk2_kombi state — each test overrides what it needs.
    @tm.update!(data: {
      "free_game_form" => "bk2_kombi",
      "bk2_options" => {
        "set_target_points" => 50,
        "direkter_zweikampf_max_shots_per_turn" => 2,
        "serienspiel_max_innings_per_set" => 5,
        "first_set_mode" => "direkter_zweikampf"
      },
      "bk2_state" => fresh_bk2_state("direkter_zweikampf")
    })
  end

  # ---------------------------------------------------------------------------
  # T1: DZ positive inning credits current player
  # ---------------------------------------------------------------------------

  test "38.3-01 T1: DZ positive inning credits current player" do
    state = fresh_bk2_state("direkter_zweikampf")
    state["set_scores"]["1"]["playera"] = 10
    @tm.update!(data: @tm.data.merge("bk2_state" => state))

    Bk2Kombi::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: 7
    )

    s = @tm.reload.data["bk2_state"]
    assert_equal 17, s["set_scores"]["1"]["playera"], "playera score must be 10+7"
    assert_equal 0, s["set_scores"]["1"]["playerb"], "playerb score must be unchanged"
    assert_equal "playerb", s["player_at_table"], "player_at_table must flip to playerb"
    assert_equal 2, s["shots_left_in_turn"], "shots_left_in_turn must reset to DZ max (2)"
  end

  # ---------------------------------------------------------------------------
  # T2: DZ negative inning (D-11) — abs credits opponent
  # ---------------------------------------------------------------------------

  test "38.3-01 T2: DZ negative inning credits abs to opponent" do
    state = fresh_bk2_state("direkter_zweikampf")
    state["set_scores"]["1"]["playera"] = 10
    state["set_scores"]["1"]["playerb"] = 5
    @tm.update!(data: @tm.data.merge("bk2_state" => state))

    Bk2Kombi::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: -3
    )

    s = @tm.reload.data["bk2_state"]
    assert_equal 10, s["set_scores"]["1"]["playera"], "playera score must be UNCHANGED"
    assert_equal 8, s["set_scores"]["1"]["playerb"], "playerb score must be 5 + abs(-3)"
    assert_equal "playerb", s["player_at_table"], "player_at_table must flip to playerb"
  end

  # ---------------------------------------------------------------------------
  # T3: DZ zero inning — no score change, player flips, shots reset
  # ---------------------------------------------------------------------------

  test "38.3-01 T3: DZ zero inning changes no score but flips player and resets shots" do
    state = fresh_bk2_state("direkter_zweikampf")
    @tm.update!(data: @tm.data.merge("bk2_state" => state))

    Bk2Kombi::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: 0
    )

    s = @tm.reload.data["bk2_state"]
    assert_equal 0, s["set_scores"]["1"]["playera"], "playera score unchanged"
    assert_equal 0, s["set_scores"]["1"]["playerb"], "playerb score unchanged"
    assert_equal "playerb", s["player_at_table"], "player_at_table must flip"
    assert_equal 2, s["shots_left_in_turn"], "shots_left_in_turn must reset"
  end

  # ---------------------------------------------------------------------------
  # T4: SP positive inning (D-12) — additive to own score, innings_left decrements
  # ---------------------------------------------------------------------------

  test "38.3-01 T4: SP positive inning adds to player score and decrements innings_left" do
    state = fresh_bk2_state("serienspiel")
    state["set_scores"]["1"]["playera"] = 10
    @tm.update!(data: @tm.data.merge("bk2_state" => state))

    Bk2Kombi::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: 12
    )

    s = @tm.reload.data["bk2_state"]
    assert_equal 22, s["set_scores"]["1"]["playera"], "playera score must be 10+12"
    assert_equal "playerb", s["player_at_table"], "player_at_table must flip to playerb"
    assert_equal 4, s["innings_left_in_set"], "innings_left_in_set must decrement from 5 to 4"
  end

  # ---------------------------------------------------------------------------
  # T5: SP negative inning (D-12) — signed add, score decreases
  # ---------------------------------------------------------------------------

  test "38.3-01 T5: SP negative inning decreases player score" do
    state = fresh_bk2_state("serienspiel")
    state["set_scores"]["1"]["playera"] = 10
    @tm.update!(data: @tm.data.merge("bk2_state" => state))

    Bk2Kombi::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: -4
    )

    s = @tm.reload.data["bk2_state"]
    assert_equal 6, s["set_scores"]["1"]["playera"], "playera score must be 10 + (-4)"
    assert_equal 4, s["innings_left_in_set"], "innings_left_in_set must decrement"
  end

  # ---------------------------------------------------------------------------
  # T6: SP negative taking score below zero (D-06/D-12 — score CAN go negative)
  # ---------------------------------------------------------------------------

  test "38.3-01 T6: SP negative inning can push score below zero" do
    state = fresh_bk2_state("serienspiel")
    state["set_scores"]["1"]["playera"] = 3
    @tm.update!(data: @tm.data.merge("bk2_state" => state))

    Bk2Kombi::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: -8
    )

    s = @tm.reload.data["bk2_state"]
    assert_equal(-5, s["set_scores"]["1"]["playera"], "playera score must be 3 + (-8) = -5")
  end

  # ---------------------------------------------------------------------------
  # T7: DZ set close on target reached
  # ---------------------------------------------------------------------------

  test "38.3-01 T7: DZ inning reaching target closes set and advances to set 2" do
    state = fresh_bk2_state("direkter_zweikampf")
    state["set_scores"]["1"]["playera"] = 45
    @tm.update!(data: @tm.data.merge("bk2_state" => state))

    Bk2Kombi::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: 7
    )

    s = @tm.reload.data["bk2_state"]
    assert_equal 52, s["set_scores"]["1"]["playera"], "playera score must be 45+7"
    assert_equal true, s["set_finished_1"], "set_finished_1 must be true"
    assert_equal "playera", s["set_winner_1"], "set_winner_1 must be playera"
    assert_equal 1, s["sets_won"]["playera"], "sets_won.playera must be 1"
    assert_equal 2, s["current_set_number"], "current_set_number must advance to 2"
    assert_equal "serienspiel", s["current_phase"],
      "Phase must flip to serienspiel (DZ first_set_mode → set 2 flips)"
    assert_equal 5, s["innings_left_in_set"], "innings_left_in_set must reset for SP set"
    assert_equal 0, s["shots_left_in_turn"], "shots_left_in_turn must be 0 in SP"
  end

  # ---------------------------------------------------------------------------
  # T8: DZ set close via opponent credit (negative inning)
  # ---------------------------------------------------------------------------

  test "38.3-01 T8: DZ set close via opponent credit on negative inning" do
    state = fresh_bk2_state("direkter_zweikampf")
    state["set_scores"]["1"]["playerb"] = 45
    @tm.update!(data: @tm.data.merge("bk2_state" => state))

    Bk2Kombi::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: -7
    )

    s = @tm.reload.data["bk2_state"]
    assert_equal 52, s["set_scores"]["1"]["playerb"], "playerb score must be 45 + abs(-7)"
    assert_equal "playerb", s["set_winner_1"], "set_winner_1 must be playerb"
    assert_equal 1, s["sets_won"]["playerb"], "sets_won.playerb must be 1"
    assert_equal 2, s["current_set_number"], "current_set_number must advance to 2"
  end

  # ---------------------------------------------------------------------------
  # T9: Match close at 2:0
  # ---------------------------------------------------------------------------

  test "38.3-01 T9: match closes when playera reaches 2 sets won" do
    state = fresh_bk2_state("serienspiel")
    state["current_set_number"] = 2
    state["sets_won"] = {"playera" => 1, "playerb" => 0}
    state["set_scores"]["2"]["playera"] = 45
    @tm.update!(data: @tm.data.merge("bk2_state" => state))

    Bk2Kombi::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: 10
    )

    s = @tm.reload.data["bk2_state"]
    assert_equal true, s["match_finished"], "match_finished must be true"
    assert_equal "playera", s["match_winner"], "match_winner must be playera"
  end

  # ---------------------------------------------------------------------------
  # T10: Idempotency via shot_sequence_number
  # ---------------------------------------------------------------------------

  test "38.3-01 T10: same shot_sequence_number submitted twice is a no-op on second call" do
    state = fresh_bk2_state("direkter_zweikampf")
    state["set_scores"]["1"]["playera"] = 10
    @tm.update!(data: @tm.data.merge("bk2_state" => state))

    Bk2Kombi::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: 5,
      shot_sequence_number: "seq-1"
    )
    score_after_first = @tm.reload.data["bk2_state"]["set_scores"]["1"]["playera"]

    result = Bk2Kombi::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: 5,
      shot_sequence_number: "seq-1"
    )

    assert_equal score_after_first, @tm.reload.data["bk2_state"]["set_scores"]["1"]["playera"],
      "Second call with same sequence number must not change the score"
    assert result[:idempotent_noop], "Result must indicate idempotent no-op"
  end

  # ---------------------------------------------------------------------------
  # T11: Invalid player raises ArgumentError
  # ---------------------------------------------------------------------------

  test "38.3-01 T11: invalid player raises ArgumentError" do
    assert_raises(ArgumentError) do
      Bk2Kombi::CommitInning.call(
        table_monitor: @tm,
        player: "playerX",
        inning_total: 5
      )
    end
  end

  # ---------------------------------------------------------------------------
  # T12: Non-Integer inning_total raises ArgumentError
  # ---------------------------------------------------------------------------

  test "38.3-01 T12: non-Integer inning_total raises ArgumentError" do
    assert_raises(ArgumentError) do
      Bk2Kombi::CommitInning.call(
        table_monitor: @tm,
        player: "playera",
        inning_total: "5"
      )
    end
  end

  # ---------------------------------------------------------------------------
  # T13: Out-of-range inning_total raises ArgumentError
  # ---------------------------------------------------------------------------

  test "38.3-01 T13: out-of-range inning_total (>999) raises ArgumentError" do
    assert_raises(ArgumentError) do
      Bk2Kombi::CommitInning.call(
        table_monitor: @tm,
        player: "playera",
        inning_total: 1_000_000
      )
    end
  end

  test "38.3-01 T13b: out-of-range inning_total (<-999) raises ArgumentError" do
    assert_raises(ArgumentError) do
      Bk2Kombi::CommitInning.call(
        table_monitor: @tm,
        player: "playera",
        inning_total: -1_000_000
      )
    end
  end

  # ---------------------------------------------------------------------------
  # T14: Return shape is {state:, transitions:}
  # ---------------------------------------------------------------------------

  test "38.3-01 T14: return value has :state and :transitions keys" do
    result = Bk2Kombi::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: 3
    )

    assert result.key?(:state), "result must have :state key"
    assert result.key?(:transitions), "result must have :transitions key"
    assert_equal @tm.reload.data["bk2_state"], result[:state],
      ":state must equal persisted bk2_state"
  end

  # ---------------------------------------------------------------------------
  # T15: Uninitialized state auto-inits
  # ---------------------------------------------------------------------------

  test "38.3-01 T15: uninitialized bk2_state auto-inits then applies inning" do
    @tm.update!(data: {
      "free_game_form" => "bk2_kombi",
      "bk2_options" => {
        "set_target_points" => 50,
        "direkter_zweikampf_max_shots_per_turn" => 2,
        "serienspiel_max_innings_per_set" => 5,
        "first_set_mode" => "direkter_zweikampf"
      }
    })

    Bk2Kombi::CommitInning.call(
      table_monitor: @tm,
      player: "playera",
      inning_total: 5
    )

    s = @tm.reload.data["bk2_state"]
    assert_not_nil s, "bk2_state must be initialized"
    assert_equal 1, s["current_set_number"], "current_set_number must be 1"
    assert_equal "direkter_zweikampf", s["current_phase"], "current_phase must be direkter_zweikampf"
    assert_equal 5, s["set_scores"]["1"]["playera"], "playera score must be 5 after inning"
  end

  private

  def fresh_bk2_state(phase)
    {
      "current_set_number" => 1,
      "current_phase" => phase,
      "first_set_mode" => "direkter_zweikampf",
      "player_at_table" => "playera",
      "shots_left_in_turn" => (phase == "direkter_zweikampf") ? 2 : 0,
      "innings_left_in_set" => (phase == "serienspiel") ? 5 : 0,
      "set_scores" => {
        "1" => {"playera" => 0, "playerb" => 0},
        "2" => {"playera" => 0, "playerb" => 0},
        "3" => {"playera" => 0, "playerb" => 0}
      },
      "sets_won" => {"playera" => 0, "playerb" => 0},
      "set_target_points" => 50
    }
  end
end
