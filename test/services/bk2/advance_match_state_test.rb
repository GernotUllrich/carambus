# frozen_string_literal: true

require "test_helper"

# State-Mutations-Tests fuer Bk2::AdvanceMatchState.
#
# Verifiziert: Grundlegende Zustandsaktualisierung, Satzende, Matchende,
# Persistenz via tm.save!, Initialisierungspfad bei nil-State und
# Idempotenz-Guard (shot_sequence_number).
#
# Phase 38.4 D-06: balls_goal-basierte Satz-Schlusskontrolle + init-Fallback-Tests.
#
# Alle Tests verwenden in der Datenbank gespeicherte TableMonitor-Datensaetze.
class Bk2::AdvanceMatchStateTest < ActiveSupport::TestCase
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
          "set_target_points" => 50,
          "balls_goal" => 50
        }
      }
    )
  end

  # Helper to build a simple non-foul shot payload.
  def pin_shot(fallen_pins:, player_at_table: nil)
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
    Bk2::AdvanceMatchState.call(
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
    Bk2::AdvanceMatchState.call(
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

    Bk2::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 5)
    )

    state = bk2_state
    assert state["set_scores"]["1"]["playera"] >= 50, "playera should have >= 50 points"
    assert_equal 1, state["sets_won"]["playera"], "playera wins set 1"
    assert_equal 0, state["sets_won"]["playerb"]
    assert_equal 2, state["current_set_number"], "Should advance to set 2"
    # Phase 38.2 D-14: Satz 2 flips from first_set_mode. The setup fixture has no
    # bk2_options, so derive_first_set_mode defaults to 'direkter_zweikampf',
    # and Satz 2 must flip to 'serienspiel'. The pre-seeded bk2_state also has
    # no first_set_mode key, but close_set_if_reached! falls back to derive_first_set_mode.
    assert_equal "serienspiel", state["current_phase"],
      "Phase 38.2 D-14: Satz 2 flips to serienspiel when first_set_mode defaults to direkter_zweikampf"
    # SP set: shots_left_in_turn is reset to 0 (SP does not use per-shot counter).
    assert_equal 0, state["shots_left_in_turn"], "SP phase has shots_left_in_turn = 0"
    assert_equal Bk2::AdvanceMatchState::DEFAULT_SP_MAX_INNINGS_PER_SET,
      state["innings_left_in_set"],
      "New SP set seeds innings_left_in_set from default (5)"
  end

  # ---------------------------------------------------------------------------
  # Test 4: Set close with configurable target 60 (via state['balls_goal'])
  # ---------------------------------------------------------------------------

  test "test 4: set close with balls_goal=60 passes through correctly" do
    @tm.data["bk2_state"]["balls_goal"] = 60
    @tm.data["bk2_state"]["set_target_points"] = 60
    @tm.data["bk2_state"]["set_scores"]["1"]["playera"] = 58
    @tm.save!

    Bk2::AdvanceMatchState.call(
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

  test "test 5: set close with balls_goal=70 passes through correctly" do
    @tm.data["bk2_state"]["balls_goal"] = 70
    @tm.data["bk2_state"]["set_target_points"] = 70
    @tm.data["bk2_state"]["set_scores"]["1"]["playera"] = 68
    @tm.save!

    Bk2::AdvanceMatchState.call(
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

    Bk2::AdvanceMatchState.call(
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

    Bk2::AdvanceMatchState.call(
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

    Bk2::AdvanceMatchState.call(
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
    Bk2::AdvanceMatchState.call(
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

    Bk2::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 3)
    )

    state = bk2_state
    assert_not_nil state, "bk2_state must be initialized"
    assert_equal 1, state["current_set_number"]
    assert_equal "direkter_zweikampf", state["current_phase"]
    assert_equal "playera", state["player_at_table"]
    # Phase 38.4 D-06: new state uses balls_goal (set_target_points kept for compat)
    assert_equal 50, state["balls_goal"]
    assert_equal 3, state["set_scores"]["1"]["playera"]
  end

  # ---------------------------------------------------------------------------
  # Test 11: Idempotency — same shot_sequence_number is a no-op
  # ---------------------------------------------------------------------------

  test "test 11: same shot_sequence_number submitted twice → second call is no-op" do
    shot = pin_shot(fallen_pins: 5).merge(shot_sequence_number: "abc-001")

    Bk2::AdvanceMatchState.call(table_monitor: @tm, shot_payload: shot)
    state_after_first = @tm.reload.data["bk2_state"]["set_scores"]["1"]["playera"]

    result = Bk2::AdvanceMatchState.call(table_monitor: @tm, shot_payload: shot)

    assert_equal state_after_first, @tm.reload.data["bk2_state"]["set_scores"]["1"]["playera"],
      "Second call with same sequence number must be a no-op"
    assert result[:idempotent_noop], "Result must indicate idempotent no-op"
  end

  # ===========================================================================
  # Phase 38.2 Plan 01 — bk2_options-driven init + phase-flip across sets
  # ===========================================================================

  # Helper: create a fresh TableMonitor with bk2_options but no bk2_state yet,
  # so init_state_if_missing! runs with the configured options.
  def fresh_bk2_tm(bk2_options)
    TableMonitor.create!(
      state: "playing",
      data: {
        "free_game_form" => "bk2_kombi",
        "current_kickoff_player" => "playera",
        "bk2_options" => bk2_options
      }
    )
  end

  test "38.2-01 T1: init seeds shots_left_in_turn from bk2_options.direkter_zweikampf_max_shots_per_turn (DZ first)" do
    tm = fresh_bk2_tm(
      "set_target_points" => 50,
      "direkter_zweikampf_max_shots_per_turn" => 3,
      "first_set_mode" => "direkter_zweikampf"
    )

    Bk2::AdvanceMatchState.call(
      table_monitor: tm,
      shot_payload: pin_shot(fallen_pins: 0)
    )

    state = tm.reload.data["bk2_state"]
    # 3 seeded - 1 (non-bonus shot consumes one) = 2
    assert_equal 2, state["shots_left_in_turn"],
      "shots_left_in_turn must be seeded from bk2_options (3) and decremented by 1 after the first shot"
    assert_equal "direkter_zweikampf", state["current_phase"]
    assert_equal "direkter_zweikampf", state["first_set_mode"]
  end

  test "38.2-01 T2: init seeds innings_left_in_set from bk2_options.serienspiel_max_innings_per_set (SP first)" do
    tm = fresh_bk2_tm(
      "set_target_points" => 50,
      "serienspiel_max_innings_per_set" => 7,
      "first_set_mode" => "serienspiel"
    )

    # Non-turn-ending shot (positive score) leaves innings_left_in_set at seeded value.
    Bk2::AdvanceMatchState.call(
      table_monitor: tm,
      shot_payload: pin_shot(fallen_pins: 2)
    )

    state = tm.reload.data["bk2_state"]
    assert_equal 7, state["innings_left_in_set"],
      "innings_left_in_set must be seeded from bk2_options (7) and remain 7 on a non-turn-ending SP shot"
    assert_equal "serienspiel", state["current_phase"]
    assert_equal "serienspiel", state["first_set_mode"]
  end

  test "38.2-01 T3: phase_for_set — set 1/3 match first_set_mode, set 2 is flipped" do
    tm = fresh_bk2_tm(
      "set_target_points" => 50,
      "first_set_mode" => "direkter_zweikampf"
    )
    svc = Bk2::AdvanceMatchState.new(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 0))

    assert_equal "direkter_zweikampf", svc.send(:phase_for_set, 1, "direkter_zweikampf")
    assert_equal "serienspiel", svc.send(:phase_for_set, 2, "direkter_zweikampf")
    assert_equal "direkter_zweikampf", svc.send(:phase_for_set, 3, "direkter_zweikampf")

    assert_equal "serienspiel", svc.send(:phase_for_set, 1, "serienspiel")
    assert_equal "direkter_zweikampf", svc.send(:phase_for_set, 2, "serienspiel")
    assert_equal "serienspiel", svc.send(:phase_for_set, 3, "serienspiel")
  end

  test "38.2-01 T4: close_set advances with phase flip and correct counter reset (DZ-first → SP set 2)" do
    tm = fresh_bk2_tm(
      "set_target_points" => 50,
      "direkter_zweikampf_max_shots_per_turn" => 2,
      "serienspiel_max_innings_per_set" => 5,
      "first_set_mode" => "direkter_zweikampf"
    )
    # Initialise state, then bring player A to 47 and close the set with a 5-pin.
    Bk2::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 0))
    tm.data["bk2_state"]["set_scores"]["1"]["playera"] = 47
    tm.save!
    Bk2::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 5))

    state = tm.reload.data["bk2_state"]
    assert_equal 2, state["current_set_number"]
    assert_equal "serienspiel", state["current_phase"], "Set 2 phase must flip to serienspiel"
    assert_equal 5, state["innings_left_in_set"], "New SP set resets innings_left_in_set"
    assert_equal 0, state["shots_left_in_turn"], "SP set leaves shots_left_in_turn at 0"
  end

  test "38.2-01 T4b: close_set with SP-first → DZ set 2 resets shots_left_in_turn, innings_left_in_set=0" do
    tm = fresh_bk2_tm(
      "set_target_points" => 50,
      "direkter_zweikampf_max_shots_per_turn" => 2,
      "serienspiel_max_innings_per_set" => 5,
      "first_set_mode" => "serienspiel"
    )
    # Initialise via a non-turn-ending SP shot (+2 for playera, turn stays).
    Bk2::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 2))
    # Bring playera to the brink of the set target while still at table.
    tm.data["bk2_state"]["set_scores"]["1"]["playera"] = 47
    tm.save!
    # A 5-pin SP shot by playera pushes to 52 → set 1 closes.
    Bk2::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 5))

    state = tm.reload.data["bk2_state"]
    assert_equal 2, state["current_set_number"], "set 1 must close, advance to set 2"
    assert_equal "direkter_zweikampf", state["current_phase"],
      "Set 2 phase flips from SP (set 1) to DZ"
    assert_equal 2, state["shots_left_in_turn"],
      "New DZ set resets shots_left_in_turn to dz_max (2)"
    assert_equal 0, state["innings_left_in_set"],
      "DZ set has innings_left_in_set = 0"
  end

  test "38.2-01 T5: apply_transitions decrements innings_left_in_set on turn_ends in Serienspiel" do
    tm = fresh_bk2_tm(
      "set_target_points" => 50,
      "serienspiel_max_innings_per_set" => 5,
      "first_set_mode" => "serienspiel"
    )
    # Initialise via a non-turn-ending shot.
    Bk2::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 2))
    assert_equal 5, tm.reload.data["bk2_state"]["innings_left_in_set"]

    # Turn-ending shot: foul in SP ends the Aufnahme → innings_left decrements.
    Bk2::AdvanceMatchState.call(table_monitor: tm, shot_payload: foul_shot(foul_code: :wrong_ball))

    state = tm.reload.data["bk2_state"]
    assert_equal 4, state["innings_left_in_set"],
      "innings_left_in_set must decrement from 5 → 4 on turn_ends in SP"
  end

  test "38.2-01 T5b: apply_transitions with zero-point non-foul in SP also ends turn → innings decrements" do
    tm = fresh_bk2_tm(
      "set_target_points" => 50,
      "serienspiel_max_innings_per_set" => 5,
      "first_set_mode" => "serienspiel"
    )
    Bk2::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 2))
    assert_equal 5, tm.reload.data["bk2_state"]["innings_left_in_set"]

    # Zero-pin non-foul shot in SP ends the Aufnahme per ScoreShot.calculate_serienspiel_transitions.
    Bk2::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 0))

    state = tm.reload.data["bk2_state"]
    assert_equal 4, state["innings_left_in_set"]
  end

  test "38.2-01 T6: apply_transitions does not touch innings_left_in_set in direkter_zweikampf" do
    tm = fresh_bk2_tm(
      "set_target_points" => 50,
      "direkter_zweikampf_max_shots_per_turn" => 2,
      "first_set_mode" => "direkter_zweikampf"
    )
    Bk2::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 0))
    state = tm.reload.data["bk2_state"]
    assert_equal 0, state["innings_left_in_set"]

    Bk2::AdvanceMatchState.call(table_monitor: tm, shot_payload: foul_shot(foul_code: :wrong_ball))
    state = tm.reload.data["bk2_state"]
    assert_equal 0, state["innings_left_in_set"], "DZ phase must not touch innings_left_in_set"
  end

  test "38.2-01 T7: defaults apply when bk2_options is empty" do
    tm = TableMonitor.create!(
      state: "playing",
      data: {
        "free_game_form" => "bk2_kombi",
        "current_kickoff_player" => "playera",
        "bk2_options" => {}
      }
    )

    Bk2::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 0))

    state = tm.reload.data["bk2_state"]
    assert_equal "direkter_zweikampf", state["current_phase"],
      "Default first_set_mode and set-1 phase is direkter_zweikampf"
    assert_equal "direkter_zweikampf", state["first_set_mode"]
    # Phase 38.4 D-06: new state uses balls_goal
    assert_equal 50, state["balls_goal"]
    # Default DZ max shots = 2, one shot consumed → shots_left_in_turn = 1.
    assert_equal 1, state["shots_left_in_turn"]
    assert_equal 0, state["innings_left_in_set"], "innings_left_in_set is 0 while in DZ phase"
  end

  test "38.2-01 T8: invalid first_set_mode in bk2_options falls back to direkter_zweikampf" do
    tm = fresh_bk2_tm(
      "set_target_points" => 50,
      "first_set_mode" => "attacker_injected_value"
    )

    Bk2::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 0))

    state = tm.reload.data["bk2_state"]
    assert_equal "direkter_zweikampf", state["first_set_mode"]
    assert_equal "direkter_zweikampf", state["current_phase"]
  end

  # --- Phase 38.3-08 I6: initialize_bk2_state! public entry-point -------------

  test "38.3-08 T1: initialize_bk2_state! populates bk2_state on a fresh TableMonitor" do
    @tm.update!(data: {
      "free_game_form" => "bk2_kombi",
      "current_kickoff_player" => "playera",
      "bk2_options" => {
        "first_set_mode" => "direkter_zweikampf",
        "set_target_points" => 50,
        "direkter_zweikampf_max_shots_per_turn" => 2,
        "serienspiel_max_innings_per_set" => 5
      }
    })

    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    @tm.reload
    state = @tm.data["bk2_state"]

    assert_equal "direkter_zweikampf", state["current_phase"]
    assert_equal 1, state["current_set_number"]
    assert_equal 2, state["shots_left_in_turn"]
    assert_equal 0, state["innings_left_in_set"]
    # Phase 38.4 D-06: balls_goal is the new per-set target key
    assert_equal 50, state["balls_goal"]
    assert_equal({"playera" => 0, "playerb" => 0}, state["set_scores"]["1"])
    assert_equal({"playera" => 0, "playerb" => 0}, state["set_scores"]["2"])
    assert_equal({"playera" => 0, "playerb" => 0}, state["set_scores"]["3"])
    assert_equal({"playera" => 0, "playerb" => 0}, state["sets_won"])
    assert_equal "playera", state["player_at_table"]
    refute @tm.bk2_state_uninitialized?, "predicate must return false after init"
  end

  test "38.3-08 T2: initialize_bk2_state! honors first_set_mode=serienspiel with SP counters" do
    @tm.update!(data: {
      "free_game_form" => "bk2_kombi",
      "current_kickoff_player" => "playerb",
      "bk2_options" => {
        "first_set_mode" => "serienspiel",
        "set_target_points" => 70,
        "direkter_zweikampf_max_shots_per_turn" => 3,
        "serienspiel_max_innings_per_set" => 7
      }
    })

    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    @tm.reload
    state = @tm.data["bk2_state"]

    assert_equal "serienspiel", state["current_phase"]
    assert_equal 0, state["shots_left_in_turn"]
    assert_equal 7, state["innings_left_in_set"]
    assert_equal 70, state["balls_goal"]
    assert_equal "playerb", state["player_at_table"]
  end

  test "38.3-08 T3: initialize_bk2_state! is idempotent when bk2_state already exists" do
    @tm.update!(data: {
      "free_game_form" => "bk2_kombi",
      "bk2_options" => {"first_set_mode" => "direkter_zweikampf"},
      "bk2_state" => {
        "current_set_number" => 2,
        "current_phase" => "serienspiel",
        "first_set_mode" => "direkter_zweikampf",
        "player_at_table" => "playerb",
        "shots_left_in_turn" => 0,
        "innings_left_in_set" => 3,
        "set_scores" => {
          "1" => {"playera" => 50, "playerb" => 42},
          "2" => {"playera" => 17, "playerb" => 25},
          "3" => {"playera" => 0, "playerb" => 0}
        },
        "sets_won" => {"playera" => 1, "playerb" => 0},
        "set_target_points" => 50,
        "balls_goal" => 50
      }
    })

    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    @tm.reload
    state = @tm.data["bk2_state"]

    # All mid-match values preserved — init was a no-op
    assert_equal 2, state["current_set_number"]
    assert_equal "serienspiel", state["current_phase"]
    assert_equal 50, state["set_scores"]["1"]["playera"]
    assert_equal 1, state["sets_won"]["playera"]
  end

  test "38.3-08 T4: initialize_bk2_state! falls back to DEFAULT_FIRST_SET_MODE when bk2_options.first_set_mode is missing (covers key_d path)" do
    @tm.update!(data: {
      "free_game_form" => "bk2_kombi",
      "bk2_options" => {}  # no first_set_mode set — simulates the key_d keyboard path
    })

    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    @tm.reload
    state = @tm.data["bk2_state"]

    # derive_first_set_mode returns DEFAULT_FIRST_SET_MODE ("direkter_zweikampf")
    assert_equal "direkter_zweikampf", state["current_phase"]
    assert_equal Bk2::AdvanceMatchState::DEFAULT_DZ_MAX_SHOTS_PER_TURN, state["shots_left_in_turn"]
    assert_equal 0, state["innings_left_in_set"]
    refute @tm.bk2_state_uninitialized?, "predicate must return false after init (default-mode path)"
  end

  # ===========================================================================
  # Phase 38.4 D-06: balls_goal-based state init and close_set fallback tests
  # ===========================================================================

  test "38.4-06 init_state_if_missing! reads balls_goal from tournament_monitor, writes state['balls_goal']" do
    # Create a TournamentMonitor with balls_goal=60 and attach it to the TableMonitor.
    tm_with_tournament = TableMonitor.create!(
      state: "playing",
      data: {
        "free_game_form" => "bk2_kombi",
        "current_kickoff_player" => "playera",
        "bk2_options" => {}
      }
    )
    # Stub tournament_monitor.balls_goal = 60.
    # OpenStruct responds to arbitrary methods with nil, avoiding NoMethodError in OptionsPresenter.
    tournament_monitor_double = OpenStruct.new(balls_goal: 60) # rubocop:disable Style/OpenStructUse
    tm_with_tournament.define_singleton_method(:tournament_monitor) { tournament_monitor_double }

    Bk2::AdvanceMatchState.initialize_bk2_state!(tm_with_tournament)
    state = tm_with_tournament.reload.data["bk2_state"]

    assert_equal 60, state["balls_goal"],
      "init_state_if_missing! must write balls_goal from tournament_monitor.balls_goal"
  end

  test "38.4-06 init_state_if_missing! falls back to bk2_options[:set_target_points] if tournament_monitor.balls_goal is nil/zero" do
    tm_no_tm = TableMonitor.create!(
      state: "playing",
      data: {
        "free_game_form" => "bk2_kombi",
        "current_kickoff_player" => "playera",
        "bk2_options" => {"set_target_points" => 70}
      }
    )
    # tournament_monitor.balls_goal = 0 → falls back to bk2_options.
    tournament_monitor_zero = OpenStruct.new(balls_goal: 0) # rubocop:disable Style/OpenStructUse
    tm_no_tm.define_singleton_method(:tournament_monitor) { tournament_monitor_zero }

    Bk2::AdvanceMatchState.initialize_bk2_state!(tm_no_tm)
    state = tm_no_tm.reload.data["bk2_state"]

    assert_equal 70, state["balls_goal"],
      "balls_goal must fall back to bk2_options[:set_target_points]=70 when tournament_monitor.balls_goal is 0"
  end

  test "38.4-06 close_set_if_reached! reads state['balls_goal'] to close the set" do
    state_data = {
      "current_set_number" => 1,
      "current_phase" => "serienspiel",
      "first_set_mode" => "direkter_zweikampf",
      "player_at_table" => "playera",
      "shots_left_in_turn" => 0,
      "innings_left_in_set" => 5,
      "set_scores" => {
        "1" => {"playera" => 48, "playerb" => 0},
        "2" => {"playera" => 0, "playerb" => 0},
        "3" => {"playera" => 0, "playerb" => 0}
      },
      "sets_won" => {"playera" => 0, "playerb" => 0},
      "balls_goal" => 50
      # Note: no set_target_points key — balls_goal is the only target
    }
    @tm.update!(data: @tm.data.merge("bk2_state" => state_data))

    Bk2::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 3)
    )

    s = @tm.reload.data["bk2_state"]
    assert s["set_scores"]["1"]["playera"] >= 50, "playera must reach balls_goal"
    assert_equal true, s["set_finished_1"], "set must close when balls_goal reached"
  end

  test "38.4-06 close_set_if_reached! falls back to state['set_target_points'] if balls_goal missing (legacy in-flight)" do
    # Legacy in-flight state: has set_target_points but no balls_goal
    state_data = {
      "current_set_number" => 1,
      "current_phase" => "direkter_zweikampf",
      "first_set_mode" => "direkter_zweikampf",
      "player_at_table" => "playera",
      "shots_left_in_turn" => 2,
      "innings_left_in_set" => 0,
      "set_scores" => {
        "1" => {"playera" => 47, "playerb" => 0},
        "2" => {"playera" => 0, "playerb" => 0},
        "3" => {"playera" => 0, "playerb" => 0}
      },
      "sets_won" => {"playera" => 0, "playerb" => 0},
      "set_target_points" => 50
      # balls_goal deliberately absent — simulates legacy in-flight game
    }
    @tm.update!(data: @tm.data.merge("bk2_state" => state_data))

    Bk2::AdvanceMatchState.call(
      table_monitor: @tm,
      shot_payload: pin_shot(fallen_pins: 5)
    )

    s = @tm.reload.data["bk2_state"]
    assert s["set_scores"]["1"]["playera"] >= 50, "playera must reach set_target_points (fallback)"
    assert_equal true, s["set_finished_1"],
      "set must still close via legacy set_target_points fallback (T-38.4-05-02)"
  end

  # ===========================================================================
  # Phase 38.4-11 O2+O4: Nachstoß deferred-close logic
  # ===========================================================================

  # Phase 38.4-16 P5: BK50 narrowed to NO Nachstoß per user clarification.
  # Reframes T-O2-bk50-nachstoss-defers-close (Plan 11) — assertions FLIPPED.
  test "T-P5-bk50-no-nachstoss 38.4-16: BK50 set CLOSES immediately when leader reaches 50; no Nachstoß" do
    bk50 = ensure_bk_discipline("BK50", "bk50", [50], nachstoss_allowed: false)
    tm = build_table_monitor_with_discipline(bk50, balls_goal: 50, free_game_form: "bk50")
    Bk2::AdvanceMatchState.initialize_bk2_state!(tm)

    Bk2::CommitInning.call(table_monitor: tm, player: "playera", inning_total: 50)
    tm.reload
    state = tm.data["bk2_state"]

    assert_equal 1, state.dig("sets_won", "playera"),
      "T-P5-bk50: leader's set-win MUST increment immediately when nachstoss_allowed=false (P5 narrowing)"
    assert_equal true, state["set_finished_1"],
      "T-P5-bk50: set_finished_1 must be true after immediate close"
    assert_nil state["nachstoss_pending"],
      "T-P5-bk50: nachstoss_pending MUST be nil/absent — BK50 no longer engages Nachstoß per P5"
  end

  # Phase 38.4-16 P5: BK50 narrowed to immediate-close per user clarification.
  # Replaces T-O4-nachstoss-equal-resolves-set + T-O4-nachstoss-below-leader-wins
  # (Plan 11) — there is no longer an equal-vs-below distinction for BK50 because
  # there is no Nachstoß window.
  test "T-P5-bk50-immediate-close-at-50 38.4-16: BK50 single-inning close at balls_goal — no equalizer" do
    bk50 = ensure_bk_discipline("BK50", "bk50", [50], nachstoss_allowed: false)
    tm = build_table_monitor_with_discipline(bk50, balls_goal: 50, free_game_form: "bk50")
    Bk2::AdvanceMatchState.initialize_bk2_state!(tm)

    Bk2::CommitInning.call(table_monitor: tm, player: "playera", inning_total: 50)
    tm.reload
    state = tm.data["bk2_state"]

    assert_equal 50, state.dig("set_scores", "1", "playera"),
      "T-P5-bk50-immediate: leader's score is exactly 50"
    assert_equal true, state["set_finished_1"],
      "T-P5-bk50-immediate: set must close on the leader's reach — no equalizer for BK50"
    assert_equal 1, state.dig("sets_won", "playera"),
      "T-P5-bk50-immediate: leader (playera) wins the set immediately"
    assert_nil state["nachstoss_pending"],
      "T-P5-bk50-immediate: nachstoss_pending MUST be nil — BK50 has no Nachstoß per P5"
  end

  # Phase 38.4-16 P5: BK100 narrowed to NO Nachstoß per user clarification.
  # Reframes T-O2-bk100-nachstoss-defers-close (Plan 11) — assertions FLIPPED.
  test "T-P5-bk100-no-nachstoss 38.4-16: BK100 set CLOSES immediately at 100; no Nachstoß" do
    bk100 = ensure_bk_discipline("BK100", "bk100", [100], nachstoss_allowed: false)
    tm = build_table_monitor_with_discipline(bk100, balls_goal: 100, free_game_form: "bk100")
    Bk2::AdvanceMatchState.initialize_bk2_state!(tm)

    Bk2::CommitInning.call(table_monitor: tm, player: "playera", inning_total: 100)
    tm.reload
    state = tm.data["bk2_state"]

    assert_equal 1, state.dig("sets_won", "playera"),
      "T-P5-bk100: leader's set-win MUST increment immediately at balls_goal=100 (P5 narrowing)"
    assert_equal true, state["set_finished_1"],
      "T-P5-bk100: set_finished_1 must be true after immediate close"
    assert_nil state["nachstoss_pending"],
      "T-P5-bk100: nachstoss_pending MUST be nil/absent — BK100 no longer engages Nachstoß per P5"
  end

  # Phase 38.4-16 P5: this test was already correct under Plan 11 (no flag → immediate
  # close). After Plan 16's narrowing it now matches BK50/BK100/BK-2/BK-2plus production
  # semantics (these disciplines lose the flag, so they take this same code path).
  test "T-O2-no-nachstoss-flag-immediate-close 38.4-11: discipline without nachstoss_allowed closes set immediately (regression)" do
    legacy = ensure_bk_discipline("BK-Legacy-Test", "bk_legacy_test", [50], nachstoss_allowed: false)
    tm = build_table_monitor_with_discipline(legacy, balls_goal: 50, free_game_form: "bk_legacy_test")
    Bk2::AdvanceMatchState.initialize_bk2_state!(tm)
    tm.data["bk2_state"]["set_scores"]["1"]["playera"] = 50
    tm.save!
    advance = Bk2::AdvanceMatchState.new(table_monitor: tm, shot_payload: {})
    state = tm.data["bk2_state"].deep_dup
    advance.send(:close_set_if_reached!, state)

    assert_equal 1, state.dig("sets_won", "playera"),
      "T-O2-regression: discipline without nachstoss_allowed closes set immediately (legacy default)"
    assert_nil state["nachstoss_pending"],
      "T-O2-regression: nachstoss_pending must NOT be set when nachstoss_allowed=false"
  end

  # Phase 38.4-14 P4: TableMonitor#add_n_balls dispatches to Bk2::CommitInning for
  # BK-family-with-nachstoss disciplines. Without this, the legacy karambol
  # terminate_current_inning fires evaluate_result → AASM set_over, and Plan 11's
  # nachstoss_pending machinery is bypassed (the user's "kommt nur bis 49" symptom).
  # POST-Plan-16: BK-2kombi is the SOLE production discipline carrying nachstoss_allowed.
  # Option B (round-4 iteration-2): bk_family_with_nachstoss? reads the discipline NAME
  # from data['playera']['discipline'] (String) and looks up the AR record by name —
  # so we set the data['playera']['discipline'] String explicitly in test setup.
  test "T-P4-add-n-balls-routes-bk-family-through-bk2-commitinning 38.4-14" do
    bk2k = ensure_bk_discipline("BK2-Kombi-T-P4", "bk2_kombi", [50, 60, 70], nachstoss_allowed: true)
    tm = build_table_monitor_with_discipline(bk2k, balls_goal: 70, free_game_form: "bk2_kombi")
    # Suppress test-setup broadcast — fixture's empty data → seeded data produces a
    # malformed diff (`playera => [nil, {...}]`) that breaks the after_update_commit
    # ultra_fast_score_update? path. Production code never sees this transition because
    # data is built up incrementally; only test seeding triggers it. We re-enable
    # broadcast before the actual gameplay call so the dispatch path runs unmocked.
    tm.suppress_broadcast = true
    Bk2::AdvanceMatchState.initialize_bk2_state!(tm)

    # Seed leader playera with running total 69 in innings_redo_list; tap +1 to reach balls_goal=70.
    # to_play = balls_goal - (result + innings_redo_list[-1]) = 70 - (0 + 69) = 1
    # add_n_balls(1) → add == to_play → score_engine returns :goal_reached
    tm.data["balls_on_table"] = 15
    tm.data["balls_counter"] = 0
    tm.data["balls_counter_stack"] = []
    tm.data["playera"] ||= {}
    tm.data["playera"]["discipline"] = "BK2-Kombi-T-P4"  # Option B: name-based lookup
    tm.data["playera"]["balls_goal"] = 70
    tm.data["playera"]["result"] = 0
    tm.data["playera"]["innings"] = 1
    tm.data["playera"]["innings_redo_list"] = [69]
    tm.data["playera"]["innings_list"] = []
    tm.data["playera"]["innings_foul_list"] = []
    tm.data["playera"]["innings_foul_redo_list"] = [0]
    tm.data["playerb"] ||= {}
    tm.data["playerb"]["discipline"] = "BK2-Kombi-T-P4"
    tm.data["playerb"]["balls_goal"] = 70
    tm.data["playerb"]["result"] = 0
    tm.data["playerb"]["innings"] = 0
    tm.data["playerb"]["innings_redo_list"] = [0]
    tm.data["playerb"]["innings_list"] = []
    tm.data["playerb"]["innings_foul_list"] = []
    tm.data["playerb"]["innings_foul_redo_list"] = [0]
    tm.data["current_inning"] = {"active_player" => "playera"} unless tm.data["current_inning"].is_a?(Hash)
    tm.save!(validate: false)
    tm.suppress_broadcast = false
    tm.instance_variable_set(:@collected_data_changes, nil)
    tm.instance_variable_set(:@collected_changes, nil)

    tm.add_n_balls(1, "playera")
    tm.reload
    state = tm.data["bk2_state"]

    assert_equal true, state["nachstoss_pending"],
      "T-P4: add_n_balls(:goal_reached) MUST route through Bk2::CommitInning for BK-family-with-nachstoss; nachstoss_pending=true expected"
    assert_equal "playerb", state["player_at_table"],
      "T-P4: nachstoss_for/player_at_table must flip to playerb (trailing)"
    assert_nil state["set_finished_1"],
      "T-P4: set_finished_1 must NOT be set yet — Nachstoß defer holds the close until trailing equalizes"
    refute_equal "set_over", tm.state.to_s,
      "T-P4: TM.state must NOT have transitioned to set_over during Nachstoß defer"
  end

  # Phase 38.4-14 P4: end-to-end — leader reaches 70, trailing reaches 70 via add_n_balls.
  # Provisional rule per Plan 11 close_set_if_reached!:198-209: trailing >= target → trailing wins.
  test "T-P4-add-n-balls-bk2kombi-engages-nachstoss-on-leader-reach 38.4-14" do
    bk2k = ensure_bk_discipline("BK2-Kombi-T-P4-end2end", "bk2_kombi", [50, 60, 70], nachstoss_allowed: true)
    tm = build_table_monitor_with_discipline(bk2k, balls_goal: 70, free_game_form: "bk2_kombi")
    tm.suppress_broadcast = true
    Bk2::AdvanceMatchState.initialize_bk2_state!(tm)

    # Step 1: leader playera reaches 70.
    tm.data["balls_on_table"] = 15
    tm.data["balls_counter"] = 0
    tm.data["balls_counter_stack"] = []
    tm.data["playera"] ||= {}
    tm.data["playera"]["discipline"] = "BK2-Kombi-T-P4-end2end"  # Option B: name-based lookup
    tm.data["playera"]["balls_goal"] = 70
    tm.data["playera"]["result"] = 0
    tm.data["playera"]["innings"] = 1
    tm.data["playera"]["innings_redo_list"] = [69]
    tm.data["playera"]["innings_list"] = []
    tm.data["playera"]["innings_foul_list"] = []
    tm.data["playera"]["innings_foul_redo_list"] = [0]
    tm.data["playerb"] ||= {}
    tm.data["playerb"]["discipline"] = "BK2-Kombi-T-P4-end2end"
    tm.data["playerb"]["balls_goal"] = 70
    tm.data["playerb"]["result"] = 0
    tm.data["playerb"]["innings"] = 0
    tm.data["playerb"]["innings_redo_list"] = [69]
    tm.data["playerb"]["innings_list"] = []
    tm.data["playerb"]["innings_foul_list"] = []
    tm.data["playerb"]["innings_foul_redo_list"] = [0]
    tm.data["current_inning"] = {"active_player" => "playera"}
    tm.save!(validate: false)
    tm.suppress_broadcast = false
    tm.instance_variable_set(:@collected_data_changes, nil)
    tm.instance_variable_set(:@collected_changes, nil)
    tm.add_n_balls(1, "playera")
    tm.reload
    assert_equal true, tm.data["bk2_state"]["nachstoss_pending"], "leader reach engaged Nachstoß"

    # Step 2: trailing playerb taps +1 from 69 to 70 (Nachstoß equalizer).
    tm.data["current_inning"]["active_player"] = "playerb"
    tm.save!(validate: false)
    tm.instance_variable_set(:@collected_data_changes, nil)
    tm.instance_variable_set(:@collected_changes, nil)
    tm.add_n_balls(1, "playerb")
    tm.reload
    state = tm.data["bk2_state"]

    assert_equal true, state["set_finished_1"],
      "T-P4: set_finished_1 must be true after trailing's Nachstoß equalizer"
    assert_equal 1, state.dig("sets_won", "playerb"),
      "T-P4: trailing wins on equalize at target (provisional rule)"
    refute state["nachstoss_pending"],
      "T-P4: nachstoss_pending cleared after resolution (false or nil)"
  end

  # Phase 38.4-14 P4: ProtokollEditor write path. The user's UAT report says
  # "Auch nicht, wenn ich über den Protokoll-Editor 50 eingebe." (= "Even when I enter
  # 50 via Protokoll-Editor, [it's rejected]"). Pre-fix: TM#set_n_balls returns early
  # via `return unless playing?` because evaluate_result transitioned to set_over.
  # Post-fix: nachstoss_pending defers the AASM transition, set_n_balls(70) succeeds.
  test "T-P4-protokoll-editor-set-n-balls-honours-target-during-nachstoss 38.4-14" do
    bk2k = ensure_bk_discipline("BK2-Kombi-T-P4-protokoll", "bk2_kombi", [50, 60, 70], nachstoss_allowed: true)
    tm = build_table_monitor_with_discipline(bk2k, balls_goal: 70, free_game_form: "bk2_kombi")
    tm.suppress_broadcast = true
    # set_n_balls (ProtokollEditor write path) returns early via `return unless playing?`,
    # so the TM's `state` column must be "playing" — the existing fixture state is "new".
    tm.update_columns(state: "playing")
    Bk2::AdvanceMatchState.initialize_bk2_state!(tm)

    # Step 1: leader playera reaches 70 via add_n_balls.
    tm.data["balls_on_table"] = 15
    tm.data["balls_counter"] = 0
    tm.data["balls_counter_stack"] = []
    tm.data["playera"] ||= {}
    tm.data["playera"]["discipline"] = "BK2-Kombi-T-P4-protokoll"  # Option B: name-based lookup
    tm.data["playera"]["balls_goal"] = 70
    tm.data["playera"]["result"] = 0
    tm.data["playera"]["innings"] = 1
    tm.data["playera"]["innings_redo_list"] = [69]
    tm.data["playera"]["innings_list"] = []
    tm.data["playera"]["innings_foul_list"] = []
    tm.data["playera"]["innings_foul_redo_list"] = [0]
    tm.data["playerb"] ||= {}
    tm.data["playerb"]["discipline"] = "BK2-Kombi-T-P4-protokoll"
    tm.data["playerb"]["balls_goal"] = 70
    tm.data["playerb"]["result"] = 0
    tm.data["playerb"]["innings"] = 0
    tm.data["playerb"]["innings_redo_list"] = [0]
    tm.data["playerb"]["innings_list"] = []
    tm.data["playerb"]["innings_foul_list"] = []
    tm.data["playerb"]["innings_foul_redo_list"] = [0]
    tm.data["current_inning"] = {"active_player" => "playera"}
    tm.save!(validate: false)
    tm.suppress_broadcast = false
    tm.instance_variable_set(:@collected_data_changes, nil)
    tm.instance_variable_set(:@collected_changes, nil)
    tm.add_n_balls(1, "playera")
    tm.reload
    refute_equal "set_over", tm.state.to_s,
      "T-P4-protokoll: TM.state must NOT be set_over after leader reach (Nachstoß defer)"

    # Step 2: trailing playerb's score is 0; ProtokollEditor enters 70 via set_n_balls.
    tm.data["current_inning"]["active_player"] = "playerb"
    tm.save!(validate: false)
    tm.instance_variable_set(:@collected_data_changes, nil)
    tm.instance_variable_set(:@collected_changes, nil)
    tm.set_n_balls(70)  # ProtokollEditor write path
    tm.reload
    state = tm.data["bk2_state"]

    assert_equal true, state["set_finished_1"],
      "T-P4-protokoll: ProtokollEditor 70 must close the set during Nachstoß"
    assert_equal 1, state.dig("sets_won", "playerb"),
      "T-P4-protokoll: trailing wins on equalize at target (provisional rule)"
  end

  # Phase 38.4-14 P4 (round-4 iteration-2 — BLOCKER 1 fix): INTEGRATION test that proves
  # the dispatcher fires for ACTUAL production wiring (real AR Discipline + production-shape
  # data['playera']['discipline'] String — no define_singleton_method stub).
  #
  # Why this matters: the 3 unit tests above use build_table_monitor_with_discipline which
  # historically stubs TableMonitor#discipline via define_singleton_method to return an AR
  # record. Plan 14 (Option B) does NOT call self.discipline — it reads the discipline
  # name from data['playera']['discipline'] (the existing String contract) and looks up
  # the AR record by name. This integration test exercises that actual production lookup
  # path WITHOUT any stubs.
  test "T-P4-integration-real-discipline-wiring 38.4-14: dispatcher fires for production-shape wiring (real AR Discipline + String name in data, no stubs)" do
    # Real AR Discipline record — same shape the production seed creates.
    bk2k = ensure_bk_discipline("BK2-Kombi-T-P4-integration", "bk2_kombi", [50, 60, 70], nachstoss_allowed: true)
    assert bk2k.persisted?, "T-P4-integration: AR Discipline must be persisted"
    assert bk2k.nachstoss_allowed?, "T-P4-integration: AR Discipline must report nachstoss_allowed=true"

    # TableMonitor wired with the production-shape data['playera']['discipline'] String —
    # NO define_singleton_method on tm.discipline. We use the fixture but we DO NOT
    # override its discipline accessor. Production code reads the name from
    # data['playera']['discipline'], not from tm.discipline (per Option B).
    tm = table_monitors(:one).reload
    tm.suppress_broadcast = true
    tm.data ||= {}
    tm.data["free_game_form"] = "bk2_kombi"
    tm.data["bk2_options"] = {"first_set_mode" => "direkter_zweikampf", "set_target_points" => 70}
    tm.data["bk2_state"] = nil
    tm.data["balls_on_table"] = 15
    tm.data["balls_counter"] = 0
    tm.data["balls_counter_stack"] = []
    tm.data["playera"] = {
      "discipline" => "BK2-Kombi-T-P4-integration",  # ← STRING (production contract)
      "balls_goal" => 70,
      "result" => 0,
      "innings" => 1,
      "innings_redo_list" => [69],
      "innings_list" => [],
      "innings_foul_list" => [],
      "innings_foul_redo_list" => [0]
    }
    tm.data["playerb"] = {
      "discipline" => "BK2-Kombi-T-P4-integration",
      "balls_goal" => 70,
      "result" => 0,
      "innings" => 0,
      "innings_redo_list" => [0],
      "innings_list" => [],
      "innings_foul_list" => [],
      "innings_foul_redo_list" => [0]
    }
    tm.data["current_inning"] = {"active_player" => "playera"}
    tm.tournament_monitor = nil
    tm.save!(validate: false)

    # Verify TableMonitor#discipline still returns a STRING (the unchanged contract).
    # If a future refactor changes this, this assertion will surface the regression.
    assert_kind_of String, tm.discipline,
      "T-P4-integration: TableMonitor#discipline MUST still return a String (15+ legacy callers depend on this; round-4 iteration-2 Option B preserves this contract)"
    assert_equal "BK2-Kombi-T-P4-integration", tm.discipline,
      "T-P4-integration: tm.discipline returns the String name from data['playera']['discipline']"

    Bk2::AdvanceMatchState.initialize_bk2_state!(tm)
    tm.suppress_broadcast = false
    tm.instance_variable_set(:@collected_data_changes, nil)
    tm.instance_variable_set(:@collected_changes, nil)

    tm.add_n_balls(1, "playera")
    tm.reload
    state = tm.data["bk2_state"]

    assert_equal true, state["nachstoss_pending"],
      "T-P4-integration: dispatcher fires WITHOUT define_singleton_method stub — proves Option B name-based lookup works for production wiring"
    assert_equal "playerb", state["player_at_table"],
      "T-P4-integration: player_at_table flipped to playerb"
    refute_equal "set_over", tm.state.to_s,
      "T-P4-integration: TM.state must NOT have transitioned to set_over during Nachstoß defer"
  end

  private

  def ensure_bk_discipline(name, free_game_form, choices, nachstoss_allowed: false)
    data = {"free_game_form" => free_game_form, "ballziel_choices" => choices, "nachstoss_allowed" => nachstoss_allowed}.to_json
    rec = Discipline.find_or_initialize_by(name: name)
    rec.data = data
    rec.type = nil
    rec.table_kind_id = TableKind.find_by(name: "Small Billard")&.id || rec.table_kind_id
    rec.save!(validate: false)
    rec
  end

  def build_table_monitor_with_discipline(discipline, balls_goal:, free_game_form:)
    tm = table_monitors(:one).reload
    tm.data ||= {}
    tm.data["free_game_form"] = free_game_form
    tm.data["bk2_options"] = {"first_set_mode" => "direkter_zweikampf"}
    tm.data["bk2_state"] = nil
    # define_singleton_method used as explicit shortcut — TableMonitor#discipline
    # lookup is multi-step via game.discipline; brittle for unit tests. See SUMMARY.
    tm.define_singleton_method(:discipline) { discipline }
    tm.tournament_monitor = nil
    tm.data["bk2_options"]["set_target_points"] = balls_goal
    tm.save!(validate: false)
    tm
  end
end
