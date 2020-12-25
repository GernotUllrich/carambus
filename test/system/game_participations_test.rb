require "application_system_test_case"

class GameParticipationsTest < ApplicationSystemTestCase
  setup do
    @game_participation = game_participations(:one)
  end

  test "visiting the index" do
    visit game_participations_url
    assert_selector "h1", text: "Game Participations"
  end

  test "creating a Game participation" do
    visit game_participations_url
    click_on "New Game Participation"

    fill_in "Data", with: @game_participation.data
    fill_in "Game", with: @game_participation.game
    fill_in "Game", with: @game_participation.game_id
    fill_in "Gd", with: @game_participation.gd
    fill_in "Hs", with: @game_participation.hs
    fill_in "Innings", with: @game_participation.innings
    fill_in "Player", with: @game_participation.player_id
    fill_in "Points", with: @game_participation.points
    fill_in "Result", with: @game_participation.result
    fill_in "Role", with: @game_participation.role
    click_on "Create Game participation"

    assert_text "Game participation was successfully created"
    assert_selector "h1", text: "Game Participations"
  end

  test "updating a Game participation" do
    visit game_participation_url(@game_participation)
    click_on "Edit", match: :first

    fill_in "Data", with: @game_participation.data
    fill_in "Game", with: @game_participation.game
    fill_in "Game", with: @game_participation.game_id
    fill_in "Gd", with: @game_participation.gd
    fill_in "Hs", with: @game_participation.hs
    fill_in "Innings", with: @game_participation.innings
    fill_in "Player", with: @game_participation.player_id
    fill_in "Points", with: @game_participation.points
    fill_in "Result", with: @game_participation.result
    fill_in "Role", with: @game_participation.role
    click_on "Update Game participation"

    assert_text "Game participation was successfully updated"
    assert_selector "h1", text: "Game Participations"
  end

  test "destroying a Game participation" do
    visit edit_game_participation_url(@game_participation)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Game participation was successfully destroyed"
  end
end
