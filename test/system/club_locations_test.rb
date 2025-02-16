require "application_system_test_case"

class ClubLocationsTest < ApplicationSystemTestCase
  setup do
    @club_location = club_locations(:one)
  end

  test "visiting the index" do
    visit club_locations_url
    assert_selector "h1", text: "Club Locations"
  end

  test "creating a Club location" do
    visit club_locations_url
    click_on "New Club Location"

    fill_in "Club", with: @club_location.club_id
    fill_in "Location", with: @club_location.location_id
    fill_in "Status", with: @club_location.status
    click_on "Create Club location"

    assert_text "Club location was successfully created"
    assert_selector "h1", text: "Club Locations"
  end

  test "updating a Club location" do
    visit club_location_url(@club_location)
    click_on "Edit", match: :first

    fill_in "Club", with: @club_location.club_id
    fill_in "Location", with: @club_location.location_id
    fill_in "Status", with: @club_location.status
    click_on "Update Club location"

    assert_text "Club location was successfully updated"
    assert_selector "h1", text: "Club Locations"
  end

  test "destroying a Club location" do
    visit edit_club_location_url(@club_location)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Club location was successfully destroyed"
  end
end
