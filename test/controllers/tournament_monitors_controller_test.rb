require 'test_helper'

class TournamentMonitorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tournament_monitor = tournament_monitors(:one)
  end

  test "should get index" do
    get tournament_monitors_url
    assert_response :success
  end

  test "should get new" do
    get new_tournament_monitor_url
    assert_response :success
  end

  test "should create tournament_monitor" do
    assert_difference('TournamentMonitor.count') do
      post tournament_monitors_url, params: { tournament_monitor: { balls_goal: @tournament_monitor.balls_goal, date: @tournament_monitor.date, innings_goal: @tournament_monitor.innings_goal, state: @tournament_monitor.state, tournament_id: @tournament_monitor.tournament_id } }
    end

    assert_redirected_to tournament_monitor_url(TournamentMonitor.last)
  end

  test "should show tournament_monitor" do
    get tournament_monitor_url(@tournament_monitor)
    assert_response :success
  end

  test "should get edit" do
    get edit_tournament_monitor_url(@tournament_monitor)
    assert_response :success
  end

  test "should update tournament_monitor" do
    patch tournament_monitor_url(@tournament_monitor), params: { tournament_monitor: { balls_goal: @tournament_monitor.balls_goal, date: @tournament_monitor.date, innings_goal: @tournament_monitor.innings_goal, state: @tournament_monitor.state, tournament_id: @tournament_monitor.tournament_id } }
    assert_redirected_to tournament_monitor_url(@tournament_monitor)
  end

  test "should destroy tournament_monitor" do
    assert_difference('TournamentMonitor.count', -1) do
      delete tournament_monitor_url(@tournament_monitor)
    end

    assert_redirected_to tournament_monitors_url
  end
end
