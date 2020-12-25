require "application_system_test_case"

class SeasonsTest < ApplicationSystemTestCase
  setup do
    @season = seasons(:one)
  end

  test "visiting the index" do
    visit seasons_url
    assert_selector "h1", text: "Seasons"
  end

  test "creating a Season" do
    visit seasons_url
    click_on "New Season"

    fill_in "Ba", with: @season.ba_id
    fill_in "Data", with: @season.data
    fill_in "Name", with: @season.name
    click_on "Create Season"

    assert_text "Season was successfully created"
    assert_selector "h1", text: "Seasons"
  end

  test "updating a Season" do
    visit season_url(@season)
    click_on "Edit", match: :first

    fill_in "Ba", with: @season.ba_id
    fill_in "Data", with: @season.data
    fill_in "Name", with: @season.name
    click_on "Update Season"

    assert_text "Season was successfully updated"
    assert_selector "h1", text: "Seasons"
  end

  test "destroying a Season" do
    visit edit_season_url(@season)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Season was successfully destroyed"
  end
end
