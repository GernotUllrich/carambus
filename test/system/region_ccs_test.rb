require "application_system_test_case"

class RegionCcsTest < ApplicationSystemTestCase
  setup do
    @region_cc = region_ccs(:one)
  end

  test "visiting the index" do
    visit region_ccs_url
    assert_selector "h1", text: "Region Ccs"
  end

  test "creating a Region cc" do
    visit region_ccs_url
    click_on "New Region Cc"

    fill_in "Cc", with: @region_cc.cc_id
    fill_in "Context", with: @region_cc.context
    fill_in "Name", with: @region_cc.name
    fill_in "Region", with: @region_cc.region_id
    fill_in "Shortname", with: @region_cc.shortname
    click_on "Create Region cc"

    assert_text "Region cc was successfully created"
    assert_selector "h1", text: "Region Ccs"
  end

  test "updating a Region cc" do
    visit region_cc_url(@region_cc)
    click_on "Edit", match: :first

    fill_in "Cc", with: @region_cc.cc_id
    fill_in "Context", with: @region_cc.context
    fill_in "Name", with: @region_cc.name
    fill_in "Region", with: @region_cc.region_id
    fill_in "Shortname", with: @region_cc.shortname
    click_on "Update Region cc"

    assert_text "Region cc was successfully updated"
    assert_selector "h1", text: "Region Ccs"
  end

  test "destroying a Region cc" do
    visit edit_region_cc_url(@region_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Region cc was successfully destroyed"
  end
end
