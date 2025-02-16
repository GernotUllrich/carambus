require "test_helper"

class PartyMonitorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @party_monitor = party_monitors(:one)
  end

  test "should get index" do
    get party_monitors_url
    assert_response :success
  end

  test "should get new" do
    get new_party_monitor_url
    assert_response :success
  end

  test "should create party_monitor" do
    assert_difference("PartyMonitor.count") do
      post party_monitors_url, params: {party_monitor: {data: @party_monitor.data, ended_at: @party_monitor.ended_at, party_id: @party_monitor.party_id, started_at: @party_monitor.started_at, state: @party_monitor.state}}
    end

    assert_redirected_to party_monitor_url(PartyMonitor.last)
  end

  test "should show party_monitor" do
    get party_monitor_url(@party_monitor)
    assert_response :success
  end

  test "should get edit" do
    get edit_party_monitor_url(@party_monitor)
    assert_response :success
  end

  test "should update party_monitor" do
    patch party_monitor_url(@party_monitor), params: {party_monitor: {data: @party_monitor.data, ended_at: @party_monitor.ended_at, party_id: @party_monitor.party_id, started_at: @party_monitor.started_at, state: @party_monitor.state}}
    assert_redirected_to party_monitor_url(@party_monitor)
  end

  test "should destroy party_monitor" do
    assert_difference("PartyMonitor.count", -1) do
      delete party_monitor_url(@party_monitor)
    end

    assert_redirected_to party_monitors_url
  end
end
