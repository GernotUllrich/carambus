require "test_helper"

class LeagueTeamCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @league_team_cc = league_team_ccs(:one)
  end

  test "should get index" do
    get league_team_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_league_team_cc_url
    assert_response :success
  end

  test "should create league_team_cc" do
    assert_difference('LeagueTeamCc.count') do
      post league_team_ccs_url, params: { league_team_cc: { cc_id: @league_team_cc.cc_id, data: @league_team_cc.data, league_cc_id: @league_team_cc.league_cc_id, league_team_id: @league_team_cc.league_team_id, name: @league_team_cc.name, shortname: @league_team_cc.shortname } }
    end

    assert_redirected_to league_team_cc_url(LeagueTeamCc.last)
  end

  test "should show league_team_cc" do
    get league_team_cc_url(@league_team_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_league_team_cc_url(@league_team_cc)
    assert_response :success
  end

  test "should update league_team_cc" do
    patch league_team_cc_url(@league_team_cc), params: { league_team_cc: { cc_id: @league_team_cc.cc_id, data: @league_team_cc.data, league_cc_id: @league_team_cc.league_cc_id, league_team_id: @league_team_cc.league_team_id, name: @league_team_cc.name, shortname: @league_team_cc.shortname } }
    assert_redirected_to league_team_cc_url(@league_team_cc)
  end

  test "should destroy league_team_cc" do
    assert_difference('LeagueTeamCc.count', -1) do
      delete league_team_cc_url(@league_team_cc)
    end

    assert_redirected_to league_team_ccs_url
  end
end
