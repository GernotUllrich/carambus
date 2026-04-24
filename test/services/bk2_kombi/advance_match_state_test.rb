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
    # Phase 38.2 D-14: Satz 2 flips from first_set_mode. The setup fixture has no
    # bk2_options, so derive_first_set_mode defaults to 'direkter_zweikampf',
    # and Satz 2 must flip to 'serienspiel'. The pre-seeded bk2_state also has
    # no first_set_mode key, but close_set_if_reached! falls back to derive_first_set_mode.
    assert_equal "serienspiel", state["current_phase"],
      "Phase 38.2 D-14: Satz 2 flips to serienspiel when first_set_mode defaults to direkter_zweikampf"
    # SP set: shots_left_in_turn is reset to 0 (SP does not use per-shot counter).
    assert_equal 0, state["shots_left_in_turn"], "SP phase has shots_left_in_turn = 0"
    assert_equal Bk2Kombi::AdvanceMatchState::DEFAULT_SP_MAX_INNINGS_PER_SET,
      state["innings_left_in_set"],
      "New SP set seeds innings_left_in_set from default (5)"
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

    Bk2Kombi::AdvanceMatchState.call(
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
    Bk2Kombi::AdvanceMatchState.call(
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
    svc = Bk2Kombi::AdvanceMatchState.new(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 0))

    assert_equal "direkter_zweikampf", svc.send(:phase_for_set, 1, "direkter_zweikampf")
    assert_equal "serienspiel",         svc.send(:phase_for_set, 2, "direkter_zweikampf")
    assert_equal "direkter_zweikampf", svc.send(:phase_for_set, 3, "direkter_zweikampf")

    assert_equal "serienspiel",         svc.send(:phase_for_set, 1, "serienspiel")
    assert_equal "direkter_zweikampf", svc.send(:phase_for_set, 2, "serienspiel")
    assert_equal "serienspiel",         svc.send(:phase_for_set, 3, "serienspiel")
  end

  test "38.2-01 T4: close_set advances with phase flip and correct counter reset (DZ-first → SP set 2)" do
    tm = fresh_bk2_tm(
      "set_target_points" => 50,
      "direkter_zweikampf_max_shots_per_turn" => 2,
      "serienspiel_max_innings_per_set" => 5,
      "first_set_mode" => "direkter_zweikampf"
    )
    # Initialise state, then bring player A to 47 and close the set with a 5-pin.
    Bk2Kombi::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 0))
    tm.data["bk2_state"]["set_scores"]["1"]["playera"] = 47
    tm.save!
    Bk2Kombi::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 5))

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
    Bk2Kombi::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 2))
    # Bring playera to the brink of the set target while still at table.
    tm.data["bk2_state"]["set_scores"]["1"]["playera"] = 47
    tm.save!
    # A 5-pin SP shot by playera pushes to 52 → set 1 closes.
    Bk2Kombi::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 5))

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
    Bk2Kombi::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 2))
    assert_equal 5, tm.reload.data["bk2_state"]["innings_left_in_set"]

    # Turn-ending shot: foul in SP ends the Aufnahme → innings_left decrements.
    Bk2Kombi::AdvanceMatchState.call(table_monitor: tm, shot_payload: foul_shot(foul_code: :wrong_ball))

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
    Bk2Kombi::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 2))
    assert_equal 5, tm.reload.data["bk2_state"]["innings_left_in_set"]

    # Zero-pin non-foul shot in SP ends the Aufnahme per ScoreShot.calculate_serienspiel_transitions.
    Bk2Kombi::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 0))

    state = tm.reload.data["bk2_state"]
    assert_equal 4, state["innings_left_in_set"]
  end

  test "38.2-01 T6: apply_transitions does not touch innings_left_in_set in direkter_zweikampf" do
    tm = fresh_bk2_tm(
      "set_target_points" => 50,
      "direkter_zweikampf_max_shots_per_turn" => 2,
      "first_set_mode" => "direkter_zweikampf"
    )
    Bk2Kombi::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 0))
    state = tm.reload.data["bk2_state"]
    assert_equal 0, state["innings_left_in_set"]

    Bk2Kombi::AdvanceMatchState.call(table_monitor: tm, shot_payload: foul_shot(foul_code: :wrong_ball))
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

    Bk2Kombi::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 0))

    state = tm.reload.data["bk2_state"]
    assert_equal "direkter_zweikampf", state["current_phase"],
      "Default first_set_mode and set-1 phase is direkter_zweikampf"
    assert_equal "direkter_zweikampf", state["first_set_mode"]
    assert_equal 50, state["set_target_points"]
    # Default DZ max shots = 2, one shot consumed → shots_left_in_turn = 1.
    assert_equal 1, state["shots_left_in_turn"]
    assert_equal 0, state["innings_left_in_set"], "innings_left_in_set is 0 while in DZ phase"
  end

  test "38.2-01 T8: invalid first_set_mode in bk2_options falls back to direkter_zweikampf" do
    tm = fresh_bk2_tm(
      "set_target_points" => 50,
      "first_set_mode" => "attacker_injected_value"
    )

    Bk2Kombi::AdvanceMatchState.call(table_monitor: tm, shot_payload: pin_shot(fallen_pins: 0))

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

    Bk2Kombi::AdvanceMatchState.initialize_bk2_state!(@tm)
    @tm.reload
    state = @tm.data["bk2_state"]

    assert_equal "direkter_zweikampf", state["current_phase"]
    assert_equal 1, state["current_set_number"]
    assert_equal 2, state["shots_left_in_turn"]
    assert_equal 0, state["innings_left_in_set"]
    assert_equal 50, state["set_target_points"]
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

    Bk2Kombi::AdvanceMatchState.initialize_bk2_state!(@tm)
    @tm.reload
    state = @tm.data["bk2_state"]

    assert_equal "serienspiel", state["current_phase"]
    assert_equal 0, state["shots_left_in_turn"]
    assert_equal 7, state["innings_left_in_set"]
    assert_equal 70, state["set_target_points"]
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
        "set_target_points" => 50
      }
    })

    Bk2Kombi::AdvanceMatchState.initialize_bk2_state!(@tm)
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

    Bk2Kombi::AdvanceMatchState.initialize_bk2_state!(@tm)
    @tm.reload
    state = @tm.data["bk2_state"]

    # derive_first_set_mode returns DEFAULT_FIRST_SET_MODE ("direkter_zweikampf")
    assert_equal "direkter_zweikampf", state["current_phase"]
    assert_equal Bk2Kombi::AdvanceMatchState::DEFAULT_DZ_MAX_SHOTS_PER_TURN, state["shots_left_in_turn"]
    assert_equal 0, state["innings_left_in_set"]
    refute @tm.bk2_state_uninitialized?, "predicate must return false after init (default-mode path)"
  end
end
