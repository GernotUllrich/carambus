require "application_system_test_case"

class BranchCcsTest < ApplicationSystemTestCase
  setup do
    @branch_cc = branch_ccs(:one)
  end

  test "visiting the index" do
    visit branch_ccs_url
    assert_selector "h1", text: "Branch Ccs"
  end

  test "creating a Branch cc" do
    visit branch_ccs_url
    click_on "New Branch Cc"

    fill_in "Cc", with: @branch_cc.cc_id
    fill_in "Context", with: @branch_cc.context
    fill_in "Discipline", with: @branch_cc.discipline_id
    fill_in "Name", with: @branch_cc.name
    fill_in "Region cc", with: @branch_cc.region_cc_id
    click_on "Create Branch cc"

    assert_text "Branch cc was successfully created"
    assert_selector "h1", text: "Branch Ccs"
  end

  test "updating a Branch cc" do
    visit branch_cc_url(@branch_cc)
    click_on "Edit", match: :first

    fill_in "Cc", with: @branch_cc.cc_id
    fill_in "Context", with: @branch_cc.context
    fill_in "Discipline", with: @branch_cc.discipline_id
    fill_in "Name", with: @branch_cc.name
    fill_in "Region cc", with: @branch_cc.region_cc_id
    click_on "Update Branch cc"

    assert_text "Branch cc was successfully updated"
    assert_selector "h1", text: "Branch Ccs"
  end

  test "destroying a Branch cc" do
    visit edit_branch_cc_url(@branch_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Branch cc was successfully destroyed"
  end
end
