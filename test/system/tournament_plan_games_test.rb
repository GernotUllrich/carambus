require "application_system_test_case"

class TournamentPlanGamesTest < ApplicationSystemTestCase
  setup do
    @tournament_plan_game = tournament_plan_games(:one)
  end

  test "visiting the index" do
    visit tournament_plan_games_url
    assert_selector "h1", text: "Tournament Plan Games"
  end

  test "creating a Tournament plan game" do
    visit tournament_plan_games_url
    click_on "New Tournament Plan Game"

    fill_in "Data", with: @tournament_plan_game.data
    fill_in "Name", with: @tournament_plan_game.name
    fill_in "Tournament plan", with: @tournament_plan_game.tournament_plan_id
    click_on "Create Tournament plan game"

    assert_text "Tournament plan game was successfully created"
    assert_selector "h1", text: "Tournament Plan Games"
  end

  test "updating a Tournament plan game" do
    visit tournament_plan_game_url(@tournament_plan_game)
    click_on "Edit", match: :first

    fill_in "Data", with: @tournament_plan_game.data
    fill_in "Name", with: @tournament_plan_game.name
    fill_in "Tournament plan", with: @tournament_plan_game.tournament_plan_id
    click_on "Update Tournament plan game"

    assert_text "Tournament plan game was successfully updated"
    assert_selector "h1", text: "Tournament Plan Games"
  end

  test "destroying a Tournament plan game" do
    visit edit_tournament_plan_game_url(@tournament_plan_game)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Tournament plan game was successfully destroyed"
  end
end
