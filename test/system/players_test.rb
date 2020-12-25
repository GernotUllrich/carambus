require "application_system_test_case"

class PlayersTest < ApplicationSystemTestCase
  setup do
    @player = players(:one)
  end

  test "visiting the index" do
    visit players_url
    assert_selector "h1", text: "Players"
  end

  test "creating a Player" do
    visit players_url
    click_on "New Player"

    fill_in "Ba", with: @player.ba_id
    fill_in "Club", with: @player.club_id
    fill_in "Firstname", with: @player.firstname
    fill_in "Lastname", with: @player.lastname
    fill_in "Title", with: @player.title
    click_on "Create Player"

    assert_text "Player was successfully created"
    assert_selector "h1", text: "Players"
  end

  test "updating a Player" do
    visit player_url(@player)
    click_on "Edit", match: :first

    fill_in "Ba", with: @player.ba_id
    fill_in "Club", with: @player.club_id
    fill_in "Firstname", with: @player.firstname
    fill_in "Lastname", with: @player.lastname
    fill_in "Title", with: @player.title
    click_on "Update Player"

    assert_text "Player was successfully updated"
    assert_selector "h1", text: "Players"
  end

  test "destroying a Player" do
    visit edit_player_url(@player)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Player was successfully destroyed"
  end
end
