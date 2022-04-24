require "test_helper"

class SeasonCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @season_cc = season_ccs(:one)
  end

  test "should get index" do
    get season_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_season_cc_url
    assert_response :success
  end

  test "should create season_cc" do
    assert_difference('SeasonCc.count') do
      post season_ccs_url, params: { season_cc: { cc_id: @season_cc.cc_id, competition_cc_id: @season_cc.competition_cc_id, context: @season_cc.context, name: @season_cc.name, season_id: @season_cc.season_id } }
    end

    assert_redirected_to season_cc_url(SeasonCc.last)
  end

  test "should show season_cc" do
    get season_cc_url(@season_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_season_cc_url(@season_cc)
    assert_response :success
  end

  test "should update season_cc" do
    patch season_cc_url(@season_cc), params: { season_cc: { cc_id: @season_cc.cc_id, competition_cc_id: @season_cc.competition_cc_id, context: @season_cc.context, name: @season_cc.name, season_id: @season_cc.season_id } }
    assert_redirected_to season_cc_url(@season_cc)
  end

  test "should destroy season_cc" do
    assert_difference('SeasonCc.count', -1) do
      delete season_cc_url(@season_cc)
    end

    assert_redirected_to season_ccs_url
  end
end
