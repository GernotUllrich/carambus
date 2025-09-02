require "test_helper"

class TableMonitorsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @table_monitor = table_monitors(:one)
    @user = users(:one)
    sign_in @user
  end

  test "should get index" do
    get table_monitors_url
    assert_response :success
  end

  test "should get new" do
    get new_table_monitor_url
    assert_response :success
  end

  test "should create table_monitor" do
    assert_difference("TableMonitor.count") do
      post table_monitors_url, params: { table_monitor: { tournament_monitor_id: @table_monitor.tournament_monitor_id, state: @table_monitor.state, name: @table_monitor.name, game_id: @table_monitor.game_id, next_game_id: @table_monitor.next_game_id, data: @table_monitor.data, ip_address: @table_monitor.ip_address, player_a_id: @table_monitor.player_a_id, player_b_id: @table_monitor.player_b_id, balls_goal: @table_monitor.balls_goal, balls_goal_a: @table_monitor.balls_goal_a, balls_goal_b: @table_monitor.balls_goal_b, discipline: @table_monitor.discipline, discipline_a: @table_monitor.discipline_a, discipline_b: @table_monitor.discipline_b, innings_goal: @table_monitor.innings_goal, timeout: @table_monitor.timeout, timeouts: @table_monitor.timeouts, kickoff_switches_with: @table_monitor.kickoff_switches_with, fixed_display_left: @table_monitor.fixed_display_left, color_remains_with_set: @table_monitor.color_remains_with_set, balls_on_table: @table_monitor.balls_on_table, allow_overflow: @table_monitor.allow_overflow, allow_follow_up: @table_monitor.allow_follow_up, toggle_dark_mode: @table_monitor.toggle_dark_mode } }
    end

    assert_redirected_to table_monitor_url(TableMonitor.last)
  end

  test "should show table_monitor" do
    get table_monitor_url(@table_monitor)
    assert_response :success
  end

  test "should get edit" do
    get edit_table_monitor_url(@table_monitor)
    assert_response :success
  end

  test "should update table_monitor" do
    patch table_monitor_url(@table_monitor), params: { table_monitor: { tournament_monitor_id: @table_monitor.tournament_monitor_id, state: @table_monitor.state, name: @table_monitor.name, game_id: @table_monitor.game_id, next_game_id: @table_monitor.next_game_id, data: @table_monitor.data, ip_address: @table_monitor.ip_address, player_a_id: @table_monitor.player_a_id, player_b_id: @table_monitor.player_b_id, balls_goal: @table_monitor.balls_goal, balls_goal_a: @table_monitor.balls_goal_a, balls_goal_b: @table_monitor.balls_goal_b, discipline: @table_monitor.discipline, discipline_a: @table_monitor.discipline_a, discipline_b: @table_monitor.discipline_b, innings_goal: @table_monitor.innings_goal, timeout: @table_monitor.timeout, timeouts: @table_monitor.timeouts, kickoff_switches_with: @table_monitor.kickoff_switches_with, fixed_display_left: @table_monitor.fixed_display_left, color_remains_with_set: @table_monitor.color_remains_with_set, balls_on_table: @table_monitor.balls_on_table, allow_overflow: @table_monitor.allow_overflow, allow_follow_up: @table_monitor.allow_follow_up, toggle_dark_mode: @table_monitor.toggle_dark_mode } }
    assert_redirected_to table_monitor_url(@table_monitor)
  end

  test "should destroy table_monitor" do
    assert_difference("TableMonitor.count", -1) do
      delete table_monitor_url(@table_monitor)
    end

    assert_redirected_to table_monitors_url
  end

  # Test optimistic scoreboard updates
  test "should handle optimistic score updates" do
    # Simulate a score update request
    assert_enqueued_with(job: TableMonitorValidationJob) do
      post "/reflex", params: {
        reflex: "TableMonitor#key_a",
        id: @table_monitor.id
      }
    end
  end

  test "should handle optimistic player changes" do
    # Simulate a player change request
    assert_enqueued_with(job: TableMonitorValidationJob) do
      post "/reflex", params: {
        reflex: "TableMonitor#next_step",
        id: @table_monitor.id
      }
    end
  end

  test "should queue background validation for score updates" do
    assert_enqueued_with(job: TableMonitorValidationJob) do
      post "/reflex", params: {
        reflex: "TableMonitor#add_n",
        n: 5,
        id: @table_monitor.id
      }
    end
  end
end

