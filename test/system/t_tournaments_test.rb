require "application_system_test_case"

class TTournamentsTest < ApplicationSystemTestCase
  setup do
    @t_tournament = t_tournaments(:one)
  end

  test "visiting the index" do
    visit t_tournaments_url
    assert_selector "h1", text: "T Tournaments"
  end

  test "creating a T tournament" do
    visit t_tournaments_url
    click_on "New T Tournament"

    click_on "Create T tournament"

    assert_text "T tournament was successfully created"
    assert_selector "h1", text: "T Tournaments"
  end

  test "updating a T tournament" do
    visit t_tournament_url(@t_tournament)
    click_on "Edit", match: :first

    click_on "Update T tournament"

    assert_text "T tournament was successfully updated"
    assert_selector "h1", text: "T Tournaments"
  end

  test "destroying a T tournament" do
    visit edit_t_tournament_url(@t_tournament)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "T tournament was successfully destroyed"
  end
end
