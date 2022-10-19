require "test_helper"

class DisciplineCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @discipline_cc = discipline_ccs(:one)
  end

  test "should get index" do
    get discipline_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_discipline_cc_url
    assert_response :success
  end

  test "should create discipline_cc" do
    assert_difference('DisciplineCc.count') do
      post discipline_ccs_url, params: { discipline_cc: { branch_cc_id: @discipline_cc.branch_cc_id, cc_id: @discipline_cc.cc_id, context: @discipline_cc.context, discipline_id: @discipline_cc.discipline_id, name: @discipline_cc.name } }
    end

    assert_redirected_to discipline_cc_url(DisciplineCc.last)
  end

  test "should show discipline_cc" do
    get discipline_cc_url(@discipline_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_discipline_cc_url(@discipline_cc)
    assert_response :success
  end

  test "should update discipline_cc" do
    patch discipline_cc_url(@discipline_cc), params: { discipline_cc: { branch_cc_id: @discipline_cc.branch_cc_id, cc_id: @discipline_cc.cc_id, context: @discipline_cc.context, discipline_id: @discipline_cc.discipline_id, name: @discipline_cc.name } }
    assert_redirected_to discipline_cc_url(@discipline_cc)
  end

  test "should destroy discipline_cc" do
    assert_difference('DisciplineCc.count', -1) do
      delete discipline_cc_url(@discipline_cc)
    end

    assert_redirected_to discipline_ccs_url
  end
end
