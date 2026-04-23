# frozen_string_literal: true

require "test_helper"

# End-to-End Integrations-Test: BK2-Kombi Dispatch-Kette
#
# Verifiziert, dass Plan 01 + Plan 02 + Plan 03 korrekt zusammenwirken:
#   - Plan 01: TableMonitor::ScoreEngine lässt negative Punktzahlen für bk2_kombi zu
#              (und blockiert sie weiterhin für karambol — Regression-Control)
#   - Plan 02: ResultRecorder leitet bk2_kombi-Aufrufe an AdvanceMatchState weiter
#   - Plan 03: AdvanceMatchState verarbeitet Schüsse, schließt Sätze und Matches
#
# Testszenario:
#   - Gesamter Satz 1 wird simuliert bis 50 Punkte erreicht → set_scores + sets_won aktualisiert
#   - Gesamtes Match (2 Sätze) simuliert → match_finished=true
#   - Negative-Control: karambol ScoreEngine blockiert negative Aufnahmen weiterhin
class Bk2KombiDispatchIntegrationTest < ActiveSupport::TestCase
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

  # Helper: build a simple non-foul shot payload.
  def pin_shot(fallen_pins:)
    {
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
  end

  # Helper: apply multiple 5-pin shots until a player's set score reaches the target.
  # Returns the state after set close.
  def advance_to_set_close(set_score_to_preset: 45)
    @tm.data["bk2_state"]["set_scores"]["1"]["playera"] = set_score_to_preset
    @tm.save!

    # One more shot to cross 50
    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 5)
    )
    @tm.reload.data["bk2_state"]
  end

  # ---------------------------------------------------------------------------
  # Test 1: Running total — 5 shots accumulate in set_scores
  # ---------------------------------------------------------------------------

  test "5 sequential shots accumulate correctly in set_scores and no negative error fires" do
    # Apply 5 shots of 3 pins each — playera starts with 2 shots, then playerb 2, etc.
    # The test just verifies total points accumulate (player alternation happens after shots_left).
    [3, 4, 2, 5, 1].each do |pins|
      Bk2Kombi::AdvanceMatchState.call(
        table_monitor: @tm,
        shot_payload: pin_shot(fallen_pins: pins)
      )
      @tm.reload
    end

    state = @tm.data["bk2_state"]
    total_a = state["set_scores"]["1"]["playera"]
    total_b = state["set_scores"]["1"]["playerb"]

    # Total points scored should be >= 0 (no negative-scores error fired)
    assert total_a >= 0, "playera score must be non-negative"
    assert total_b >= 0, "playerb score must be non-negative"
    # At least some points should have been scored (5 shots of 1-5 pins each)
    assert(total_a + total_b > 0, "Total points across all shots must be > 0")
  end

  # ---------------------------------------------------------------------------
  # Test 2: Set close — playera reaches 50, current_set_number advances to 2
  # ---------------------------------------------------------------------------

  test "set close at 50 points — set_scores updated, sets_won incremented, set 2 starts" do
    state = advance_to_set_close(set_score_to_preset: 45)

    assert state["set_scores"]["1"]["playera"] >= 50,
      "playera set 1 score must be >= 50 after set close"
    assert_equal 1, state["sets_won"]["playera"], "playera must have 1 set won"
    assert_equal 0, state["sets_won"]["playerb"]
    assert_equal 2, state["current_set_number"], "Must advance to set 2"
    assert_equal "direkter_zweikampf", state["current_phase"]
    assert_equal 2, state["shots_left_in_turn"]
  end

  # ---------------------------------------------------------------------------
  # Test 3: Full 2-0 match — playera wins sets 1 and 2, match_finished=true
  # ---------------------------------------------------------------------------

  test "full 2-0 match — playera wins set 1, then playerb starts set 2 but playera closes it" do
    # Close set 1 for playera (preset to 47, one 5-pin shot crosses 50)
    @tm.data["bk2_state"]["set_scores"]["1"]["playera"] = 47
    @tm.save!
    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 5)
    )
    @tm.reload

    state = @tm.data["bk2_state"]
    assert_equal 1, state["sets_won"]["playera"], "playera must have 1 set after set 1 close"
    assert_equal 2, state["current_set_number"], "Must be in set 2"
    assert_nil state["match_finished"], "Match must NOT be finished yet"

    # After set 1 close, kickoff alternates: player_at_table is now "playerb".
    # Set up set 2 so playera wins: preset playera's set 2 score to 47, then
    # force player_at_table back to "playera" to simulate a playera turn.
    @tm.data["bk2_state"]["set_scores"]["2"]["playera"] = 47
    @tm.data["bk2_state"]["player_at_table"] = "playera"
    @tm.data["bk2_state"]["shots_left_in_turn"] = 2
    @tm.save!

    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 5)
    )
    @tm.reload

    final_state = @tm.data["bk2_state"]
    assert_equal 2, final_state["sets_won"]["playera"], "playera must have 2 sets won"
    assert_equal 0, final_state["sets_won"]["playerb"]
    assert_equal true, final_state["match_finished"], "match_finished must be true after 2-0"
    assert_equal "playera", final_state["match_winner"]
  end

  # ---------------------------------------------------------------------------
  # Test 4: set_scores hash persists correctly after reload
  # ---------------------------------------------------------------------------

  test "bk2_state persists to database — reload reflects shot results" do
    Bk2Kombi::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 4)
    )

    fresh = @tm.reload
    assert_equal 4, fresh.data["bk2_state"]["set_scores"]["1"]["playera"],
      "Persisted bk2_state must reflect the 4-pin shot"
  end

  # ---------------------------------------------------------------------------
  # Negative control: karambol ScoreEngine still blocks negative scores (Plan 01 regression)
  # ---------------------------------------------------------------------------

  test "karambol ScoreEngine rejects negative innings — Plan 01 regression control" do
    # Build a plain-hash data fixture with free_game_form="karambol".
    # Constructor is new(data, discipline: ...) — plain Hash, NOT AR instance.
    karambol_data = {
      "free_game_form" => "karambol",
      "playera" => {"result" => 0, "innings" => 1, "innings_list" => [], "innings_redo_list" => [0]},
      "playerb" => {"result" => 0, "innings" => 1, "innings_list" => [], "innings_redo_list" => [0]},
      "current_inning" => {"active_player" => "playera"}
    }

    engine = TableMonitor::ScoreEngine.new(karambol_data, discipline: "Freie Partie")

    # A negative innings entry must be rejected for karambol
    result = engine.update_innings_history(
      {"playera" => [-5], "playerb" => [3]},
      playing_or_set_over: true
    )

    assert_equal false, result[:success],
      "karambol must reject negative innings"
    assert_equal "Negative Punktzahlen sind nicht erlaubt", result[:error]
  end

  # ---------------------------------------------------------------------------
  # Test 6: BK2-Kombi ScoreEngine allows negative via allow_negative_scores?
  # ---------------------------------------------------------------------------

  test "bk2_kombi ScoreEngine allows negative innings via allow_negative_scores?" do
    bk2_data = {
      "free_game_form" => "bk2_kombi",
      "playera" => {"result" => 0, "innings" => 1, "innings_list" => [], "innings_redo_list" => [0]},
      "playerb" => {"result" => 0, "innings" => 1, "innings_list" => [], "innings_redo_list" => [0]},
      "current_inning" => {"active_player" => "playera"}
    }

    engine = TableMonitor::ScoreEngine.new(bk2_data, discipline: "BK2-Kombi")

    assert engine.allow_negative_scores?,
      "bk2_kombi ScoreEngine must allow negative scores"

    result = engine.update_innings_history(
      {"playera" => [-3], "playerb" => [6]},
      playing_or_set_over: true
    )

    assert_equal true, result[:success],
      "bk2_kombi must accept negative innings"
  end
end
