require 'test_helper'

class PartyTournamentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @party_tournament = party_tournaments(:one)
  end

  test "should get index" do
    get party_tournaments_url
    assert_response :success
  end

  test "should get new" do
    get new_party_tournament_url
    assert_response :success
  end

  test "should create party_tournament" do
    assert_difference('PartyTournament.count') do
      post party_tournaments_url, params: { party_tournament: { party_id: @party_tournament.party_id, position: @party_tournament.position, tournament_id: @party_tournament.tournament_id } }
    end

    assert_redirected_to party_tournament_url(PartyTournament.last)
  end

  test "should show party_tournament" do
    get party_tournament_url(@party_tournament)
    assert_response :success
  end

  test "should get edit" do
    get edit_party_tournament_url(@party_tournament)
    assert_response :success
  end

  test "should update party_tournament" do
    patch party_tournament_url(@party_tournament), params: { party_tournament: { party_id: @party_tournament.party_id, position: @party_tournament.position, tournament_id: @party_tournament.tournament_id } }
    assert_redirected_to party_tournament_url(@party_tournament)
  end

  test "should destroy party_tournament" do
    assert_difference('PartyTournament.count', -1) do
      delete party_tournament_url(@party_tournament)
    end

    assert_redirected_to party_tournaments_url
  end
end
