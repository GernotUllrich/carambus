require "application_system_test_case"

class PartyTournamentsTest < ApplicationSystemTestCase
  setup do
    @party_tournament = party_tournaments(:one)
  end

  test "visiting the index" do
    visit party_tournaments_url
    assert_selector "h1", text: "Party Tournaments"
  end

  test "creating a Party tournament" do
    visit party_tournaments_url
    click_on "New Party Tournament"

    fill_in "Party", with: @party_tournament.party_id
    fill_in "Position", with: @party_tournament.position
    fill_in "Tournament", with: @party_tournament.tournament_id
    click_on "Create Party tournament"

    assert_text "Party tournament was successfully created"
    assert_selector "h1", text: "Party Tournaments"
  end

  test "updating a Party tournament" do
    visit party_tournament_url(@party_tournament)
    click_on "Edit", match: :first

    fill_in "Party", with: @party_tournament.party_id
    fill_in "Position", with: @party_tournament.position
    fill_in "Tournament", with: @party_tournament.tournament_id
    click_on "Update Party tournament"

    assert_text "Party tournament was successfully updated"
    assert_selector "h1", text: "Party Tournaments"
  end

  test "destroying a Party tournament" do
    visit edit_party_tournament_url(@party_tournament)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Party tournament was successfully destroyed"
  end
end
