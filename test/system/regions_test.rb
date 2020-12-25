require "application_system_test_case"

class RegionsTest < ApplicationSystemTestCase
  setup do
    @@region = regions(:one)
  end

  test "visiting the index" do
    visit regions_url
    assert_selector "h1", text: "Regions"
  end

  test "creating a @region" do
    visit regions_url
    click_on "New @region"

    fill_in "Address", with: @@region.address
    fill_in "Country", with: @@region.country_id
    fill_in "Email", with: @@region.email
    fill_in "Logo", with: @@region.logo
    fill_in "Name", with: @region.name
    fill_in "Shortname", with: @region.shortname
    click_on "Create Region"

    assert_text "Region was successfully created"
    assert_selector "h1", text: "Regions"
  end

  test "updating a Region" do
    visit region_url(@region)
    click_on "Edit", match: :first

    fill_in "Address", with: @region.address
    fill_in "Country", with: @region.country_id
    fill_in "Email", with: @region.email
    fill_in "Logo", with: @region.logo
    fill_in "Name", with: @region.name
    fill_in "Shortname", with: @region.shortname
    click_on "Update Region"

    assert_text "Region was successfully updated"
    assert_selector "h1", text: "Regions"
  end

  test "destroying a Region" do
    visit edit_region_url(@region)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Region was successfully destroyed"
  end
end
