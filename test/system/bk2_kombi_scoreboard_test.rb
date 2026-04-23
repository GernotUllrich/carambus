# frozen_string_literal: true

require "application_system_test_case"

# BK2-Kombi scoreboard system test.
#
# Coverage split:
#   Capybara (browser DOM) tests:
#     - Rendering: bk2_kombi partial renders when free_game_form == "bk2_kombi"
#     - Negative control: bk2_kombi DOM absent for karambol discipline
#
#   Integration-level shot-submit tests (call AdvanceMatchState directly):
#     The StimulusReflex click path (data-reflex) requires a running WebSocket
#     server + JS execution and is brittle with Capybara. Plan 04 allows
#     falling back to integration-level for shot-submit assertions as long as
#     coverage remains end-to-end (not pure unit). These tests exercise the
#     full Ruby dispatch chain: reflex payload shape → AdvanceMatchState →
#     bk2_state persistence, which is the load-bearing path.
#
#   Per plan requirement: B2 full_pin_image → 2-point path MUST be
#   integration-level (not pure unit). Tests 3–5 satisfy this.
class Bk2KombiScoreboardTest < ApplicationSystemTestCase
  setup do
    @tm = table_monitors(:one)

    # Minimal Game so the show action does not redirect.
    # System tests do not wrap in transactions; use find_or_create_by!.
    @game = Game.find_or_create_by!(id: 50_000_200)

    @bk2_data = {
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

    @tm.update_columns(game_id: @game.id, state: "playing")
    @tm.update!(data: @bk2_data)
  end

  teardown do
    @tm.update_columns(game_id: nil, state: "new")
    @tm.update!(data: {})
    @game&.destroy
  end

  # -----------------------------------------------------------------------
  # DOM rendering tests (Capybara)
  # -----------------------------------------------------------------------

  test "renders bk2_kombi scoreboard partial when free_game_form is bk2_kombi" do
    visit table_monitor_path(@tm)

    begin
      assert_selector "[data-controller~='bk2-kombi-shot']", wait: 5
    rescue StandardError => e
      flunk "bk2-kombi-shot Stimulus controller not found in DOM: #{e.class}: #{e.message}"
    end

    begin
      assert_text I18n.t("table_monitor.bk2_kombi.phase.direkter_zweikampf")
    rescue StandardError => e
      flunk "Phase indicator text missing: #{e.class}: #{e.message}"
    end

    begin
      assert_selector "[data-bk2-kombi-shot-target='fullPinImage']", wait: 3
    rescue StandardError => e
      flunk "fullPinImage checkbox missing from form — B2 fix not rendered: #{e.class}: #{e.message}"
    end
  end

  test "does NOT render bk2_kombi partial when free_game_form is karambol" do
    @tm.update!(data: @bk2_data.merge("free_game_form" => "karambol"))
    visit table_monitor_path(@tm)

    assert_no_selector "[data-controller~='bk2-kombi-shot']", wait: 3
  end

  # -----------------------------------------------------------------------
  # Integration-level shot-submit tests
  # (call AdvanceMatchState directly — same load-bearing path as the reflex)
  # -----------------------------------------------------------------------

  # Helper: build a shot payload matching the D-13 shape the reflex constructs.
  def build_shot_payload(fallen_pins:, middle_pin_only: false, full_pin_image: false,
    true_carom: false, false_carom: false, passages: 0,
    foul: false, foul_code: nil, band_hit: false)
    {
      observations: {
        fallen_pins: fallen_pins,
        middle_pin_only: middle_pin_only,
        true_carom: true_carom,
        false_carom: false_carom,
        passages: passages,
        foul: foul,
        foul_code: foul_code,
        band_hit: band_hit
      },
      table_snapshot: {full_pin_image: full_pin_image},
      shot_sequence_number: SecureRandom.uuid
    }
  end

  # Helper: reload @tm and return bk2_state.
  def reload_bk2_state
    @tm.reload
    @tm.data.dig("bk2_state")
  end

  test "submits a 3-pin shot and updates set_scores (integration path)" do
    payload = build_shot_payload(fallen_pins: 3)

    begin
      Bk2Kombi::AdvanceMatchState.call(table_monitor: @tm, shot_payload: payload)
    rescue StandardError => e
      flunk "AdvanceMatchState raised unexpectedly: #{e.class}: #{e.message}"
    end

    state = reload_bk2_state
    assert_equal 3, state.dig("set_scores", "1", "playera"),
      "3-pin shot must credit 3 points to playera in set 1"
  end

  # B2 FIX — mandatory: proves the D-15 2-point rule is reachable via the
  # integration path that the reflex exercises.
  # full_pin_image=true + fallen_pins=1 + middle_pin_only=true → 2 points.
  test "scores 2 points for middle_pin_only with full_pin_image=true (D-15 rule, B2 fix)" do
    payload = build_shot_payload(
      fallen_pins: 1,
      middle_pin_only: true,
      full_pin_image: true
    )

    begin
      Bk2Kombi::AdvanceMatchState.call(table_monitor: @tm, shot_payload: payload)
    rescue StandardError => e
      flunk "AdvanceMatchState raised on D-15 path: #{e.class}: #{e.message}"
    end

    state = reload_bk2_state
    assert_equal 2, state.dig("set_scores", "1", "playera"),
      "D-15: full_pin_image=true + fallen_pins=1 + middle_pin_only=true MUST score 2 (not 1) — unreachable without B2-fix UI control"
  end

  # B2 FIX contrast: same shot WITHOUT full_pin_image → 1 point.
  # Proves the full_pin_image toggle actually drives different scoring.
  test "scores 1 point for middle_pin_only WITHOUT full_pin_image (contrast with D-15)" do
    payload = build_shot_payload(
      fallen_pins: 1,
      middle_pin_only: true,
      full_pin_image: false
    )

    begin
      Bk2Kombi::AdvanceMatchState.call(table_monitor: @tm, shot_payload: payload)
    rescue StandardError => e
      flunk "AdvanceMatchState raised on non-D-15 path: #{e.class}: #{e.message}"
    end

    state = reload_bk2_state
    assert_equal 1, state.dig("set_scores", "1", "playera"),
      "Without full_pin_image the same shot must score only 1 — proves the full_pin_image toggle drives scoring differently"
  end

  # Idempotency: same shot_sequence_number submitted twice → only one state update.
  test "idempotency guard: duplicate shot_sequence_number is ignored" do
    seq = SecureRandom.uuid
    payload1 = build_shot_payload(fallen_pins: 3).merge(shot_sequence_number: seq)
    payload2 = build_shot_payload(fallen_pins: 3).merge(shot_sequence_number: seq)

    begin
      Bk2Kombi::AdvanceMatchState.call(table_monitor: @tm, shot_payload: payload1)
      @tm.reload
      Bk2Kombi::AdvanceMatchState.call(table_monitor: @tm, shot_payload: payload2)
    rescue StandardError => e
      flunk "AdvanceMatchState raised on idempotency path: #{e.class}: #{e.message}"
    end

    state = reload_bk2_state
    assert_equal 3, state.dig("set_scores", "1", "playera"),
      "Duplicate shot_sequence_number must be ignored — set_scores must be 3, not 6"
  end
end
