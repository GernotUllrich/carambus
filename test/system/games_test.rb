require "application_system_test_case"

class GamesTest < ApplicationSystemTestCase
  setup do
    @game = games(:one)
  end

  test "visiting the index" do
    visit games_url
    assert_selector "h1", text: "Games"
  end

  test "creating a Game" do
    visit games_url
    click_on "New Game"

    fill_in "Data", with: @game.data
    fill_in "Ended at", with: @game.ended_at
    fill_in "Gname", with: @game.gname
    fill_in "Group no", with: @game.group_no
    fill_in "Roles", with: @game.roles
    fill_in "Round no", with: @game.round_no
    fill_in "Seqno", with: @game.seqno
    fill_in "Started at", with: @game.started_at
    fill_in "Table no", with: @game.table_no
    fill_in "Template game", with: @game.template_game_id
    fill_in "Tournament", with: @game.tournament_id
    click_on "Create Game"

    assert_text "Game was successfully created"
    assert_selector "h1", text: "Games"
  end

  test "updating a Game" do
    visit game_url(@game)
    click_on "Edit", match: :first

    fill_in "Data", with: @game.data
    fill_in "Ended at", with: @game.ended_at
    fill_in "Gname", with: @game.gname
    fill_in "Group no", with: @game.group_no
    fill_in "Roles", with: @game.roles
    fill_in "Round no", with: @game.round_no
    fill_in "Seqno", with: @game.seqno
    fill_in "Started at", with: @game.started_at
    fill_in "Table no", with: @game.table_no
    fill_in "Template game", with: @game.template_game_id
    fill_in "Tournament", with: @game.tournament_id
    click_on "Update Game"

    assert_text "Game was successfully updated"
    assert_selector "h1", text: "Games"
  end

  test "destroying a Game" do
    visit edit_game_url(@game)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Game was successfully destroyed"
  end
end
