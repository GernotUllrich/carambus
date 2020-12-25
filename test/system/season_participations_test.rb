require "application_system_test_case"

class SeasonParticipationsTest < ApplicationSystemTestCase
  setup do
    @season_participation = season_participations(:one)
  end

  test "visiting the index" do
    visit season_participations_url
    assert_selector "h1", text: "Season Participations"
  end

  test "creating a Season participation" do
    visit season_participations_url
    click_on "New Season Participation"

    fill_in "Club", with: @season_participation.club_id
    fill_in "Data", with: @season_participation.data
    fill_in "Player", with: @season_participation.player_id
    fill_in "Season", with: @season_participation.season_id
    click_on "Create Season participation"

    assert_text "Season participation was successfully created"
    assert_selector "h1", text: "Season Participations"
  end

  test "updating a Season participation" do
    visit season_participation_url(@season_participation)
    click_on "Edit", match: :first

    fill_in "Club", with: @season_participation.club_id
    fill_in "Data", with: @season_participation.data
    fill_in "Player", with: @season_participation.player_id
    fill_in "Season", with: @season_participation.season_id
    click_on "Update Season participation"

    assert_text "Season participation was successfully updated"
    assert_selector "h1", text: "Season Participations"
  end

  test "destroying a Season participation" do
    visit edit_season_participation_url(@season_participation)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Season participation was successfully destroyed"
  end
end
