require "test_helper"

class CompetitionCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @competition_cc = competition_ccs(:one)
  end

  test "should get index" do
    get competition_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_competition_cc_url
    assert_response :success
  end

  test "should create competition_cc" do
    assert_difference('CompetitionCc.count') do
      post competition_ccs_url, params: { competition_cc: { branch_cc_id: @competition_cc.branch_cc_id, cc_id: @competition_cc.cc_id, context: @competition_cc.context, discipline_id: @competition_cc.discipline_id, name: @competition_cc.name } }
    end

    assert_redirected_to competition_cc_url(CompetitionCc.last)
  end

  test "should show competition_cc" do
    get competition_cc_url(@competition_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_competition_cc_url(@competition_cc)
    assert_response :success
  end

  test "should update competition_cc" do
    patch competition_cc_url(@competition_cc), params: { competition_cc: { branch_cc_id: @competition_cc.branch_cc_id, cc_id: @competition_cc.cc_id, context: @competition_cc.context, discipline_id: @competition_cc.discipline_id, name: @competition_cc.name } }
    assert_redirected_to competition_cc_url(@competition_cc)
  end

  test "should destroy competition_cc" do
    assert_difference('CompetitionCc.count', -1) do
      delete competition_cc_url(@competition_cc)
    end

    assert_redirected_to competition_ccs_url
  end
end
