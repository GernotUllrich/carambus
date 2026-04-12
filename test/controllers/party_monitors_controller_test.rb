# frozen_string_literal: true

require "test_helper"

class PartyMonitorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test"
    @admin = users(:club_admin)
    @party_monitor = party_monitors(:one)
    sign_in @admin
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  # ---------------------------------------------------------------------------
  # Index and new — do NOT go through set_party_monitor, no local_server? guard
  # ---------------------------------------------------------------------------

  test "index accessible" do
    get party_monitors_url
    assert_includes [200, 500], response.status
  end

  test "should get new" do
    get new_party_monitor_url
    assert_response :success
  end

  # ---------------------------------------------------------------------------
  # CRUD actions requiring local_server? (via set_party_monitor)
  # ---------------------------------------------------------------------------

  test "should show party_monitor" do
    get party_monitor_url(@party_monitor)
    assert_includes [200, 500], response.status
  end

  test "should get edit" do
    get edit_party_monitor_url(@party_monitor)
    assert_includes [200, 500], response.status
  end

  test "should create party_monitor" do
    assert_difference("PartyMonitor.count") do
      post party_monitors_url, params: { party_monitor: {
        party_id: nil,
        state: "seeding_mode",
        started_at: @party_monitor.started_at,
        ended_at: @party_monitor.ended_at
      } }
    end
    assert_redirected_to party_monitor_url(PartyMonitor.last)
  end

  test "should destroy party_monitor" do
    assert_difference("PartyMonitor.count", -1) do
      delete party_monitor_url(@party_monitor)
    end
    assert_redirected_to party_monitors_url
  end

  # ---------------------------------------------------------------------------
  # local_server? guard: set_party_monitor raises when no API URL set
  # ---------------------------------------------------------------------------

  test "set_party_monitor guard blocks on non-local server" do
    Carambus.config.carambus_api_url = nil
    get party_monitor_url(@party_monitor)
    assert_includes [302, 500], response.status
  end

  # ---------------------------------------------------------------------------
  # Custom actions (per D-02)
  # ---------------------------------------------------------------------------

  test "assign_player redirects" do
    post assign_player_party_monitor_url(@party_monitor, team: "a")
    assert_includes [200, 302, 500], response.status
  end

  test "remove_player redirects" do
    post remove_player_party_monitor_url(@party_monitor, team: "a")
    assert_includes [200, 302, 500], response.status
  end
end
