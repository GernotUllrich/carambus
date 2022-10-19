require "application_system_test_case"

class CategoryCcsTest < ApplicationSystemTestCase
  setup do
    @category_cc = category_ccs(:one)
  end

  test "visiting the index" do
    visit category_ccs_url
    assert_selector "h1", text: "Category Ccs"
  end

  test "creating a Category cc" do
    visit category_ccs_url
    click_on "New Category Cc"

    fill_in "Branch cc", with: @category_cc.branch_cc_id
    fill_in "Cc", with: @category_cc.cc_id
    fill_in "Context", with: @category_cc.context
    fill_in "Max age", with: @category_cc.max_age
    fill_in "Min age", with: @category_cc.min_age
    fill_in "Name", with: @category_cc.name
    fill_in "Sex", with: @category_cc.sex
    fill_in "Status", with: @category_cc.status
    click_on "Create Category cc"

    assert_text "Category cc was successfully created"
    assert_selector "h1", text: "Category Ccs"
  end

  test "updating a Category cc" do
    visit category_cc_url(@category_cc)
    click_on "Edit", match: :first

    fill_in "Branch cc", with: @category_cc.branch_cc_id
    fill_in "Cc", with: @category_cc.cc_id
    fill_in "Context", with: @category_cc.context
    fill_in "Max age", with: @category_cc.max_age
    fill_in "Min age", with: @category_cc.min_age
    fill_in "Name", with: @category_cc.name
    fill_in "Sex", with: @category_cc.sex
    fill_in "Status", with: @category_cc.status
    click_on "Update Category cc"

    assert_text "Category cc was successfully updated"
    assert_selector "h1", text: "Category Ccs"
  end

  test "destroying a Category cc" do
    visit edit_category_cc_url(@category_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Category cc was successfully destroyed"
  end
end
