require 'test_helper'

class SeasonParticipationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @season_participation = season_participations(:one)
  end

  test "should get index" do
    get season_participations_url
    assert_response :success
  end

  test "should get new" do
    get new_season_participation_url
    assert_response :success
  end

  test "should create season_participation" do
    assert_difference('SeasonParticipation.count') do
      post season_participations_url, params: { season_participation: { club_id: @season_participation.club_id, data: @season_participation.data, player_id: @season_participation.player_id, season_id: @season_participation.season_id } }
    end

    assert_redirected_to season_participation_url(SeasonParticipation.last)
  end

  test "should show season_participation" do
    get season_participation_url(@season_participation)
    assert_response :success
  end

  test "should get edit" do
    get edit_season_participation_url(@season_participation)
    assert_response :success
  end

  test "should update season_participation" do
    patch season_participation_url(@season_participation), params: { season_participation: { club_id: @season_participation.club_id, data: @season_participation.data, player_id: @season_participation.player_id, season_id: @season_participation.season_id } }
    assert_redirected_to season_participation_url(@season_participation)
  end

  test "should destroy season_participation" do
    assert_difference('SeasonParticipation.count', -1) do
      delete season_participation_url(@season_participation)
    end

    assert_redirected_to season_participations_url
  end
end
