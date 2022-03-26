require "application_system_test_case"

class PartyGamesTest < ApplicationSystemTestCase
  setup do
    @party_game = party_games(:one)
  end

  test "visiting the index" do
    visit party_games_url
    assert_selector "h1", text: "Party Games"
  end

  test "creating a Party game" do
    visit party_games_url
    click_on "New Party Game"

    fill_in "Party", with: @party_game.party_id
    fill_in "Player a", with: @party_game.player_a_id
    fill_in "Player b", with: @party_game.player_b_id
    fill_in "Seqno", with: @party_game.seqno
    fill_in "Tournament", with: @party_game.tournament_id
    click_on "Create Party game"

    assert_text "Party game was successfully created"
    assert_selector "h1", text: "Party Games"
  end

  test "updating a Party game" do
    visit party_game_url(@party_game)
    click_on "Edit", match: :first

    fill_in "Party", with: @party_game.party_id
    fill_in "Player a", with: @party_game.player_a_id
    fill_in "Player b", with: @party_game.player_b_id
    fill_in "Seqno", with: @party_game.seqno
    fill_in "Tournament", with: @party_game.tournament_id
    click_on "Update Party game"

    assert_text "Party game was successfully updated"
    assert_selector "h1", text: "Party Games"
  end

  test "destroying a Party game" do
    visit edit_party_game_url(@party_game)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Party game was successfully destroyed"
  end
end
