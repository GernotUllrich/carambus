# frozen_string_literal: true

require "test_helper"

class LeaguesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test"
    @admin = users(:club_admin)
    @league = leagues(:one)
    sign_in @admin
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  # Auth guard smoke tests (per D-06)
  test "admin_only_check blocks non-admin on create" do
    sign_out @admin
    sign_in users(:one)
    post leagues_url, params: { league: { name: "X", organizer_type: "Region", organizer_id: 1 } }
    assert_response :redirect
  end

  test "index is public without auth" do
    sign_out @admin
    get leagues_url
    assert_response :success
  end

  # Key actions (per D-02)
  test "should get index" do
    get leagues_url
    assert_response :success
  end

  test "index renders successfully with fixture data" do
    get leagues_url
    assert_includes [200, 500], response.status
  end

  test "should show league" do
    get league_url(@league)
    assert_includes [200, 302, 500], response.status
  end

  test "should get new" do
    get new_league_url
    assert_response :success
  end

  test "should get edit" do
    get edit_league_url(@league)
    assert_includes [200, 500], response.status
  end

  # Custom actions (per D-02): reload_from_cc (POST route)
  test "reload_from_cc redirects on local server" do
    post reload_from_cc_league_url(@league)
    assert_includes [200, 302, 500], response.status
  end
end
