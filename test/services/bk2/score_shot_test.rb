# frozen_string_literal: true

require "test_helper"

# Unit-Tests fuer Bk2::ScoreShot — pure shot evaluator.
#
# Verifiziert: Rohpunkte, Fehlerlogik (D-16 exakte Werte), Bonusstoß (Direkter Zweikampf),
# Serienspiel-Abbruch und DEFAULT_RULES-Konstante.
#
# ScoreShot ist eine pure Funktion (keine DB-Schreibzugriffe, keine Zustandsaenderungen).
# Alle Tests koennen isoliert ohne Datenbank laufen.
class Bk2::ScoreShotTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Default state fixture (Direkter Zweikampf)
  # ---------------------------------------------------------------------------

  setup do
    @default_state = {
      current_phase: "direkter_zweikampf",
      player_at_table: "playera",
      shots_left_in_turn: 2
    }

    @serienspiel_state = {
      current_phase: "serienspiel",
      player_at_table: "playera",
      shots_left_in_turn: nil
    }
  end

  # Helper to build a shot payload with observations and table_snapshot.
  def shot(obs_overrides = {}, snapshot_overrides = {})
    {
      observations: {
        fallen_pins: 0,
        middle_pin_only: false,
        true_carom: false,
        false_carom: false,
        passages: 0,
        foul: false,
        foul_code: nil,
        band_hit: false
      }.merge(obs_overrides),
      table_snapshot: {
        full_pin_image: false
      }.merge(snapshot_overrides)
    }
  end

  # ---------------------------------------------------------------------------
  # Base scoring (tests 1-5)
  # ---------------------------------------------------------------------------

  test "test 1: 3 fallen pins, no carom, no passage → raw_total=3, points_for_current_player=3" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot(fallen_pins: 3),
      state: @default_state
    )

    assert_equal false, result[:scoring][:foul]
    assert_equal 3, result[:scoring][:raw_total]
    assert_equal 3, result[:scoring][:points_for_current_player]
    assert_equal 0, result[:scoring][:points_for_opponent]
    assert_equal 3, result[:scoring][:credited_total]
  end

  test "test 2: middle_pin_only from full_pin_image → raw_total=2 (not 1)" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot({fallen_pins: 1, middle_pin_only: true}, {full_pin_image: true}),
      state: @default_state
    )

    assert_equal false, result[:scoring][:foul]
    assert_equal 2, result[:scoring][:raw_total]
    assert_equal 2, result[:scoring][:points_for_current_player]
  end

  test "test 3: middle_pin_only WITHOUT full_pin_image → raw_total=1 (regular pin)" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot({fallen_pins: 1, middle_pin_only: true}, {full_pin_image: false}),
      state: @default_state
    )

    assert_equal false, result[:scoring][:foul]
    assert_equal 1, result[:scoring][:raw_total]
    assert_equal 1, result[:scoring][:points_for_current_player]
  end

  test "test 4: 5 pins + true_carom → raw_total=6, bonus_shot_awarded=true in Direkter Zweikampf" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot(fallen_pins: 5, true_carom: true),
      state: @default_state
    )

    assert_equal false, result[:scoring][:foul]
    assert_equal 6, result[:scoring][:raw_total]
    assert_equal 6, result[:scoring][:points_for_current_player]
    assert_equal true, result[:transitions][:bonus_shot_awarded]
  end

  test "test 5: 2 passages alone, no pins, no carom → raw_total=2" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot(fallen_pins: 0, passages: 2),
      state: @default_state
    )

    assert_equal false, result[:scoring][:foul]
    assert_equal 2, result[:scoring][:raw_total]
    assert_equal 2, result[:scoring][:points_for_current_player]
    assert_equal 0, result[:scoring][:points_for_opponent]
  end

  # ---------------------------------------------------------------------------
  # Fouls (tests 6-12, including test 10b for direct_play_on_pins floor at fallen_pins=0)
  # ---------------------------------------------------------------------------

  test "test 6: foul=:wrong_ball, fallen_pins=0 → foul_points=-6, points_for_current_player=0, points_for_opponent=6" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot(foul: true, foul_code: :wrong_ball, fallen_pins: 0),
      state: @default_state
    )

    assert_equal true, result[:scoring][:foul]
    assert_equal :wrong_ball, result[:scoring][:foul_code]
    assert_equal(-6, result[:scoring][:foul_points])
    assert_equal 0, result[:scoring][:points_for_current_player]
    assert_equal 6, result[:scoring][:points_for_opponent]
  end

  test "test 7: foul=:no_object_ball_hit, band_hit=true → foul_points=-1, points_for_opponent=1" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot(foul: true, foul_code: :no_object_ball_hit, band_hit: true, fallen_pins: 0),
      state: @default_state
    )

    assert_equal true, result[:scoring][:foul]
    assert_equal(-1, result[:scoring][:foul_points])
    assert_equal 0, result[:scoring][:points_for_current_player]
    assert_equal 1, result[:scoring][:points_for_opponent]
  end

  test "test 8: foul=:no_object_ball_hit, band_hit=false → foul_points=-2, points_for_opponent=2" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot(foul: true, foul_code: :no_object_ball_hit, band_hit: false, fallen_pins: 0),
      state: @default_state
    )

    assert_equal true, result[:scoring][:foul]
    assert_equal(-2, result[:scoring][:foul_points])
    assert_equal 0, result[:scoring][:points_for_current_player]
    assert_equal 2, result[:scoring][:points_for_opponent]
  end

  test "test 9: foul=:premature_shot → foul_points=-1, points_for_opponent=1" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot(foul: true, foul_code: :premature_shot, fallen_pins: 0),
      state: @default_state
    )

    assert_equal true, result[:scoring][:foul]
    assert_equal(-1, result[:scoring][:foul_points])
    assert_equal 0, result[:scoring][:points_for_current_player]
    assert_equal 1, result[:scoring][:points_for_opponent]
  end

  test "test 10: foul=:direct_play_on_pins, fallen_pins=3 → foul_points=-max(1,3)=-3, points_for_opponent=3" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot(foul: true, foul_code: :direct_play_on_pins, fallen_pins: 3),
      state: @default_state
    )

    assert_equal true, result[:scoring][:foul]
    assert_equal(-3, result[:scoring][:foul_points])
    assert_equal 0, result[:scoring][:points_for_current_player]
    assert_equal 3, result[:scoring][:points_for_opponent]
  end

  # B3 fix: direct_play_on_pins floor at fallen_pins=0 must return -1 (NOT +1, NOT 0)
  test "test 10b: foul=:direct_play_on_pins, fallen_pins=0 → foul_points=-max(1,0)=-1 (B3 floor fix)" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot(foul: true, foul_code: :direct_play_on_pins, fallen_pins: 0),
      state: @default_state
    )

    assert_equal true, result[:scoring][:foul]
    assert_equal(-1, result[:scoring][:foul_points],
      "direct_play_on_pins with fallen_pins=0 must return -1 (NEGATIVE signed value with max(1,0) floor)")
    assert_equal 0, result[:scoring][:points_for_current_player]
    assert_equal 1, result[:scoring][:points_for_opponent]
  end

  test "test 11: foul=:direct_play_on_pins, fallen_pins=0 → foul_points=-1, points_for_opponent=1 (explicit D-16 edge case)" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot(foul: true, foul_code: :direct_play_on_pins, fallen_pins: 0),
      state: @default_state
    )

    assert_equal(-1, result[:scoring][:foul_points])
    assert_equal 1, result[:scoring][:points_for_opponent]
  end

  test "test 12: foul=:anything_else (unknown symbol) → foul_points=-1 (other default)" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot(foul: true, foul_code: :completely_unknown_code, fallen_pins: 0),
      state: @default_state
    )

    assert_equal true, result[:scoring][:foul]
    assert_equal(-1, result[:scoring][:foul_points])
    assert_equal 0, result[:scoring][:points_for_current_player]
    assert_equal 1, result[:scoring][:points_for_opponent]
  end

  # ---------------------------------------------------------------------------
  # Bonus-shot rule — Direkter Zweikampf (tests 13-17)
  # ---------------------------------------------------------------------------

  test "test 13: 5 pins + carom, direkter_zweikampf, shots_left=2 → bonus_shot_awarded=true, turn_ends=false, next_player=current, next_shots_left=max(2,1)=2" do
    state = @default_state.merge(shots_left_in_turn: 2)
    result = Bk2::ScoreShot.call(
      shot_payload: shot(fallen_pins: 5, true_carom: true),
      state: state
    )

    assert_equal true, result[:transitions][:bonus_shot_awarded]
    assert_equal false, result[:transitions][:turn_ends]
    assert_equal "playera", result[:transitions][:next_player_at_table]
    assert_equal 2, result[:transitions][:next_shots_left_in_turn]
  end

  test "test 14: 5 pins, NO carom, direkter_zweikampf, shots_left=2 → bonus_shot_awarded=true (5 pins alone qualifies)" do
    state = @default_state.merge(shots_left_in_turn: 2)
    result = Bk2::ScoreShot.call(
      shot_payload: shot(fallen_pins: 5, true_carom: false, false_carom: false),
      state: state
    )

    assert_equal true, result[:transitions][:bonus_shot_awarded]
    assert_equal false, result[:transitions][:turn_ends]
    assert_equal "playera", result[:transitions][:next_player_at_table]
  end

  test "test 15: 4 pins + carom, direkter_zweikampf, shots_left=2 → bonus_shot_awarded=false, turn_ends=false, next_shots_left=1" do
    state = @default_state.merge(shots_left_in_turn: 2)
    result = Bk2::ScoreShot.call(
      shot_payload: shot(fallen_pins: 4, true_carom: true),
      state: state
    )

    assert_equal false, result[:transitions][:bonus_shot_awarded]
    assert_equal false, result[:transitions][:turn_ends]
    assert_equal "playera", result[:transitions][:next_player_at_table]
    assert_equal 1, result[:transitions][:next_shots_left_in_turn]
  end

  test "test 16: 3 pins, direkter_zweikampf, shots_left=1 → bonus_shot_awarded=false, turn_ends=true, next_player swaps, next_shots_left=2" do
    state = @default_state.merge(shots_left_in_turn: 1, player_at_table: "playera")
    result = Bk2::ScoreShot.call(
      shot_payload: shot(fallen_pins: 3),
      state: state
    )

    assert_equal false, result[:transitions][:bonus_shot_awarded]
    assert_equal true, result[:transitions][:turn_ends]
    assert_equal "playerb", result[:transitions][:next_player_at_table]
    assert_equal 2, result[:transitions][:next_shots_left_in_turn]
  end

  test "test 17: Foul, direkter_zweikampf, shots_left=2 → bonus_shot_awarded=false, turn_ends=true (foul always ends turn)" do
    state = @default_state.merge(shots_left_in_turn: 2)
    result = Bk2::ScoreShot.call(
      shot_payload: shot(foul: true, foul_code: :wrong_ball, fallen_pins: 0),
      state: state
    )

    assert_equal false, result[:transitions][:bonus_shot_awarded]
    assert_equal true, result[:transitions][:turn_ends]
    assert_equal "playerb", result[:transitions][:next_player_at_table]
    assert_equal 2, result[:transitions][:next_shots_left_in_turn]
  end

  # ---------------------------------------------------------------------------
  # Serienspiel (tests 18-20)
  # ---------------------------------------------------------------------------

  test "test 18: 3 pins (non-zero, non-foul), serienspiel → turn_ends=false, next_shots_left=nil" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot(fallen_pins: 3),
      state: @serienspiel_state
    )

    assert_equal false, result[:transitions][:turn_ends]
    assert_equal "playera", result[:transitions][:next_player_at_table]
    assert_nil result[:transitions][:next_shots_left_in_turn]
  end

  test "test 19: 0 pins (zero-point shot), serienspiel → turn_ends=true, next_player swaps" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot(fallen_pins: 0),
      state: @serienspiel_state
    )

    assert_equal true, result[:transitions][:turn_ends]
    assert_equal "playerb", result[:transitions][:next_player_at_table]
  end

  test "test 20: Foul, serienspiel → turn_ends=true" do
    result = Bk2::ScoreShot.call(
      shot_payload: shot(foul: true, foul_code: :premature_shot, fallen_pins: 0),
      state: @serienspiel_state
    )

    assert_equal true, result[:transitions][:turn_ends]
    assert_equal "playerb", result[:transitions][:next_player_at_table]
  end

  # ---------------------------------------------------------------------------
  # DEFAULT_RULES guard (tests 21-22)
  # ---------------------------------------------------------------------------

  test "test 21: DEFAULT_RULES is frozen" do
    assert Bk2::ScoreShot::DEFAULT_RULES.frozen?,
      "DEFAULT_RULES must be frozen"
  end

  test "test 22: DEFAULT_RULES has all required keys with D-15 and D-16 literal values" do
    rules = Bk2::ScoreShot::DEFAULT_RULES

    # Scoring values (D-15)
    assert_equal 1, rules.dig(:scoring, :pin)
    assert_equal 2, rules.dig(:scoring, :middle_pin_only_from_full_image)
    assert_equal 1, rules.dig(:scoring, :true_carom)
    assert_equal 1, rules.dig(:scoring, :false_carom_with_pin_or_passage)
    assert_equal 1, rules.dig(:scoring, :passage)

    # Foul values (D-16) — stored as SIGNED NEGATIVE
    assert_equal(-6, rules.dig(:foul_values, :wrong_ball))
    assert_equal(-1, rules.dig(:foul_values, :no_object_ball_hit_with_band))
    assert_equal(-2, rules.dig(:foul_values, :no_object_ball_hit_no_band))
    assert_equal(-1, rules.dig(:foul_values, :premature_shot))
    assert_nil rules.dig(:foul_values, :direct_play_on_pins), # sentinel: computed at call time
      "direct_play_on_pins must be nil (computed sentinel)"
    assert_equal(-1, rules.dig(:foul_values, :other))
  end
end
