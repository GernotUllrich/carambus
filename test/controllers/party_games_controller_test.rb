require 'test_helper'

class PartyGamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @party_game = party_games(:one)
  end

  test "should get index" do
    get party_games_url
    assert_response :success
  end

  test "should get new" do
    get new_party_game_url
    assert_response :success
  end

  test "should create party_game" do
    assert_difference('PartyGame.count') do
      post party_games_url, params: { party_game: { party_id: @party_game.party_id, player_a_id: @party_game.player_a_id, player_b_id: @party_game.player_b_id, seqno: @party_game.seqno, tournament_id: @party_game.tournament_id } }
    end

    assert_redirected_to party_game_url(PartyGame.last)
  end

  test "should show party_game" do
    get party_game_url(@party_game)
    assert_response :success
  end

  test "should get edit" do
    get edit_party_game_url(@party_game)
    assert_response :success
  end

  test "should update party_game" do
    patch party_game_url(@party_game), params: { party_game: { party_id: @party_game.party_id, player_a_id: @party_game.player_a_id, player_b_id: @party_game.player_b_id, seqno: @party_game.seqno, tournament_id: @party_game.tournament_id } }
    assert_redirected_to party_game_url(@party_game)
  end

  test "should destroy party_game" do
    assert_difference('PartyGame.count', -1) do
      delete party_game_url(@party_game)
    end

    assert_redirected_to party_games_url
  end
end
