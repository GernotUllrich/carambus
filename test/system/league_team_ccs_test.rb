require "application_system_test_case"

class LeagueTeamCcsTest < ApplicationSystemTestCase
  setup do
    @league_team_cc = league_team_ccs(:one)
  end

  test "visiting the index" do
    visit league_team_ccs_url
    assert_selector "h1", text: "League Team Ccs"
  end

  test "creating a League team cc" do
    visit league_team_ccs_url
    click_on "New League Team Cc"

    fill_in "Cc", with: @league_team_cc.cc_id
    fill_in "Data", with: @league_team_cc.data
    fill_in "League cc", with: @league_team_cc.league_cc_id
    fill_in "League team", with: @league_team_cc.league_team_id
    fill_in "Name", with: @league_team_cc.name
    fill_in "Shortname", with: @league_team_cc.shortname
    click_on "Create League team cc"

    assert_text "League team cc was successfully created"
    assert_selector "h1", text: "League Team Ccs"
  end

  test "updating a League team cc" do
    visit league_team_cc_url(@league_team_cc)
    click_on "Edit", match: :first

    fill_in "Cc", with: @league_team_cc.cc_id
    fill_in "Data", with: @league_team_cc.data
    fill_in "League cc", with: @league_team_cc.league_cc_id
    fill_in "League team", with: @league_team_cc.league_team_id
    fill_in "Name", with: @league_team_cc.name
    fill_in "Shortname", with: @league_team_cc.shortname
    click_on "Update League team cc"

    assert_text "League team cc was successfully updated"
    assert_selector "h1", text: "League Team Ccs"
  end

  test "destroying a League team cc" do
    visit edit_league_team_cc_url(@league_team_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "League team cc was successfully destroyed"
  end
end
