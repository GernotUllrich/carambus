require "test_helper"

class GamePlanRowCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game_plan_row_cc = game_plan_row_ccs(:one)
  end

  test "should get index" do
    get game_plan_row_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_game_plan_row_cc_url
    assert_response :success
  end

  test "should create game_plan_row_cc" do
    assert_difference('GamePlanRowCc.count') do
      post game_plan_row_ccs_url, params: { game_plan_row_cc: { cc_id: @game_plan_row_cc.cc_id, discipline_id: @game_plan_row_cc.discipline_id, game_plan_id: @game_plan_row_cc.game_plan_id, home_brett: @game_plan_row_cc.home_brett, mpg: @game_plan_row_cc.mpg, pmv: @game_plan_row_cc.pmv, ppg: @game_plan_row_cc.ppg, ppu: @game_plan_row_cc.ppu, ppv: @game_plan_row_cc.ppv, score: @game_plan_row_cc.score, sets: @game_plan_row_cc.sets, visitor_brett: @game_plan_row_cc.visitor_brett } }
    end

    assert_redirected_to game_plan_row_cc_url(GamePlanRowCc.last)
  end

  test "should show game_plan_row_cc" do
    get game_plan_row_cc_url(@game_plan_row_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_game_plan_row_cc_url(@game_plan_row_cc)
    assert_response :success
  end

  test "should update game_plan_row_cc" do
    patch game_plan_row_cc_url(@game_plan_row_cc), params: { game_plan_row_cc: { cc_id: @game_plan_row_cc.cc_id, discipline_id: @game_plan_row_cc.discipline_id, game_plan_id: @game_plan_row_cc.game_plan_id, home_brett: @game_plan_row_cc.home_brett, mpg: @game_plan_row_cc.mpg, pmv: @game_plan_row_cc.pmv, ppg: @game_plan_row_cc.ppg, ppu: @game_plan_row_cc.ppu, ppv: @game_plan_row_cc.ppv, score: @game_plan_row_cc.score, sets: @game_plan_row_cc.sets, visitor_brett: @game_plan_row_cc.visitor_brett } }
    assert_redirected_to game_plan_row_cc_url(@game_plan_row_cc)
  end

  test "should destroy game_plan_row_cc" do
    assert_difference('GamePlanRowCc.count', -1) do
      delete game_plan_row_cc_url(@game_plan_row_cc)
    end

    assert_redirected_to game_plan_row_ccs_url
  end
end
