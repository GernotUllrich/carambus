require "test_helper"

class TournamentCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tournament_cc = tournament_ccs(:one)
  end

  test "should get index" do
    get tournament_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_tournament_cc_url
    assert_response :success
  end

  test "should create tournament_cc" do
    assert_difference('TournamentCc.count') do
      post tournament_ccs_url, params: { tournament_cc: { branch_cc_id: @tournament_cc.branch_cc_id, category_cc_id: @tournament_cc.category_cc_id, cc_id: @tournament_cc.cc_id, championship_type_cc_id: @tournament_cc.championship_type_cc_id, context: @tournament_cc.context, description: @tournament_cc.description, discipline_id: @tournament_cc.discipline_id, entry_fee: @tournament_cc.entry_fee, flowchart: @tournament_cc.flowchart, group_cc_id: @tournament_cc.group_cc_id, league_climber_quote: @tournament_cc.league_climber_quote, location_id: @tournament_cc.location_id, location_text: @tournament_cc.location_text, max_players: @tournament_cc.max_players, name: @tournament_cc.name, poster: @tournament_cc.poster, ranking_list: @tournament_cc.ranking_list, registration_list_cc_id: @tournament_cc.registration_list_cc_id, registration_rule: @tournament_cc.registration_rule, season: @tournament_cc.season, shortname: @tournament_cc.shortname, starting_at: @tournament_cc.starting_at, status: @tournament_cc.status, successor_list: @tournament_cc.successor_list, tender: @tournament_cc.tender, tournament_end: @tournament_cc.tournament_end, tournament_series_cc_id: @tournament_cc.tournament_series_cc_id, tournament_start: @tournament_cc.tournament_start } }
    end

    assert_redirected_to tournament_cc_url(TournamentCc.last)
  end

  test "should show tournament_cc" do
    get tournament_cc_url(@tournament_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_tournament_cc_url(@tournament_cc)
    assert_response :success
  end

  test "should update tournament_cc" do
    patch tournament_cc_url(@tournament_cc), params: { tournament_cc: { branch_cc_id: @tournament_cc.branch_cc_id, category_cc_id: @tournament_cc.category_cc_id, cc_id: @tournament_cc.cc_id, championship_type_cc_id: @tournament_cc.championship_type_cc_id, context: @tournament_cc.context, description: @tournament_cc.description, discipline_id: @tournament_cc.discipline_id, entry_fee: @tournament_cc.entry_fee, flowchart: @tournament_cc.flowchart, group_cc_id: @tournament_cc.group_cc_id, league_climber_quote: @tournament_cc.league_climber_quote, location_id: @tournament_cc.location_id, location_text: @tournament_cc.location_text, max_players: @tournament_cc.max_players, name: @tournament_cc.name, poster: @tournament_cc.poster, ranking_list: @tournament_cc.ranking_list, registration_list_cc_id: @tournament_cc.registration_list_cc_id, registration_rule: @tournament_cc.registration_rule, season: @tournament_cc.season, shortname: @tournament_cc.shortname, starting_at: @tournament_cc.starting_at, status: @tournament_cc.status, successor_list: @tournament_cc.successor_list, tender: @tournament_cc.tender, tournament_end: @tournament_cc.tournament_end, tournament_series_cc_id: @tournament_cc.tournament_series_cc_id, tournament_start: @tournament_cc.tournament_start } }
    assert_redirected_to tournament_cc_url(@tournament_cc)
  end

  test "should destroy tournament_cc" do
    assert_difference('TournamentCc.count', -1) do
      delete tournament_cc_url(@tournament_cc)
    end

    assert_redirected_to tournament_ccs_url
  end
end
