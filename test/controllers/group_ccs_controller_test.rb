require "test_helper"

class GroupCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @group_cc = group_ccs(:one)
  end

  test "should get index" do
    get group_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_group_cc_url
    assert_response :success
  end

  test "should create group_cc" do
    assert_difference('GroupCc.count') do
      post group_ccs_url, params: { group_cc: { branch_cc_id: @group_cc.branch_cc_id, cc_id: @group_cc.cc_id, context: @group_cc.context, data: @group_cc.data, display: @group_cc.display, name: @group_cc.name, status: @group_cc.status } }
    end

    assert_redirected_to group_cc_url(GroupCc.last)
  end

  test "should show group_cc" do
    get group_cc_url(@group_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_group_cc_url(@group_cc)
    assert_response :success
  end

  test "should update group_cc" do
    patch group_cc_url(@group_cc), params: { group_cc: { branch_cc_id: @group_cc.branch_cc_id, cc_id: @group_cc.cc_id, context: @group_cc.context, data: @group_cc.data, display: @group_cc.display, name: @group_cc.name, status: @group_cc.status } }
    assert_redirected_to group_cc_url(@group_cc)
  end

  test "should destroy group_cc" do
    assert_difference('GroupCc.count', -1) do
      delete group_cc_url(@group_cc)
    end

    assert_redirected_to group_ccs_url
  end
end
