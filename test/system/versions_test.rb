require "application_system_test_case"

class VersionsTest < ApplicationSystemTestCase
  setup do
    @version = versions(:one)
  end

  test "visiting the index" do
    visit versions_url
    assert_selector "h1", text: "Versions"
  end

  test "creating a Version" do
    visit versions_url
    click_on "New Version"

    fill_in "Event", with: @version.event
    fill_in "Item", with: @version.item_id
    fill_in "Item type", with: @version.item_type
    fill_in "Object", with: @version.object
    fill_in "Object changes", with: @version.object_changes
    fill_in "Whodunnit", with: @version.whodunnit
    click_on "Create Version"

    assert_text "Version was successfully created"
    assert_selector "h1", text: "Versions"
  end

  test "updating a Version" do
    visit version_url(@version)
    click_on "Edit", match: :first

    fill_in "Event", with: @version.event
    fill_in "Item", with: @version.item_id
    fill_in "Item type", with: @version.item_type
    fill_in "Object", with: @version.object
    fill_in "Object changes", with: @version.object_changes
    fill_in "Whodunnit", with: @version.whodunnit
    click_on "Update Version"

    assert_text "Version was successfully updated"
    assert_selector "h1", text: "Versions"
  end

  test "destroying a Version" do
    visit edit_version_url(@version)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Version was successfully destroyed"
  end
end
