require "application_system_test_case"

class LeagueCcsTest < ApplicationSystemTestCase
  setup do
    @league_cc = league_ccs(:one)
  end

  test "visiting the index" do
    visit league_ccs_url
    assert_selector "h1", text: "League Ccs"
  end

  test "creating a League cc" do
    visit league_ccs_url
    click_on "New League Cc"

    fill_in "Cc", with: @league_cc.cc_id
    fill_in "Context", with: @league_cc.context
    fill_in "Name", with: @league_cc.name
    fill_in "Season cc", with: @league_cc.season_cc_id
    click_on "Create League cc"

    assert_text "League cc was successfully created"
    assert_selector "h1", text: "League Ccs"
  end

  test "updating a League cc" do
    visit league_cc_url(@league_cc)
    click_on "Edit", match: :first

    fill_in "Cc", with: @league_cc.cc_id
    fill_in "Context", with: @league_cc.context
    fill_in "Name", with: @league_cc.name
    fill_in "Season cc", with: @league_cc.season_cc_id
    click_on "Update League cc"

    assert_text "League cc was successfully updated"
    assert_selector "h1", text: "League Ccs"
  end

  test "destroying a League cc" do
    visit edit_league_cc_url(@league_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "League cc was successfully destroyed"
  end
end
