require "application_system_test_case"

class SeasonCcsTest < ApplicationSystemTestCase
  setup do
    @season_cc = season_ccs(:one)
  end

  test "visiting the index" do
    visit season_ccs_url
    assert_selector "h1", text: "Season Ccs"
  end

  test "creating a Season cc" do
    visit season_ccs_url
    click_on "New Season Cc"

    fill_in "Cc", with: @season_cc.cc_id
    fill_in "Competition cc", with: @season_cc.competition_cc_id
    fill_in "Context", with: @season_cc.context
    fill_in "Name", with: @season_cc.name
    fill_in "Season", with: @season_cc.season_id
    click_on "Create Season cc"

    assert_text "Season cc was successfully created"
    assert_selector "h1", text: "Season Ccs"
  end

  test "updating a Season cc" do
    visit season_cc_url(@season_cc)
    click_on "Edit", match: :first

    fill_in "Cc", with: @season_cc.cc_id
    fill_in "Competition cc", with: @season_cc.competition_cc_id
    fill_in "Context", with: @season_cc.context
    fill_in "Name", with: @season_cc.name
    fill_in "Season", with: @season_cc.season_id
    click_on "Update Season cc"

    assert_text "Season cc was successfully updated"
    assert_selector "h1", text: "Season Ccs"
  end

  test "destroying a Season cc" do
    visit edit_season_cc_url(@season_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Season cc was successfully destroyed"
  end
end
