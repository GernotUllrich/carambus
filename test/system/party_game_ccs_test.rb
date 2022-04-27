require "application_system_test_case"

class PartyGameCcsTest < ApplicationSystemTestCase
  setup do
    @party_game_cc = party_game_ccs(:one)
  end

  test "visiting the index" do
    visit party_game_ccs_url
    assert_selector "h1", text: "Party Game Ccs"
  end

  test "creating a Party game cc" do
    visit party_game_ccs_url
    click_on "New Party Game Cc"

    fill_in "Cc", with: @party_game_cc.cc_id
    fill_in "Data", with: @party_game_cc.data
    fill_in "Discipline", with: @party_game_cc.discipline_id
    fill_in "Name", with: @party_game_cc.name
    fill_in "Player a", with: @party_game_cc.player_a_id
    fill_in "Player b", with: @party_game_cc.player_b_id
    fill_in "Seqno", with: @party_game_cc.seqno
    click_on "Create Party game cc"

    assert_text "Party game cc was successfully created"
    assert_selector "h1", text: "Party Game Ccs"
  end

  test "updating a Party game cc" do
    visit party_game_cc_url(@party_game_cc)
    click_on "Edit", match: :first

    fill_in "Cc", with: @party_game_cc.cc_id
    fill_in "Data", with: @party_game_cc.data
    fill_in "Discipline", with: @party_game_cc.discipline_id
    fill_in "Name", with: @party_game_cc.name
    fill_in "Player a", with: @party_game_cc.player_a_id
    fill_in "Player b", with: @party_game_cc.player_b_id
    fill_in "Seqno", with: @party_game_cc.seqno
    click_on "Update Party game cc"

    assert_text "Party game cc was successfully updated"
    assert_selector "h1", text: "Party Game Ccs"
  end

  test "destroying a Party game cc" do
    visit edit_party_game_cc_url(@party_game_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Party game cc was successfully destroyed"
  end
end
