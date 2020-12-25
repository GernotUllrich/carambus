require 'test_helper'

class SeedingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @seeding = seedings(:one)
  end

  test "should get index" do
    get seedings_url
    assert_response :success
  end

  test "should get new" do
    get new_seeding_url
    assert_response :success
  end

  test "should create seeding" do
    assert_difference('Seeding.count') do
      post seedings_url, params: { seeding: { ba_state: @seeding.ba_state, balls_goal: @seeding.balls_goal, data: @seeding.data, player_id: @seeding.player_id, playing_discipline_id: @seeding.playing_discipline_id, position: @seeding.position, state: @seeding.state, tournament_id: @seeding.tournament_id } }
    end

    assert_redirected_to seeding_url(Seeding.last)
  end

  test "should show seeding" do
    get seeding_url(@seeding)
    assert_response :success
  end

  test "should get edit" do
    get edit_seeding_url(@seeding)
    assert_response :success
  end

  test "should update seeding" do
    patch seeding_url(@seeding), params: { seeding: { ba_state: @seeding.ba_state, balls_goal: @seeding.balls_goal, data: @seeding.data, player_id: @seeding.player_id, playing_discipline_id: @seeding.playing_discipline_id, position: @seeding.position, state: @seeding.state, tournament_id: @seeding.tournament_id } }
    assert_redirected_to seeding_url(@seeding)
  end

  test "should destroy seeding" do
    assert_difference('Seeding.count', -1) do
      delete seeding_url(@seeding)
    end

    assert_redirected_to seedings_url
  end
end
