require 'test_helper'

class LeagueTeamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @league_team = league_teams(:one)
  end

  test "should get index" do
    get league_teams_url
    assert_response :success
  end

  test "should get new" do
    get new_league_team_url
    assert_response :success
  end

  test "should create league_team" do
    assert_difference('LeagueTeam.count') do
      post league_teams_url, params: { league_team: { ba_id: @league_team.ba_id, club_id: @league_team.club_id, league_id: @league_team.league_id, name: @league_team.name, shortname: @league_team.shortname } }
    end

    assert_redirected_to league_team_url(LeagueTeam.last)
  end

  test "should show league_team" do
    get league_team_url(@league_team)
    assert_response :success
  end

  test "should get edit" do
    get edit_league_team_url(@league_team)
    assert_response :success
  end

  test "should update league_team" do
    patch league_team_url(@league_team), params: { league_team: { ba_id: @league_team.ba_id, club_id: @league_team.club_id, league_id: @league_team.league_id, name: @league_team.name, shortname: @league_team.shortname } }
    assert_redirected_to league_team_url(@league_team)
  end

  test "should destroy league_team" do
    assert_difference('LeagueTeam.count', -1) do
      delete league_team_url(@league_team)
    end

    assert_redirected_to league_teams_url
  end
end
