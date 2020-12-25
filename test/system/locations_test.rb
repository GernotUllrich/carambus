require "application_system_test_case"

class LocationsTest < ApplicationSystemTestCase
  setup do
    @location = locations(:one)
  end

  test "visiting the index" do
    visit locations_url
    assert_selector "h1", text: "Locations"
  end

  test "creating a Location" do
    visit locations_url
    click_on "New Location"

    fill_in "Address", with: @location.address
    fill_in "Club", with: @location.club_id
    fill_in "Data", with: @location.data
    fill_in "Name", with: @location.name
    click_on "Create Location"

    assert_text "Location was successfully created"
    assert_selector "h1", text: "Locations"
  end

  test "updating a Location" do
    visit location_url(@location)
    click_on "Edit", match: :first

    fill_in "Address", with: @location.address
    fill_in "Club", with: @location.club_id
    fill_in "Data", with: @location.data
    fill_in "Name", with: @location.name
    click_on "Update Location"

    assert_text "Location was successfully updated"
    assert_selector "h1", text: "Locations"
  end

  test "destroying a Location" do
    visit edit_location_url(@location)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Location was successfully destroyed"
  end
end
