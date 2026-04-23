# frozen_string_literal: true

require "test_helper"

# State-Mutations-Tests fuer Bk2Kombi::AdvanceMatchState.
#
# Verifiziert: Grundlegende Zustandsaktualisierung, Satzende, Matchende,
# Persistenz via tm.save!, Initialisierungspfad bei nil-State und
# Idempotenz-Guard (shot_sequence_number).
#
# Alle Tests verwenden in der Datenbank gespeicherte TableMonitor-Datensaetze.
class Bk2Kombi::AdvanceMatchStateTest < ActiveSupport::TestCase
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

    @tm = TableMonitor.create!(
      state: "playing",
      data: {
        "free_game_form" => "bk2_kombi",
        "current_kickoff_player" => "playera",
        "bk2_state" => {
          "current_set_number" => 1,
          "current_phase" => "direkter_zweikampf",
          "player_at_table" => "playera",
          "shots_left_in_turn" => 2,
          "set_scores" => {
            "1" => {"playera" => 0, "playerb" => 0},
            "2" => {"playera" => 0, "playerb" => 0},
            "3" => {"playera" => 0, "playerb" => 0}
          },
          "sets_won" => {"playera" => 0, "playerb" => 0},
          "set_target_points" => 50
        }
      }
    )
  end

  # Helper to build a simple non-foul shot payload.
  def pin_shot(fallen_pins:, player_at_table: nil)
    payload = {
      observations: {
        fallen_pins: fallen_pins,
        middle_pin_only: false,
        true_carom: false,
        false_carom: false,
        passages: 0,
        foul: false,
        foul_code: nil,
        band_hit: false
      },
      table_snapshot: {full_pin_image: false}
    }
    payload
  end

  def foul_shot(foul_code:, fallen_pins: 0)
    {
      observations: {
        fallen_pins: fallen_pins,
        middle_pin_only: false,
        true_carom: false,
        false_carom: false,
        passages: 0,
        foul: true,
        foul_code: foul_code,
        band_hit: false
      },
      table_snapshot: {full_pin_image: false}
    }
  end

  # Update bk2_state shortcut
  def bk2_state
    @tm.reload.data["bk2_state"]
  end

  # ---------------------------------------------------------------------------
  # Test 1: Basic state update (non-foul shot)
  # ---------------------------------------------------------------------------

  test "test 1: fresh bk2_state, shot scores 3 pins for playera → set_scores updated, shots_left decremented" do
    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 3)
    )

    state = bk2_state
    assert_equal 3, state["set_scores"]["1"]["playera"]
    assert_equal 0, state["set_scores"]["1"]["playerb"]
    assert_equal "playera", state["player_at_table"], "Player should not change (still has shots)"
    assert_equal 1, state["shots_left_in_turn"]
  end

  # ---------------------------------------------------------------------------
  # Test 2: Foul shot — opponent gets credit, player swaps
  # ---------------------------------------------------------------------------

  test "test 2: foul shot credits points to opponent, player swaps" do
    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: foul_shot(foul_code: :wrong_ball)
    )

    state = bk2_state
    assert_equal 0, state["set_scores"]["1"]["playera"]
    assert_equal 6, state["set_scores"]["1"]["playerb"], "Opponent receives 6 for wrong_ball foul"
    assert_equal "playerb", state["player_at_table"], "Turn should end on foul"
    assert_equal 2, state["shots_left_in_turn"], "shots_left reset to 2 after player swap"
  end

  # ---------------------------------------------------------------------------
  # Test 3: Set close — playera reaches target 50
  # ---------------------------------------------------------------------------

  test "test 3: playera at 47, shot scores 5 → set closes, sets_won incremented, set 2 starts" do
    @tm.data["bk2_state"]["set_scores"]["1"]["playera"] = 47
    @tm.save!

    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 5)
    )

    state = bk2_state
    assert state["set_scores"]["1"]["playera"] >= 50, "playera should have >= 50 points"
    assert_equal 1, state["sets_won"]["playera"], "playera wins set 1"
    assert_equal 0, state["sets_won"]["playerb"]
    assert_equal 2, state["current_set_number"], "Should advance to set 2"
    assert_equal "direkter_zweikampf", state["current_phase"], "Phase resets to direkter_zweikampf"
    assert_equal 2, state["shots_left_in_turn"], "shots_left_in_turn resets to 2"
  end

  # ---------------------------------------------------------------------------
  # Test 4: Set close with configurable target 60
  # ---------------------------------------------------------------------------

  test "test 4: set close with set_target_points=60 passes through correctly" do
    @tm.data["bk2_state"]["set_target_points"] = 60
    @tm.data["bk2_state"]["set_scores"]["1"]["playera"] = 58
    @tm.save!

    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 3)
    )

    state = bk2_state
    assert state["set_scores"]["1"]["playera"] >= 60
    assert_equal 1, state["sets_won"]["playera"]
    assert_equal 2, state["current_set_number"]
  end

  # ---------------------------------------------------------------------------
  # Test 5: Set close with configurable target 70
  # ---------------------------------------------------------------------------

  test "test 5: set close with set_target_points=70 passes through correctly" do
    @tm.data["bk2_state"]["set_target_points"] = 70
    @tm.data["bk2_state"]["set_scores"]["1"]["playera"] = 68
    @tm.save!

    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 3)
    )

    state = bk2_state
    assert state["set_scores"]["1"]["playera"] >= 70
    assert_equal 1, state["sets_won"]["playera"]
    assert_equal 2, state["current_set_number"]
  end

  # ---------------------------------------------------------------------------
  # Test 6: Match close — playera wins 2-0
  # ---------------------------------------------------------------------------

  test "test 6: sets_won = {playera: 1, playerb: 0}, shot closes set 2 → match_finished=true, match_winner=playera" do
    @tm.data["bk2_state"]["sets_won"] = {"playera" => 1, "playerb" => 0}
    @tm.data["bk2_state"]["current_set_number"] = 2
    @tm.data["bk2_state"]["set_scores"]["2"]["playera"] = 47
    @tm.save!

    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 5)
    )

    state = bk2_state
    assert_equal 2, state["sets_won"]["playera"]
    assert_equal 0, state["sets_won"]["playerb"]
    assert_equal true, state["match_finished"]
    assert_equal "playera", state["match_winner"]
  end

  # ---------------------------------------------------------------------------
  # Test 7: 1-1 split → third set plays to 2-1
  # ---------------------------------------------------------------------------

  test "test 7: 1-1 set split, third set closes for playera → match_finished=true at 2-1" do
    @tm.data["bk2_state"]["sets_won"] = {"playera" => 1, "playerb" => 1}
    @tm.data["bk2_state"]["current_set_number"] = 3
    @tm.data["bk2_state"]["set_scores"]["3"]["playera"] = 47
    @tm.save!

    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 5)
    )

    state = bk2_state
    assert_equal 2, state["sets_won"]["playera"]
    assert_equal 1, state["sets_won"]["playerb"]
    assert_equal true, state["match_finished"]
    assert_equal "playera", state["match_winner"]
  end

  # ---------------------------------------------------------------------------
  # Test 8: playerb closes set 2 → 1-1, no match close
  # ---------------------------------------------------------------------------

  test "test 8: 1-0 and playerb closes set 2 → 1-1, match_finished is nil or false, current_set_number=3" do
    @tm.data["bk2_state"]["sets_won"] = {"playera" => 1, "playerb" => 0}
    @tm.data["bk2_state"]["current_set_number"] = 2
    @tm.data["bk2_state"]["player_at_table"] = "playerb"
    @tm.data["bk2_state"]["set_scores"]["2"]["playerb"] = 47
    @tm.save!

    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 5)
    )

    state = bk2_state
    assert_equal 1, state["sets_won"]["playera"]
    assert_equal 1, state["sets_won"]["playerb"]
    assert_not state["match_finished"], "match should NOT be finished at 1-1"
    assert_equal 3, state["current_set_number"]
  end

  # ---------------------------------------------------------------------------
  # Test 9: Persistence — reload confirms state persisted
  # ---------------------------------------------------------------------------

  test "test 9: after AdvanceMatchState.call, tm.reload.data['bk2_state'] reflects the update" do
    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 4)
    )

    fresh_state = @tm.reload.data["bk2_state"]
    assert_equal 4, fresh_state["set_scores"]["1"]["playera"],
      "Persisted state must reflect the 4-pin score"
  end

  # ---------------------------------------------------------------------------
  # Test 10: Initialization path — bk2_state nil
  # ---------------------------------------------------------------------------

  test "test 10: call with bk2_state=nil initializes fresh state before applying shot" do
    @tm.data = {
      "free_game_form" => "bk2_kombi",
      "current_kickoff_player" => "playera"
    }
    @tm.save!

    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 3)
    )

    state = bk2_state
    assert_not_nil state, "bk2_state must be initialized"
    assert_equal 1, state["current_set_number"]
    assert_equal "direkter_zweikampf", state["current_phase"]
    assert_equal "playera", state["player_at_table"]
    assert_equal 50, state["set_target_points"]
    assert_equal 3, state["set_scores"]["1"]["playera"]
  end

  # ---------------------------------------------------------------------------
  # Test 11: Idempotency — same shot_sequence_number is a no-op
  # ---------------------------------------------------------------------------

  test "test 11: same shot_sequence_number submitted twice → second call is no-op" do
    shot = pin_shot(fallen_pins: 5).merge(shot_sequence_number: "abc-001")

    Bk2Kombi::AdvanceMatchState.call(table_monitor: @tm, shot_payload: shot)
    state_after_first = @tm.reload.data["bk2_state"]["set_scores"]["1"]["playera"]

    result = Bk2Kombi::AdvanceMatchState.call(table_monitor: @tm, shot_payload: shot)

    assert_equal state_after_first, @tm.reload.data["bk2_state"]["set_scores"]["1"]["playera"],
      "Second call with same sequence number must be a no-op"
    assert result[:idempotent_noop], "Result must indicate idempotent no-op"
  end
end
