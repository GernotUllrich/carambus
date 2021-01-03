require 'test_helper'

class TTournamentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @t_tournament = t_tournaments(:one)
  end

  test "should get index" do
    get t_tournaments_url
    assert_response :success
  end

  test "should get new" do
    get new_t_tournament_url
    assert_response :success
  end

  test "should create t_tournament" do
    assert_difference('TTournament.count') do
      post t_tournaments_url, params: { t_tournament: {  } }
    end

    assert_redirected_to t_tournament_url(TTournament.last)
  end

  test "should show t_tournament" do
    get t_tournament_url(@t_tournament)
    assert_response :success
  end

  test "should get edit" do
    get edit_t_tournament_url(@t_tournament)
    assert_response :success
  end

  test "should update t_tournament" do
    patch t_tournament_url(@t_tournament), params: { t_tournament: {  } }
    assert_redirected_to t_tournament_url(@t_tournament)
  end

  test "should destroy t_tournament" do
    assert_difference('TTournament.count', -1) do
      delete t_tournament_url(@t_tournament)
    end

    assert_redirected_to t_tournaments_url
  end
end
