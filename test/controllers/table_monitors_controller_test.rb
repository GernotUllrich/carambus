require 'test_helper'

class TableMonitorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @table_monitor = table_monitors(:one)
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
    assert_difference('TableMonitor.count') do
      post table_monitors_url, params: { table_monitor: { data: @table_monitor.data, game_id: @table_monitor.game_id, ip_address: @table_monitor.ip_address, name: @table_monitor.name, next_game_id: @table_monitor.next_game_id, state: @table_monitor.state, tournament_monitor_id: @table_monitor.tournament_monitor_id } }
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
    patch table_monitor_url(@table_monitor), params: { table_monitor: { data: @table_monitor.data, game_id: @table_monitor.game_id, ip_address: @table_monitor.ip_address, name: @table_monitor.name, next_game_id: @table_monitor.next_game_id, state: @table_monitor.state, tournament_monitor_id: @table_monitor.tournament_monitor_id } }
    assert_redirected_to table_monitor_url(@table_monitor)
  end

  test "should destroy table_monitor" do
    assert_difference('TableMonitor.count', -1) do
      delete table_monitor_url(@table_monitor)
    end

    assert_redirected_to table_monitors_url
  end
end
