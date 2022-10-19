require "test_helper"

class ChampionshipTypeCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @championship_type_cc = championship_type_ccs(:one)
  end

  test "should get index" do
    get championship_type_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_championship_type_cc_url
    assert_response :success
  end

  test "should create championship_type_cc" do
    assert_difference('ChampionshipTypeCc.count') do
      post championship_type_ccs_url, params: { championship_type_cc: { branch_cc_id: @championship_type_cc.branch_cc_id, cc_id: @championship_type_cc.cc_id, context: @championship_type_cc.context, name: @championship_type_cc.name, shortname: @championship_type_cc.shortname, status: @championship_type_cc.status } }
    end

    assert_redirected_to championship_type_cc_url(ChampionshipTypeCc.last)
  end

  test "should show championship_type_cc" do
    get championship_type_cc_url(@championship_type_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_championship_type_cc_url(@championship_type_cc)
    assert_response :success
  end

  test "should update championship_type_cc" do
    patch championship_type_cc_url(@championship_type_cc), params: { championship_type_cc: { branch_cc_id: @championship_type_cc.branch_cc_id, cc_id: @championship_type_cc.cc_id, context: @championship_type_cc.context, name: @championship_type_cc.name, shortname: @championship_type_cc.shortname, status: @championship_type_cc.status } }
    assert_redirected_to championship_type_cc_url(@championship_type_cc)
  end

  test "should destroy championship_type_cc" do
    assert_difference('ChampionshipTypeCc.count', -1) do
      delete championship_type_cc_url(@championship_type_cc)
    end

    assert_redirected_to championship_type_ccs_url
  end
end
