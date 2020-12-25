require "application_system_test_case"

class SettingsTest < ApplicationSystemTestCase
  setup do
    @setting = settings(:one)
  end

  test "visiting the index" do
    visit settings_url
    assert_selector "h1", text: "Settings"
  end

  test "creating a Setting" do
    visit settings_url
    click_on "New Setting"

    fill_in "Club", with: @setting.club_id
    fill_in "Data", with: @setting.data
    fill_in "Region", with: @setting.region_id
    fill_in "State", with: @setting.state
    fill_in "Tournament", with: @setting.tournament_id
    click_on "Create Setting"

    assert_text "Setting was successfully created"
    assert_selector "h1", text: "Settings"
  end

  test "updating a Setting" do
    visit setting_url(@setting)
    click_on "Edit", match: :first

    fill_in "Club", with: @setting.club_id
    fill_in "Data", with: @setting.data
    fill_in "Region", with: @setting.region_id
    fill_in "State", with: @setting.state
    fill_in "Tournament", with: @setting.tournament_id
    click_on "Update Setting"

    assert_text "Setting was successfully updated"
    assert_selector "h1", text: "Settings"
  end

  test "destroying a Setting" do
    visit edit_setting_url(@setting)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Setting was successfully destroyed"
  end
end
