require "test_helper"

class LeagueCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @league_cc = league_ccs(:one)
  end

  test "should get index" do
    get league_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_league_cc_url
    assert_response :success
  end

  test "should create league_cc" do
    assert_difference('LeagueCc.count') do
      post league_ccs_url, params: { league_cc: { cc_id: @league_cc.cc_id, context: @league_cc.context, name: @league_cc.name, season_cc_id: @league_cc.season_cc_id } }
    end

    assert_redirected_to league_cc_url(LeagueCc.last)
  end

  test "should show league_cc" do
    get league_cc_url(@league_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_league_cc_url(@league_cc)
    assert_response :success
  end

  test "should update league_cc" do
    patch league_cc_url(@league_cc), params: { league_cc: { cc_id: @league_cc.cc_id, context: @league_cc.context, name: @league_cc.name, season_cc_id: @league_cc.season_cc_id } }
    assert_redirected_to league_cc_url(@league_cc)
  end

  test "should destroy league_cc" do
    assert_difference('LeagueCc.count', -1) do
      delete league_cc_url(@league_cc)
    end

    assert_redirected_to league_ccs_url
  end
end
