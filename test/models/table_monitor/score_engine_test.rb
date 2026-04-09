# frozen_string_literal: true

require "test_helper"

# Unit tests for TableMonitor::ScoreEngine.
# Uses plain Ruby hashes only — no database, no fixtures, no FactoryBot.
# All tests verify hash mutation by reference.
class TableMonitor::ScoreEngineTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def playing_data(overrides = {})
    {
      "current_inning" => { "active_player" => "playera" },
      "balls_on_table" => 15,
      "balls_counter" => 0,
      "balls_counter_stack" => [],
      "extra_balls" => 0,
      "playera" => {
        "result" => 0, "innings" => 0, "innings_list" => [],
        "innings_redo_list" => [0], "innings_foul_list" => [],
        "innings_foul_redo_list" => [0], "hs" => 0, "gd" => 0.0,
        "balls_goal" => "100", "fouls_1" => 0,
        "discipline" => "Freie Partie"
      },
      "playerb" => {
        "result" => 0, "innings" => 0, "innings_list" => [],
        "innings_redo_list" => [0], "innings_foul_list" => [],
        "innings_foul_redo_list" => [0], "hs" => 0, "gd" => 0.0,
        "balls_goal" => "100", "fouls_1" => 0,
        "discipline" => "Freie Partie"
      },
      "allow_overflow" => nil,
      "innings_goal" => "0"
    }.deep_merge(overrides)
  end

  def snooker_data(overrides = {})
    base = playing_data(
      "free_game_form" => "snooker",
      "snooker_state" => {
        "reds_remaining" => 15,
        "last_potted_ball" => nil,
        "free_ball_active" => false,
        "colors_sequence" => [2, 3, 4, 5, 6, 7]
      },
      "playera" => { "discipline" => "Snooker", "break_balls_redo_list" => [[]], "break_balls_list" => [], "break_fouls_list" => [] },
      "playerb" => { "discipline" => "Snooker", "break_balls_redo_list" => [[]], "break_balls_list" => [], "break_fouls_list" => [] }
    )
    base.deep_merge(overrides)
  end

  def engine(data, discipline: "Freie Partie")
    TableMonitor::ScoreEngine.new(data, discipline: discipline)
  end

  # ---------------------------------------------------------------------------
  # add_n_balls
  # ---------------------------------------------------------------------------

  test "add_n_balls increments active player innings_redo_list last element" do
    data = playing_data
    e = engine(data)
    e.add_n_balls(5)
    assert_equal 5, data.dig("playera", "innings_redo_list", -1)
  end

  test "add_n_balls returns :goal_reached when player reaches balls_goal" do
    data = playing_data("playera" => { "balls_goal" => "10", "result" => 0, "innings_redo_list" => [0] })
    e = engine(data)
    result = e.add_n_balls(10)
    assert_equal :goal_reached, result
  end

  test "add_n_balls with nil player uses current_inning active_player" do
    data = playing_data
    e = engine(data)
    e.add_n_balls(3)
    assert_equal 3, data.dig("playera", "innings_redo_list", -1)
    assert_equal 0, data.dig("playerb", "innings_redo_list", -1)
  end

  test "add_n_balls with explicit player uses that player" do
    data = playing_data
    e = engine(data)
    e.add_n_balls(7, "playerb")
    # playerb gets the balls when specified
    assert_equal 7, data.dig("playerb", "innings_redo_list", -1)
  end

  test "add_n_balls does not exceed balls_goal without allow_overflow" do
    data = playing_data("playera" => { "balls_goal" => "10", "result" => 0, "innings_redo_list" => [0] })
    e = engine(data)
    # 15 balls > 10 goal — should be rejected (should_process_input false)
    e.add_n_balls(15)
    assert_equal 0, data.dig("playera", "innings_redo_list", -1)
  end

  test "add_n_balls returns nil for normal increment (not goal)" do
    data = playing_data
    e = engine(data)
    result = e.add_n_balls(5)
    assert_nil result
  end

  test "add_n_balls resets fouls_1 on successful ball entry" do
    data = playing_data("playera" => { "fouls_1" => 2, "innings_redo_list" => [0], "balls_goal" => "100", "result" => 0 })
    e = engine(data)
    e.add_n_balls(3)
    assert_equal 0, data.dig("playera", "fouls_1")
  end

  # ---------------------------------------------------------------------------
  # set_n_balls
  # ---------------------------------------------------------------------------

  test "set_n_balls sets innings_redo_list to exactly n_balls" do
    data = playing_data
    e = engine(data)
    e.set_n_balls(42)
    assert_equal 42, data.dig("playera", "innings_redo_list", -1)
  end

  test "set_n_balls returns :goal_reached when n_balls equals remaining goal" do
    data = playing_data("playera" => { "balls_goal" => "10", "result" => 0, "innings_redo_list" => [0] })
    e = engine(data)
    result = e.set_n_balls(10)
    assert_equal :goal_reached, result
  end

  test "set_n_balls returns nil for normal set" do
    data = playing_data
    e = engine(data)
    result = e.set_n_balls(5)
    assert_nil result
  end

  # ---------------------------------------------------------------------------
  # foul_one
  # ---------------------------------------------------------------------------

  test "foul_one increments fouls_1 counter" do
    data = playing_data
    e = engine(data)
    e.foul_one
    assert_equal 1, data.dig("playera", "fouls_1")
  end

  test "foul_one decrements innings_foul_redo_list by 1" do
    data = playing_data
    e = engine(data)
    e.foul_one
    assert_equal(-1, data.dig("playera", "innings_foul_redo_list", -1))
  end

  test "foul_one returns :inning_terminated when fouls_1 <= 2" do
    data = playing_data
    e = engine(data)
    result = e.foul_one
    assert_equal :inning_terminated, result
  end

  test "foul_one returns nil (not :inning_terminated) when fouls_1 exceeds 2 (heavy foul)" do
    data = playing_data("playera" => { "fouls_1" => 2, "innings_foul_redo_list" => [0], "innings_redo_list" => [0], "balls_goal" => "100", "result" => 0 })
    e = engine(data)
    result = e.foul_one
    assert_nil result
    assert_equal 0, data.dig("playera", "fouls_1"), "fouls_1 should reset to 0 after heavy foul"
  end

  # ---------------------------------------------------------------------------
  # foul_two
  # ---------------------------------------------------------------------------

  test "foul_two decrements innings_foul_redo_list by 2" do
    data = playing_data
    e = engine(data)
    e.foul_two
    assert_equal(-2, data.dig("playera", "innings_foul_redo_list", -1))
  end

  test "foul_two returns :inning_terminated" do
    data = playing_data
    e = engine(data)
    result = e.foul_two
    assert_equal :inning_terminated, result
  end

  test "foul_two updates result from innings_list sum plus fouls" do
    data = playing_data("playera" => {
      "innings_list" => [5, 3],
      "innings_foul_list" => [0, 0],
      "innings_foul_redo_list" => [0],
      "result" => 8, "innings_redo_list" => [0], "fouls_1" => 0, "balls_goal" => "100"
    })
    e = engine(data)
    e.foul_two
    assert_equal 6, data.dig("playera", "result") # 8 + 0 + (-2)
  end

  # ---------------------------------------------------------------------------
  # balls_left
  # ---------------------------------------------------------------------------

  test "balls_left delegates to add_n_balls with computed ball count" do
    data = playing_data("balls_on_table" => 15)
    e = engine(data)
    e.balls_left(10) # adds 15 - 10 = 5 balls
    assert_equal 5, data.dig("playera", "innings_redo_list", -1)
  end

  test "balls_left returns the same signal as add_n_balls" do
    data = playing_data("playera" => { "balls_goal" => "5", "result" => 0, "innings_redo_list" => [0] },
                        "balls_on_table" => 15)
    e = engine(data)
    result = e.balls_left(10) # adds 5 balls, exactly hits goal
    assert_equal :goal_reached, result
  end

  # ---------------------------------------------------------------------------
  # recompute_result
  # ---------------------------------------------------------------------------

  test "recompute_result recalculates result from innings_list" do
    data = playing_data("playera" => {
      "innings_list" => [10, 20, 5],
      "innings_foul_list" => [0, 0, 0],
      "innings_foul_redo_list" => [0],
      "innings_redo_list" => [3],
      "result" => 0, "fouls_1" => 0, "balls_goal" => "100"
    })
    e = engine(data)
    e.recompute_result("playera")
    assert_equal 35, data.dig("playera", "result") # 10+20+5 + 0 fouls + 0 foul_redo
  end

  test "recompute_result updates balls_on_table based on total potted" do
    data = playing_data
    e = engine(data)
    e.add_n_balls(5)
    assert_operator data["balls_on_table"], :>=, 0
  end

  # ---------------------------------------------------------------------------
  # init_lists
  # ---------------------------------------------------------------------------

  test "init_lists creates empty innings_list when nil" do
    data = playing_data("playera" => { "innings_list" => nil, "innings_redo_list" => [0], "innings_foul_redo_list" => [0], "balls_goal" => "100", "result" => 0, "fouls_1" => 0 })
    e = engine(data)
    e.init_lists("playera")
    assert_equal [], data.dig("playera", "innings_list")
  end

  test "init_lists sets innings_redo_list to [0] when blank" do
    data = playing_data("playera" => { "innings_list" => [], "innings_redo_list" => [], "innings_foul_redo_list" => [0], "balls_goal" => "100", "result" => 0, "fouls_1" => 0 })
    e = engine(data)
    e.init_lists("playera")
    assert_equal [0], data.dig("playera", "innings_redo_list")
  end

  test "init_lists sets innings_foul_redo_list to [0] when blank" do
    data = playing_data("playera" => { "innings_list" => [], "innings_redo_list" => [0], "innings_foul_redo_list" => [], "balls_goal" => "100", "result" => 0, "fouls_1" => 0 })
    e = engine(data)
    e.init_lists("playera")
    assert_equal [0], data.dig("playera", "innings_foul_redo_list")
  end

  # ---------------------------------------------------------------------------
  # undo_hash
  # ---------------------------------------------------------------------------

  test "undo_hash decrements current player innings_redo_list by 1" do
    data = playing_data("playera" => { "innings_redo_list" => [5], "innings_list" => [], "innings_foul_redo_list" => [0], "innings_foul_list" => [], "result" => 0, "balls_goal" => "100", "fouls_1" => 0 })
    e = engine(data)
    e.undo_hash
    assert_equal 4, data.dig("playera", "innings_redo_list", -1)
  end

  test "undo_hash moves last completed inning of other player back to redo_list" do
    data = playing_data(
      "current_inning" => { "active_player" => "playera" },
      "playera" => { "innings_redo_list" => [0], "innings_list" => [], "innings_foul_redo_list" => [0], "innings_foul_list" => [], "result" => 0, "balls_goal" => "100", "fouls_1" => 0 },
      "playerb" => { "innings_redo_list" => [0], "innings_list" => [7, 3], "innings_foul_redo_list" => [0], "innings_foul_list" => [0, 0], "result" => 10, "innings" => 2, "balls_goal" => "100", "fouls_1" => 0 }
    )
    e = engine(data)
    e.undo_hash
    assert_equal 3, data.dig("playerb", "innings_redo_list", -1)
    assert_equal [7], data.dig("playerb", "innings_list")
    assert_equal "playerb", data.dig("current_inning", "active_player")
  end

  test "undo_hash returns nil" do
    data = playing_data("playera" => { "innings_redo_list" => [3], "innings_list" => [], "innings_foul_redo_list" => [0], "innings_foul_list" => [], "result" => 0, "balls_goal" => "100", "fouls_1" => 0 })
    e = engine(data)
    result = e.undo_hash
    assert_nil result
  end

  # ---------------------------------------------------------------------------
  # redo_hash
  # ---------------------------------------------------------------------------

  test "redo_hash returns :inning_terminated when innings_redo has points" do
    data = playing_data("playera" => { "innings_redo_list" => [5], "innings_list" => [], "innings_foul_redo_list" => [0], "innings_foul_list" => [], "result" => 0, "balls_goal" => "100", "fouls_1" => 0 })
    e = engine(data)
    result = e.redo_hash
    assert_equal :inning_terminated, result
  end

  test "redo_hash returns nil when no points to redo" do
    data = playing_data("playera" => { "innings_redo_list" => [0], "innings_list" => [], "innings_foul_redo_list" => [0], "innings_foul_list" => [], "result" => 0, "balls_goal" => "100", "fouls_1" => 0 })
    e = engine(data)
    result = e.redo_hash
    assert_nil result
  end

  # ---------------------------------------------------------------------------
  # render_innings_list
  # ---------------------------------------------------------------------------

  test "render_innings_list returns an HTML string" do
    data = playing_data("playera" => { "innings_list" => [5, 3, 10], "innings_foul_list" => [0, 0, 0], "innings_redo_list" => [2], "innings" => 4, "balls_goal" => "100", "result" => 18, "fouls_1" => 0 })
    e = engine(data)
    result = e.render_innings_list("playera")
    assert_kind_of String, result
    assert result.include?("<table")
  end

  test "render_innings_list returns empty string for nil role" do
    data = playing_data
    e = engine(data)
    result = e.render_innings_list(nil)
    assert_equal "", result
  end

  test "render_innings_list returns empty string for unknown role" do
    data = playing_data
    e = engine(data)
    result = e.render_innings_list("playerc")
    assert_equal "", result
  end

  # ---------------------------------------------------------------------------
  # render_last_innings
  # ---------------------------------------------------------------------------

  test "render_last_innings returns an HTML string" do
    data = playing_data("playera" => { "innings_list" => [5, 3, 10], "innings_foul_list" => [0, 0, 0], "innings_redo_list" => [2], "innings" => 4, "balls_goal" => "100", "result" => 18, "fouls_1" => 0 })
    e = engine(data)
    result = e.render_last_innings(5, "playera")
    assert_kind_of String, result
  end

  test "render_last_innings truncates to last_n when more innings exist" do
    innings = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    fouls = [0] * 10
    data = playing_data("playera" => { "innings_list" => innings, "innings_foul_list" => fouls, "innings_redo_list" => [0], "innings" => 10, "balls_goal" => "100", "result" => 55, "fouls_1" => 0 })
    e = engine(data)
    result = e.render_last_innings(3, "playera")
    assert result.include?("..."), "Expected truncation indicator"
  end

  test "render_last_innings returns empty string for nil role" do
    data = playing_data
    e = engine(data)
    result = e.render_last_innings(5, nil)
    assert_equal "", result
  end

  # ---------------------------------------------------------------------------
  # innings_history
  # ---------------------------------------------------------------------------

  test "innings_history returns structured hash with player_a and player_b keys" do
    data = playing_data
    e = engine(data)
    result = e.innings_history
    assert result.key?(:player_a)
    assert result.key?(:player_b)
    assert result.key?(:current_inning)
    assert result.key?(:discipline)
    assert result.key?(:balls_goal)
  end

  test "innings_history returns correct innings arrays" do
    data = playing_data(
      "playera" => { "innings_list" => [10, 5], "innings_redo_list" => [3], "innings" => 3, "result" => 15, "balls_goal" => "100", "fouls_1" => 0 },
      "playerb" => { "innings_list" => [7], "innings_redo_list" => [0], "innings" => 1, "result" => 7, "balls_goal" => "100", "fouls_1" => 0 }
    )
    e = engine(data)
    result = e.innings_history
    assert_includes result[:player_a][:innings], 10
    assert_includes result[:player_a][:innings], 5
  end

  test "innings_history returns fallback names when no gps provided" do
    data = playing_data
    e = engine(data)
    result = e.innings_history
    assert_equal "Spieler A", result[:player_a][:name]
    assert_equal "Spieler B", result[:player_b][:name]
  end

  # ---------------------------------------------------------------------------
  # update_innings_history
  # ---------------------------------------------------------------------------

  test "update_innings_history returns success hash on valid input" do
    data = playing_data("playera" => { "innings" => 2, "innings_list" => [5], "innings_redo_list" => [3], "innings_foul_list" => [0], "innings_foul_redo_list" => [0], "result" => 8, "balls_goal" => "100", "fouls_1" => 0 },
                        "playerb" => { "innings" => 1, "innings_list" => [], "innings_redo_list" => [4], "innings_foul_list" => [], "innings_foul_redo_list" => [0], "result" => 4, "balls_goal" => "100", "fouls_1" => 0 })
    e = engine(data)
    result = e.update_innings_history({ "playera" => [5, 3], "playerb" => [4] }, playing_or_set_over: true)
    assert_equal({ success: true }, result)
  end

  test "update_innings_history returns error when negative values provided" do
    data = playing_data
    e = engine(data)
    result = e.update_innings_history({ "playera" => [-1], "playerb" => [] }, playing_or_set_over: true)
    assert_equal false, result[:success]
    assert result[:error].present?
  end

  test "update_innings_history returns error when not in playing state" do
    data = playing_data
    e = engine(data)
    result = e.update_innings_history({ "playera" => [5], "playerb" => [] }, playing_or_set_over: false)
    assert_equal false, result[:success]
  end

  # ---------------------------------------------------------------------------
  # increment_inning_points
  # ---------------------------------------------------------------------------

  test "increment_inning_points increases a completed inning by 1" do
    data = playing_data("playera" => { "innings_list" => [5, 3], "innings_redo_list" => [0], "innings" => 2, "innings_foul_list" => [0, 0], "innings_foul_redo_list" => [0], "result" => 8, "balls_goal" => "100", "fouls_1" => 0 })
    e = engine(data)
    e.increment_inning_points(0, "playera")
    assert_equal 6, data.dig("playera", "innings_list", 0)
  end

  test "increment_inning_points increases the current inning in redo_list" do
    data = playing_data("playera" => { "innings_list" => [5], "innings_redo_list" => [2], "innings" => 2, "innings_foul_list" => [0], "innings_foul_redo_list" => [0], "result" => 5, "balls_goal" => "100", "fouls_1" => 0 })
    e = engine(data)
    e.increment_inning_points(1, "playera")
    assert_equal 3, data.dig("playera", "innings_redo_list", 0)
  end

  # ---------------------------------------------------------------------------
  # decrement_inning_points
  # ---------------------------------------------------------------------------

  test "decrement_inning_points decreases a completed inning by 1" do
    data = playing_data("playera" => { "innings_list" => [5, 3], "innings_redo_list" => [0], "innings" => 2, "innings_foul_list" => [0, 0], "innings_foul_redo_list" => [0], "result" => 8, "balls_goal" => "100", "fouls_1" => 0 })
    e = engine(data)
    e.decrement_inning_points(0, "playera")
    assert_equal 4, data.dig("playera", "innings_list", 0)
  end

  test "decrement_inning_points floors at 0" do
    data = playing_data("playera" => { "innings_list" => [0], "innings_redo_list" => [0], "innings" => 1, "innings_foul_list" => [0], "innings_foul_redo_list" => [0], "result" => 0, "balls_goal" => "100", "fouls_1" => 0 })
    e = engine(data)
    e.decrement_inning_points(0, "playera")
    assert_equal 0, data.dig("playera", "innings_list", 0)
  end

  # ---------------------------------------------------------------------------
  # delete_inning
  # ---------------------------------------------------------------------------

  test "delete_inning removes a 0:0 inning from both players" do
    data = playing_data(
      "playera" => { "innings_list" => [0, 5], "innings_redo_list" => [0], "innings" => 3, "innings_foul_list" => [0, 0], "innings_foul_redo_list" => [0], "result" => 5, "balls_goal" => "100", "fouls_1" => 0 },
      "playerb" => { "innings_list" => [0, 7], "innings_redo_list" => [0], "innings" => 3, "innings_foul_list" => [0, 0], "innings_foul_redo_list" => [0], "result" => 7, "balls_goal" => "100", "fouls_1" => 0 }
    )
    e = engine(data)
    result = e.delete_inning(0, playing_or_set_over: true)
    assert_equal({ success: true }, result)
    assert_equal [5], data.dig("playera", "innings_list")
    assert_equal [7], data.dig("playerb", "innings_list")
  end

  test "delete_inning returns error when values are not 0:0" do
    data = playing_data(
      "playera" => { "innings_list" => [3], "innings_redo_list" => [0], "innings" => 2, "innings_foul_list" => [0], "innings_foul_redo_list" => [0], "result" => 3, "balls_goal" => "100", "fouls_1" => 0 },
      "playerb" => { "innings_list" => [0], "innings_redo_list" => [0], "innings" => 2, "innings_foul_list" => [0], "innings_foul_redo_list" => [0], "result" => 0, "balls_goal" => "100", "fouls_1" => 0 }
    )
    e = engine(data)
    result = e.delete_inning(0, playing_or_set_over: true)
    assert_equal false, result[:success]
  end

  test "delete_inning returns error for current inning" do
    data = playing_data(
      "playera" => { "innings_list" => [5], "innings_redo_list" => [0], "innings" => 2, "innings_foul_list" => [0], "innings_foul_redo_list" => [0], "result" => 5, "balls_goal" => "100", "fouls_1" => 0 },
      "playerb" => { "innings_list" => [3], "innings_redo_list" => [0], "innings" => 2, "innings_foul_list" => [0], "innings_foul_redo_list" => [0], "result" => 3, "balls_goal" => "100", "fouls_1" => 0 }
    )
    e = engine(data)
    result = e.delete_inning(1, playing_or_set_over: true) # index >= max_list_length
    assert_equal false, result[:success]
  end

  # ---------------------------------------------------------------------------
  # insert_inning
  # ---------------------------------------------------------------------------

  test "insert_inning adds a zero inning at the given position" do
    data = playing_data(
      "playera" => { "innings_list" => [5, 3], "innings_redo_list" => [2], "innings" => 3, "innings_foul_list" => [0, 0], "innings_foul_redo_list" => [0], "result" => 8, "balls_goal" => "100", "fouls_1" => 0 },
      "playerb" => { "innings_list" => [7, 1], "innings_redo_list" => [0], "innings" => 3, "innings_foul_list" => [0, 0], "innings_foul_redo_list" => [0], "result" => 8, "balls_goal" => "100", "fouls_1" => 0 }
    )
    e = engine(data)
    e.insert_inning(1, playing_or_set_over: true)
    assert_equal 4, data.dig("playera", "innings")
    assert_equal 0, data.dig("playera", "innings_list", 1), "inserted 0 at position 1"
  end

  test "insert_inning increments innings counter for both players" do
    data = playing_data(
      "playera" => { "innings_list" => [5], "innings_redo_list" => [0], "innings" => 2, "innings_foul_list" => [0], "innings_foul_redo_list" => [0], "result" => 5, "balls_goal" => "100", "fouls_1" => 0 },
      "playerb" => { "innings_list" => [3], "innings_redo_list" => [0], "innings" => 2, "innings_foul_list" => [0], "innings_foul_redo_list" => [0], "result" => 3, "balls_goal" => "100", "fouls_1" => 0 }
    )
    e = engine(data)
    e.insert_inning(0, playing_or_set_over: true)
    assert_equal 3, data.dig("playera", "innings")
    assert_equal 3, data.dig("playerb", "innings")
  end

  # ---------------------------------------------------------------------------
  # recalculate_player_stats
  # ---------------------------------------------------------------------------

  test "recalculate_player_stats updates result from innings_list" do
    data = playing_data("playera" => { "innings_list" => [10, 20], "innings_redo_list" => [5], "innings" => 3, "innings_foul_list" => [0, 0], "innings_foul_redo_list" => [0], "result" => 0, "hs" => 0, "gd" => 0.0, "balls_goal" => "100", "fouls_1" => 0 })
    e = engine(data)
    e.recalculate_player_stats("playera")
    assert_equal 30, data.dig("playera", "result")
  end

  test "recalculate_player_stats updates hs from all innings" do
    data = playing_data("playera" => { "innings_list" => [10, 20], "innings_redo_list" => [25], "innings" => 3, "innings_foul_list" => [0, 0], "innings_foul_redo_list" => [0], "result" => 0, "hs" => 0, "gd" => 0.0, "balls_goal" => "100", "fouls_1" => 0 })
    e = engine(data)
    e.recalculate_player_stats("playera")
    assert_equal 25, data.dig("playera", "hs")
  end

  # ---------------------------------------------------------------------------
  # update_player_innings_data
  # ---------------------------------------------------------------------------

  test "update_player_innings_data splits innings into list and redo" do
    data = playing_data("playera" => { "innings_list" => [], "innings_redo_list" => [0], "innings" => 3, "innings_foul_list" => [], "innings_foul_redo_list" => [0], "result" => 0, "hs" => 0, "gd" => 0.0, "balls_goal" => "100", "fouls_1" => 0 })
    e = engine(data)
    e.update_player_innings_data("playera", [5, 10, 3])
    assert_equal [5, 10], data.dig("playera", "innings_list")
    assert_equal [3], data.dig("playera", "innings_redo_list")
  end

  test "update_player_innings_data sets result from completed innings only" do
    data = playing_data("playera" => { "innings_list" => [], "innings_redo_list" => [0], "innings" => 3, "innings_foul_list" => [], "innings_foul_redo_list" => [0], "result" => 0, "hs" => 0, "gd" => 0.0, "balls_goal" => "100", "fouls_1" => 0 })
    e = engine(data)
    e.update_player_innings_data("playera", [5, 10, 3])
    assert_equal 15, data.dig("playera", "result") # only list, not redo
  end

  # ---------------------------------------------------------------------------
  # calculate_running_totals
  # ---------------------------------------------------------------------------

  test "calculate_running_totals returns cumulative sums" do
    data = playing_data("playera" => { "innings_list" => [5, 3, 10], "innings_redo_list" => [0], "innings" => 3, "innings_foul_list" => [0, 0, 0], "innings_foul_redo_list" => [0], "result" => 18, "balls_goal" => "100", "fouls_1" => 0 })
    e = engine(data)
    result = e.calculate_running_totals("playera")
    assert_equal [5, 8, 18], result
  end

  test "calculate_running_totals returns empty array when no innings" do
    data = playing_data
    e = engine(data)
    result = e.calculate_running_totals("playera")
    assert_equal [], result
  end

  # ---------------------------------------------------------------------------
  # Hash mutation by reference
  # ---------------------------------------------------------------------------

  test "hash is mutated by reference (same object, not a copy)" do
    data = playing_data
    original_object_id = data.object_id
    e = engine(data)
    e.add_n_balls(5)
    assert_equal original_object_id, data.object_id, "data hash must be the same object"
    assert_equal 5, data.dig("playera", "innings_redo_list", -1), "mutation visible on original hash"
  end

  test "multiple operations accumulate on the same hash object" do
    data = playing_data
    e = engine(data)
    e.add_n_balls(3)
    e.add_n_balls(4)
    assert_equal 7, data.dig("playera", "innings_redo_list", -1)
  end

  # ---------------------------------------------------------------------------
  # Snooker methods
  # ---------------------------------------------------------------------------

  test "initial_red_balls returns 15 for standard snooker" do
    data = snooker_data
    e = engine(data, discipline: "Snooker")
    assert_equal 15, e.initial_red_balls
  end

  test "initial_red_balls returns 6 when configured" do
    data = snooker_data("initial_red_balls" => 6)
    e = engine(data, discipline: "Snooker")
    assert_equal 6, e.initial_red_balls
  end

  test "initial_red_balls returns 15 for non-snooker game form" do
    data = playing_data
    e = engine(data)
    assert_equal 15, e.initial_red_balls
  end

  test "update_snooker_state decrements reds_remaining when red is potted" do
    data = snooker_data
    e = engine(data, discipline: "Snooker")
    e.update_snooker_state(1)
    assert_equal 14, data.dig("snooker_state", "reds_remaining")
  end

  test "update_snooker_state tracks last_potted_ball" do
    data = snooker_data
    e = engine(data, discipline: "Snooker")
    e.update_snooker_state(5)
    assert_equal 5, data.dig("snooker_state", "last_potted_ball")
  end

  test "snooker_balls_on returns hash with ball values 1-7 as keys" do
    data = snooker_data
    e = engine(data, discipline: "Snooker")
    result = e.snooker_balls_on
    assert_equal (1..7).to_a, result.keys.sort
  end

  test "snooker_balls_on returns :on for red at game start" do
    data = snooker_data
    e = engine(data, discipline: "Snooker")
    result = e.snooker_balls_on
    assert_equal :on, result[1]
  end

  test "snooker_remaining_points returns 42 at start (15 reds + 27 colors)" do
    data = snooker_data
    e = engine(data, discipline: "Snooker")
    assert_equal 42, e.snooker_remaining_points
  end

  test "snooker_remaining_points returns 0 for non-snooker game" do
    data = playing_data
    e = engine(data)
    assert_equal 0, e.snooker_remaining_points
  end

  test "undo_snooker_ball removes last ball from break and recalculates score" do
    data = snooker_data(
      "playera" => {
        "break_balls_redo_list" => [[1, 5, 7]],
        "innings_redo_list" => [13],
        "innings_list" => [],
        "innings_foul_list" => [],
        "innings_foul_redo_list" => [0],
        "result" => 0, "innings" => 0, "balls_goal" => "100", "fouls_1" => 0,
        "break_balls_list" => [], "break_fouls_list" => []
      }
    )
    e = engine(data, discipline: "Snooker")
    e.undo_snooker_ball("playera")
    assert_equal [1, 5], data.dig("playera", "break_balls_redo_list", -1)
    assert_equal 6, data.dig("playera", "innings_redo_list", -1) # 1+5
  end

  test "recalculate_snooker_state_from_protocol updates reds_remaining" do
    data = snooker_data(
      "playera" => {
        "break_balls_list" => [[1, 5, 1, 7]],
        "break_balls_redo_list" => [[]],
        "innings_redo_list" => [0], "innings_list" => [],
        "innings_foul_list" => [], "innings_foul_redo_list" => [0],
        "result" => 0, "innings" => 0, "balls_goal" => "100", "fouls_1" => 0,
        "break_fouls_list" => []
      }
    )
    e = engine(data, discipline: "Snooker")
    e.recalculate_snooker_state_from_protocol
    # 2 reds potted in break_balls_list → 15 - 2 = 13 remaining
    assert_equal 13, data.dig("snooker_state", "reds_remaining")
  end
end
