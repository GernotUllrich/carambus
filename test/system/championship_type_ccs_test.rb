require "application_system_test_case"

class ChampionshipTypeCcsTest < ApplicationSystemTestCase
  setup do
    @championship_type_cc = championship_type_ccs(:one)
  end

  test "visiting the index" do
    visit championship_type_ccs_url
    assert_selector "h1", text: "Championship Type Ccs"
  end

  test "creating a Championship type cc" do
    visit championship_type_ccs_url
    click_on "New Championship Type Cc"

    fill_in "Branch cc", with: @championship_type_cc.branch_cc_id
    fill_in "Cc", with: @championship_type_cc.cc_id
    fill_in "Context", with: @championship_type_cc.context
    fill_in "Name", with: @championship_type_cc.name
    fill_in "Shortname", with: @championship_type_cc.shortname
    fill_in "Status", with: @championship_type_cc.status
    click_on "Create Championship type cc"

    assert_text "Championship type cc was successfully created"
    assert_selector "h1", text: "Championship Type Ccs"
  end

  test "updating a Championship type cc" do
    visit championship_type_cc_url(@championship_type_cc)
    click_on "Edit", match: :first

    fill_in "Branch cc", with: @championship_type_cc.branch_cc_id
    fill_in "Cc", with: @championship_type_cc.cc_id
    fill_in "Context", with: @championship_type_cc.context
    fill_in "Name", with: @championship_type_cc.name
    fill_in "Shortname", with: @championship_type_cc.shortname
    fill_in "Status", with: @championship_type_cc.status
    click_on "Update Championship type cc"

    assert_text "Championship type cc was successfully updated"
    assert_selector "h1", text: "Championship Type Ccs"
  end

  test "destroying a Championship type cc" do
    visit edit_championship_type_cc_url(@championship_type_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Championship type cc was successfully destroyed"
  end
end
