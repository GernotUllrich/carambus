require "application_system_test_case"

class MetaMapsTest < ApplicationSystemTestCase
  setup do
    @meta_map = meta_maps(:one)
  end

  test "visiting the index" do
    visit meta_maps_url
    assert_selector "h1", text: "Meta Maps"
  end

  test "creating a Meta map" do
    visit meta_maps_url
    click_on "New Meta Map"

    fill_in "Ba base url", with: @meta_map.ba_base_url
    fill_in "Cc base url", with: @meta_map.cc_base_url
    fill_in "Class ba", with: @meta_map.class_ba
    fill_in "Class cc", with: @meta_map.class_cc
    fill_in "Data", with: @meta_map.data
    click_on "Create Meta map"

    assert_text "Meta map was successfully created"
    assert_selector "h1", text: "Meta Maps"
  end

  test "updating a Meta map" do
    visit meta_map_url(@meta_map)
    click_on "Edit", match: :first

    fill_in "Ba base url", with: @meta_map.ba_base_url
    fill_in "Cc base url", with: @meta_map.cc_base_url
    fill_in "Class ba", with: @meta_map.class_ba
    fill_in "Class cc", with: @meta_map.class_cc
    fill_in "Data", with: @meta_map.data
    click_on "Update Meta map"

    assert_text "Meta map was successfully updated"
    assert_selector "h1", text: "Meta Maps"
  end

  test "destroying a Meta map" do
    visit edit_meta_map_url(@meta_map)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Meta map was successfully destroyed"
  end
end
