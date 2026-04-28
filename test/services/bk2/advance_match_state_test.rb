# frozen_string_literal: true

require "test_helper"

# Bk2::AdvanceMatchState-Smoke-Tests nach Cleanup. Die Klasse hält nur noch
# initialize_bk2_state! (read-only Konfig-Seeding für Views) — Multiset-Logik
# ist im legacy karambol-Pfad, BK-Regeln sind als Guards in TableMonitor.
class Bk2::AdvanceMatchStateTest < ActiveSupport::TestCase
  setup do
    @tm = TableMonitor.create!(
      state: "playing",
      data: {
        "free_game_form" => "bk2_kombi",
        "bk2_options" => {
          "first_set_mode" => "direkter_zweikampf",
          "balls_goal" => 70,
          "direkter_zweikampf_max_shots_per_turn" => 2,
          "serienspiel_max_innings_per_set" => 5
        }
      }
    )
  end

  test "initialize_bk2_state! seeds bk2_state with derived config" do
    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    state = @tm.reload.data["bk2_state"]

    assert_equal 1, state["current_set_number"]
    assert_equal "direkter_zweikampf", state["current_phase"]
    assert_equal "direkter_zweikampf", state["first_set_mode"]
    assert_equal 70, state["balls_goal"]
    assert_equal 70, state["set_target_points"]
    assert_equal 2, state["shots_left_in_turn"]
    assert_equal 0, state["innings_left_in_set"]
    assert_equal({"playera" => 0, "playerb" => 0}, state["sets_won"])
  end

  test "initialize_bk2_state! is idempotent (no-op when bk2_state already present)" do
    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    @tm.reload.data["bk2_state"]["current_set_number"] = 99
    @tm.save!

    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    assert_equal 99, @tm.reload.data["bk2_state"]["current_set_number"],
      "second init must not overwrite existing state"
  end

  test "initialize_bk2_state! seeds SP-first config when first_set_mode=serienspiel" do
    @tm.update!(data: @tm.data.merge("bk2_options" => @tm.data["bk2_options"].merge("first_set_mode" => "serienspiel")))
    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    state = @tm.reload.data["bk2_state"]

    assert_equal "serienspiel", state["current_phase"]
    assert_equal 0, state["shots_left_in_turn"]
    assert_equal 5, state["innings_left_in_set"]
  end

  test "initialize_bk2_state! falls back to defaults when bk2_options missing" do
    @tm.update!(data: {"free_game_form" => "bk2_kombi"})
    Bk2::AdvanceMatchState.initialize_bk2_state!(@tm)
    state = @tm.reload.data["bk2_state"]

    assert_equal "direkter_zweikampf", state["first_set_mode"]
    assert_equal 50, state["balls_goal"]
    assert_equal 2, state["shots_left_in_turn"]
  end
end
