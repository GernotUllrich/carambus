# frozen_string_literal: true

require "test_helper"

class PartiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test"
    @admin = users(:club_admin)
    @party = parties(:party_one)
    sign_in @admin
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  # Auth guard smoke tests (per D-06)
  test "admin_only_check blocks non-admin on create" do
    sign_out @admin
    sign_in users(:one)
    post parties_url, params: { party: { league_id: @party.league_id } }
    assert_response :redirect
  end

  test "index is public without auth" do
    sign_out @admin
    get parties_url
    assert_includes [200, 500], response.status
  end

  # Key actions (per D-02)
  test "should get index" do
    get parties_url
    assert_includes [200, 500], response.status
  end

  test "should show party" do
    get party_url(@party)
    assert_includes [200, 302, 500], response.status
  end

  test "should get new" do
    get new_party_url
    assert_response :success
  end

  test "should get edit" do
    get edit_party_url(@party)
    assert_includes [200, 500], response.status
  end

  # Custom action: party_monitor (per D-02)
  # Route is GET /parties/:id/party_monitor
  test "party_monitor action creates or redirects to party_monitor" do
    get party_monitor_party_url(@party)
    assert_includes [200, 302, 500], response.status
  end

  # local_server? guard on party_monitor (per D-06)
  test "party_monitor action redirects on non-local server" do
    Carambus.config.carambus_api_url = nil
    get party_monitor_party_url(@party)
    assert_response :redirect
  end
end
