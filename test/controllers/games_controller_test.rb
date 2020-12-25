require 'test_helper'

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game = games(:one)
  end

  test "should get index" do
    get games_url
    assert_response :success
  end

  test "should get new" do
    get new_game_url
    assert_response :success
  end

  test "should create game" do
    assert_difference('Game.count') do
      post games_url, params: { game: { data: @game.data, ended_at: @game.ended_at, gname: @game.gname, group_no: @game.group_no, roles: @game.roles, round_no: @game.round_no, seqno: @game.seqno, started_at: @game.started_at, table_no: @game.table_no, template_game_id: @game.template_game_id, tournament_id: @game.tournament_id } }
    end

    assert_redirected_to game_url(Game.last)
  end

  test "should show game" do
    get game_url(@game)
    assert_response :success
  end

  test "should get edit" do
    get edit_game_url(@game)
    assert_response :success
  end

  test "should update game" do
    patch game_url(@game), params: { game: { data: @game.data, ended_at: @game.ended_at, gname: @game.gname, group_no: @game.group_no, roles: @game.roles, round_no: @game.round_no, seqno: @game.seqno, started_at: @game.started_at, table_no: @game.table_no, template_game_id: @game.template_game_id, tournament_id: @game.tournament_id } }
    assert_redirected_to game_url(@game)
  end

  test "should destroy game" do
    assert_difference('Game.count', -1) do
      delete game_url(@game)
    end

    assert_redirected_to games_url
  end
end
