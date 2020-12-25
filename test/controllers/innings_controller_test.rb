require 'test_helper'

class InningsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @inning = innings(:one)
  end

  test "should get index" do
    get innings_url
    assert_response :success
  end

  test "should get new" do
    get new_inning_url
    assert_response :success
  end

  test "should create inning" do
    assert_difference('Inning.count') do
      post innings_url, params: { inning: { date: @inning.date, game_id: @inning.game_id, player_a_count: @inning.player_a_count, player_b_count: @inning.player_b_count, player_c_count: @inning.player_c_count, player_d_count: @inning.player_d_count, sequence_number: @inning.sequence_number } }
    end

    assert_redirected_to inning_url(Inning.last)
  end

  test "should show inning" do
    get inning_url(@inning)
    assert_response :success
  end

  test "should get edit" do
    get edit_inning_url(@inning)
    assert_response :success
  end

  test "should update inning" do
    patch inning_url(@inning), params: { inning: { date: @inning.date, game_id: @inning.game_id, player_a_count: @inning.player_a_count, player_b_count: @inning.player_b_count, player_c_count: @inning.player_c_count, player_d_count: @inning.player_d_count, sequence_number: @inning.sequence_number } }
    assert_redirected_to inning_url(@inning)
  end

  test "should destroy inning" do
    assert_difference('Inning.count', -1) do
      delete inning_url(@inning)
    end

    assert_redirected_to innings_url
  end
end
