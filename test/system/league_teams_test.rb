require "application_system_test_case"

class LeagueTeamsTest < ApplicationSystemTestCase
  setup do
    @league_team = league_teams(:one)
  end

  test "visiting the index" do
    visit league_teams_url
    assert_selector "h1", text: "League Teams"
  end

  test "creating a League team" do
    visit league_teams_url
    click_on "New League Team"

    fill_in "Ba", with: @league_team.ba_id
    fill_in "Club", with: @league_team.club_id
    fill_in "League", with: @league_team.league_id
    fill_in "Name", with: @league_team.name
    fill_in "Shortname", with: @league_team.shortname
    click_on "Create League team"

    assert_text "League team was successfully created"
    assert_selector "h1", text: "League Teams"
  end

  test "updating a League team" do
    visit league_team_url(@league_team)
    click_on "Edit", match: :first

    fill_in "Ba", with: @league_team.ba_id
    fill_in "Club", with: @league_team.club_id
    fill_in "League", with: @league_team.league_id
    fill_in "Name", with: @league_team.name
    fill_in "Shortname", with: @league_team.shortname
    click_on "Update League team"

    assert_text "League team was successfully updated"
    assert_selector "h1", text: "League Teams"
  end

  test "destroying a League team" do
    visit edit_league_team_url(@league_team)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "League team was successfully destroyed"
  end
end
