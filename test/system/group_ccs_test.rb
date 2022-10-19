require "application_system_test_case"

class GroupCcsTest < ApplicationSystemTestCase
  setup do
    @group_cc = group_ccs(:one)
  end

  test "visiting the index" do
    visit group_ccs_url
    assert_selector "h1", text: "Group Ccs"
  end

  test "creating a Group cc" do
    visit group_ccs_url
    click_on "New Group Cc"

    fill_in "Branch cc", with: @group_cc.branch_cc_id
    fill_in "Cc", with: @group_cc.cc_id
    fill_in "Context", with: @group_cc.context
    fill_in "Data", with: @group_cc.data
    fill_in "Display", with: @group_cc.display
    fill_in "Name", with: @group_cc.name
    fill_in "Status", with: @group_cc.status
    click_on "Create Group cc"

    assert_text "Group cc was successfully created"
    assert_selector "h1", text: "Group Ccs"
  end

  test "updating a Group cc" do
    visit group_cc_url(@group_cc)
    click_on "Edit", match: :first

    fill_in "Branch cc", with: @group_cc.branch_cc_id
    fill_in "Cc", with: @group_cc.cc_id
    fill_in "Context", with: @group_cc.context
    fill_in "Data", with: @group_cc.data
    fill_in "Display", with: @group_cc.display
    fill_in "Name", with: @group_cc.name
    fill_in "Status", with: @group_cc.status
    click_on "Update Group cc"

    assert_text "Group cc was successfully updated"
    assert_selector "h1", text: "Group Ccs"
  end

  test "destroying a Group cc" do
    visit edit_group_cc_url(@group_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Group cc was successfully destroyed"
  end
end
