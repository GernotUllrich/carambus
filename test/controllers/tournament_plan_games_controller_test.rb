require 'test_helper'

class TournamentPlanGamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tournament_plan_game = tournament_plan_games(:one)
  end

  test "should get index" do
    get tournament_plan_games_url
    assert_response :success
  end

  test "should get new" do
    get new_tournament_plan_game_url
    assert_response :success
  end

  test "should create tournament_plan_game" do
    assert_difference('TournamentPlanGame.count') do
      post tournament_plan_games_url, params: { tournament_plan_game: { data: @tournament_plan_game.data, name: @tournament_plan_game.name, tournament_plan_id: @tournament_plan_game.tournament_plan_id } }
    end

    assert_redirected_to tournament_plan_game_url(TournamentPlanGame.last)
  end

  test "should show tournament_plan_game" do
    get tournament_plan_game_url(@tournament_plan_game)
    assert_response :success
  end

  test "should get edit" do
    get edit_tournament_plan_game_url(@tournament_plan_game)
    assert_response :success
  end

  test "should update tournament_plan_game" do
    patch tournament_plan_game_url(@tournament_plan_game), params: { tournament_plan_game: { data: @tournament_plan_game.data, name: @tournament_plan_game.name, tournament_plan_id: @tournament_plan_game.tournament_plan_id } }
    assert_redirected_to tournament_plan_game_url(@tournament_plan_game)
  end

  test "should destroy tournament_plan_game" do
    assert_difference('TournamentPlanGame.count', -1) do
      delete tournament_plan_game_url(@tournament_plan_game)
    end

    assert_redirected_to tournament_plan_games_url
  end
end
