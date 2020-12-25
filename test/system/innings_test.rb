require "application_system_test_case"

class InningsTest < ApplicationSystemTestCase
  setup do
    @inning = innings(:one)
  end

  test "visiting the index" do
    visit innings_url
    assert_selector "h1", text: "Innings"
  end

  test "creating a Inning" do
    visit innings_url
    click_on "New Inning"

    fill_in "Date", with: @inning.date
    fill_in "Game", with: @inning.game_id
    fill_in "Player a count", with: @inning.player_a_count
    fill_in "Player b count", with: @inning.player_b_count
    fill_in "Player c count", with: @inning.player_c_count
    fill_in "Player d count", with: @inning.player_d_count
    fill_in "Sequence number", with: @inning.sequence_number
    click_on "Create Inning"

    assert_text "Inning was successfully created"
    assert_selector "h1", text: "Innings"
  end

  test "updating a Inning" do
    visit inning_url(@inning)
    click_on "Edit", match: :first

    fill_in "Date", with: @inning.date
    fill_in "Game", with: @inning.game_id
    fill_in "Player a count", with: @inning.player_a_count
    fill_in "Player b count", with: @inning.player_b_count
    fill_in "Player c count", with: @inning.player_c_count
    fill_in "Player d count", with: @inning.player_d_count
    fill_in "Sequence number", with: @inning.sequence_number
    click_on "Update Inning"

    assert_text "Inning was successfully updated"
    assert_selector "h1", text: "Innings"
  end

  test "destroying a Inning" do
    visit edit_inning_url(@inning)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Inning was successfully destroyed"
  end
end
