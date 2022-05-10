require "test_helper"

class GamePlanCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @game_plan_cc = game_plan_ccs(:one)
  end

  test "should get index" do
    get game_plan_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_game_plan_cc_url
    assert_response :success
  end

  test "should create game_plan_cc" do
    assert_difference('GamePlanCc.count') do
      post game_plan_ccs_url, params: { game_plan_cc: { bez_brett: @game_plan_cc.bez_brett, branch_cc_id: @game_plan_cc.branch_cc_id, cc_id: @game_plan_cc.cc_id, data: @game_plan_cc.data, discipline_id: @game_plan_cc.discipline_id, ersatzspieler_regel: @game_plan_cc.ersatzspieler_regel, mb_draw: @game_plan_cc.mb_draw, mp_lost: @game_plan_cc.mp_lost, mp_won: @game_plan_cc.mp_won, name: @game_plan_cc.name, pez_partie: @game_plan_cc.pez_partie, plausi: @game_plan_cc.plausi, rang_kegel: @game_plan_cc.rang_kegel, rang_mgd: @game_plan_cc.rang_mgd, rang_partie: @game_plan_cc.rang_partie, row_type_id: @game_plan_cc.row_type_id, vorgabe: @game_plan_cc.vorgabe, znp: @game_plan_cc.znp } }
    end

    assert_redirected_to game_plan_cc_url(GamePlanCc.last)
  end

  test "should show game_plan_cc" do
    get game_plan_cc_url(@game_plan_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_game_plan_cc_url(@game_plan_cc)
    assert_response :success
  end

  test "should update game_plan_cc" do
    patch game_plan_cc_url(@game_plan_cc), params: { game_plan_cc: { bez_brett: @game_plan_cc.bez_brett, branch_cc_id: @game_plan_cc.branch_cc_id, cc_id: @game_plan_cc.cc_id, data: @game_plan_cc.data, discipline_id: @game_plan_cc.discipline_id, ersatzspieler_regel: @game_plan_cc.ersatzspieler_regel, mb_draw: @game_plan_cc.mb_draw, mp_lost: @game_plan_cc.mp_lost, mp_won: @game_plan_cc.mp_won, name: @game_plan_cc.name, pez_partie: @game_plan_cc.pez_partie, plausi: @game_plan_cc.plausi, rang_kegel: @game_plan_cc.rang_kegel, rang_mgd: @game_plan_cc.rang_mgd, rang_partie: @game_plan_cc.rang_partie, row_type_id: @game_plan_cc.row_type_id, vorgabe: @game_plan_cc.vorgabe, znp: @game_plan_cc.znp } }
    assert_redirected_to game_plan_cc_url(@game_plan_cc)
  end

  test "should destroy game_plan_cc" do
    assert_difference('GamePlanCc.count', -1) do
      delete game_plan_cc_url(@game_plan_cc)
    end

    assert_redirected_to game_plan_ccs_url
  end
end
