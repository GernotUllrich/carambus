require "application_system_test_case"

class ClubsTest < ApplicationSystemTestCase
  setup do
    @club = clubs(:one)
  end

  test "visiting the index" do
    visit clubs_url
    assert_selector "h1", text: "Clubs"
  end

  test "creating a Club" do
    visit clubs_url
    click_on "New Club"

    fill_in "Address", with: @club.address
    fill_in "Ba", with: @club.ba_id
    fill_in "Dbu entry", with: @club.dbu_entry
    fill_in "Email", with: @club.email
    fill_in "Founded", with: @club.founded
    fill_in "Homepage", with: @club.homepage
    fill_in "Logo", with: @club.logo
    fill_in "Name", with: @club.name
    fill_in "Priceinfo", with: @club.priceinfo
    fill_in "Region", with: @club.region_id
    fill_in "Shortname", with: @club.shortname
    fill_in "Status", with: @club.status
    click_on "Create Club"

    assert_text "Club was successfully created"
    assert_selector "h1", text: "Clubs"
  end

  test "updating a Club" do
    visit club_url(@club)
    click_on "Edit", match: :first

    fill_in "Address", with: @club.address
    fill_in "Ba", with: @club.ba_id
    fill_in "Dbu entry", with: @club.dbu_entry
    fill_in "Email", with: @club.email
    fill_in "Founded", with: @club.founded
    fill_in "Homepage", with: @club.homepage
    fill_in "Logo", with: @club.logo
    fill_in "Name", with: @club.name
    fill_in "Priceinfo", with: @club.priceinfo
    fill_in "Region", with: @club.region_id
    fill_in "Shortname", with: @club.shortname
    fill_in "Status", with: @club.status
    click_on "Update Club"

    assert_text "Club was successfully updated"
    assert_selector "h1", text: "Clubs"
  end

  test "destroying a Club" do
    visit edit_club_url(@club)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Club was successfully destroyed"
  end
end
