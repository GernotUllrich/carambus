require "test_helper"

class BranchCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @branch_cc = branch_ccs(:one)
  end

  test "should get index" do
    get branch_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_branch_cc_url
    assert_response :success
  end

  test "should create branch_cc" do
    assert_difference('BranchCc.count') do
      post branch_ccs_url, params: { branch_cc: { cc_id: @branch_cc.cc_id, context: @branch_cc.context, discipline_id: @branch_cc.discipline_id, name: @branch_cc.name, region_cc_id: @branch_cc.region_cc_id } }
    end

    assert_redirected_to branch_cc_url(BranchCc.last)
  end

  test "should show branch_cc" do
    get branch_cc_url(@branch_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_branch_cc_url(@branch_cc)
    assert_response :success
  end

  test "should update branch_cc" do
    patch branch_cc_url(@branch_cc), params: { branch_cc: { cc_id: @branch_cc.cc_id, context: @branch_cc.context, discipline_id: @branch_cc.discipline_id, name: @branch_cc.name, region_cc_id: @branch_cc.region_cc_id } }
    assert_redirected_to branch_cc_url(@branch_cc)
  end

  test "should destroy branch_cc" do
    assert_difference('BranchCc.count', -1) do
      delete branch_cc_url(@branch_cc)
    end

    assert_redirected_to branch_ccs_url
  end
end
