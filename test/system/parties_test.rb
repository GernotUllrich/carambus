require "application_system_test_case"

class PartiesTest < ApplicationSystemTestCase
  setup do
    @party = parties(:one)
  end

  test "visiting the index" do
    visit parties_url
    assert_selector "h1", text: "Parties"
  end

  test "creating a Party" do
    visit parties_url
    click_on "New Party"

    fill_in "Ba", with: @party.ba_id
    fill_in "Data", with: @party.data
    fill_in "Date", with: @party.date
    fill_in "Day seqno", with: @party.day_seqno
    fill_in "Host league team", with: @party.host_league_team_id
    fill_in "League", with: @party.league_id
    fill_in "League team a", with: @party.league_team_a_id
    fill_in "League team b", with: @party.league_team_b_id
    fill_in "Remarks", with: @party.remarks
    click_on "Create Party"

    assert_text "Party was successfully created"
    assert_selector "h1", text: "Parties"
  end

  test "updating a Party" do
    visit party_url(@party)
    click_on "Edit", match: :first

    fill_in "Ba", with: @party.ba_id
    fill_in "Data", with: @party.data
    fill_in "Date", with: @party.date
    fill_in "Day seqno", with: @party.day_seqno
    fill_in "Host league team", with: @party.host_league_team_id
    fill_in "League", with: @party.league_id
    fill_in "League team a", with: @party.league_team_a_id
    fill_in "League team b", with: @party.league_team_b_id
    fill_in "Remarks", with: @party.remarks
    click_on "Update Party"

    assert_text "Party was successfully updated"
    assert_selector "h1", text: "Parties"
  end

  test "destroying a Party" do
    visit edit_party_url(@party)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Party was successfully destroyed"
  end
end
