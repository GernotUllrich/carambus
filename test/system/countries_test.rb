require "application_system_test_case"

class CountriesTest < ApplicationSystemTestCase
  setup do
    @country = countries(:one)
  end

  test "visiting the index" do
    visit countries_url
    assert_selector "h1", text: "Countries"
  end

  test "creating a Country" do
    visit countries_url
    click_on "New Country"

    fill_in "Code", with: @country.code
    fill_in "Name", with: @country.name
    click_on "Create Country"

    assert_text "Country was successfully created"
    assert_selector "h1", text: "Countries"
  end

  test "updating a Country" do
    visit country_url(@country)
    click_on "Edit", match: :first

    fill_in "Code", with: @country.code
    fill_in "Name", with: @country.name
    click_on "Update Country"

    assert_text "Country was successfully updated"
    assert_selector "h1", text: "Countries"
  end

  test "destroying a Country" do
    visit edit_country_url(@country)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Country was successfully destroyed"
  end
end
