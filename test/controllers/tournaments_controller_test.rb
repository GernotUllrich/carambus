require 'test_helper'

class TournamentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tournament = tournaments(:one)
  end

  test "should get index" do
    get tournaments_url
    assert_response :success
  end

  test "should get new" do
    get new_tournament_url
    assert_response :success
  end

  test "should create tournament" do
    assert_difference('Tournament.count') do
      post tournaments_url, params: { tournament: { accredation_end: @tournament.accredation_end, age_restriction: @tournament.age_restriction, ba_id: @tournament.ba_id, ba_state: @tournament.ba_state, balls_goal: @tournament.balls_goal, data: @tournament.data, date: @tournament.date, discipline_id: @tournament.discipline_id, end_date: @tournament.end_date, handicap_tournier: @tournament.handicap_tournier, hosting_club_id: @tournament.hosting_club_id, innings_goal: @tournament.innings_goal, last_ba_sync_date: @tournament.last_ba_sync_date, location: @tournament.location, modus: @tournament.modus, plan_or_show: @tournament.plan_or_show, player_class: @tournament.player_class, region_id: @tournament.region_id, season_id: @tournament.season_id, shortname: @tournament.shortname, single_or_league: @tournament.single_or_league, state: @tournament.state, title: @tournament.title, tournament_plan_id: @tournament.tournament_plan_id } }
    end

    assert_redirected_to tournament_url(Tournament.last)
  end

  test "should show tournament" do
    get tournament_url(@tournament)
    assert_response :success
  end

  test "should get edit" do
    get edit_tournament_url(@tournament)
    assert_response :success
  end

  test "should update tournament" do
    patch tournament_url(@tournament), params: { tournament: { accredation_end: @tournament.accredation_end, age_restriction: @tournament.age_restriction, ba_id: @tournament.ba_id, ba_state: @tournament.ba_state, balls_goal: @tournament.balls_goal, data: @tournament.data, date: @tournament.date, discipline_id: @tournament.discipline_id, end_date: @tournament.end_date, handicap_tournier: @tournament.handicap_tournier, hosting_club_id: @tournament.hosting_club_id, innings_goal: @tournament.innings_goal, last_ba_sync_date: @tournament.last_ba_sync_date, location: @tournament.location, modus: @tournament.modus, plan_or_show: @tournament.plan_or_show, player_class: @tournament.player_class, region_id: @tournament.region_id, season_id: @tournament.season_id, shortname: @tournament.shortname, single_or_league: @tournament.single_or_league, state: @tournament.state, title: @tournament.title, tournament_plan_id: @tournament.tournament_plan_id } }
    assert_redirected_to tournament_url(@tournament)
  end

  test "should destroy tournament" do
    assert_difference('Tournament.count', -1) do
      delete tournament_url(@tournament)
    end

    assert_redirected_to tournaments_url
  end
end
