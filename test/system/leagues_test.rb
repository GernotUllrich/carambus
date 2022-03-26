require "application_system_test_case"

class LeaguesTest < ApplicationSystemTestCase
  setup do
    @league = leagues(:one)
  end

  test "visiting the index" do
    visit leagues_url
    assert_selector "h1", text: "Leagues"
  end

  test "creating a League" do
    visit leagues_url
    click_on "New League"

    fill_in "Ba", with: @league.ba_id
    fill_in "Ba id2", with: @league.ba_id2
    fill_in "Discipline", with: @league.discipline_id
    fill_in "Name", with: @league.name
    fill_in "Organizer", with: @league.organizer_id
    fill_in "Organizer type", with: @league.organizer_type
    fill_in "Registration until", with: @league.registration_until
    fill_in "Season", with: @league.season_id
    click_on "Create League"

    assert_text "League was successfully created"
    assert_selector "h1", text: "Leagues"
  end

  test "updating a League" do
    visit league_url(@league)
    click_on "Edit", match: :first

    fill_in "Ba", with: @league.ba_id
    fill_in "Ba id2", with: @league.ba_id2
    fill_in "Discipline", with: @league.discipline_id
    fill_in "Name", with: @league.name
    fill_in "Organizer", with: @league.organizer_id
    fill_in "Organizer type", with: @league.organizer_type
    fill_in "Registration until", with: @league.registration_until
    fill_in "Season", with: @league.season_id
    click_on "Update League"

    assert_text "League was successfully updated"
    assert_selector "h1", text: "Leagues"
  end

  test "destroying a League" do
    visit edit_league_url(@league)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "League was successfully destroyed"
  end
end
