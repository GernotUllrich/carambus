require "application_system_test_case"

class SeedingsTest < ApplicationSystemTestCase
  setup do
    @seeding = seedings(:one)
  end

  test "visiting the index" do
    visit seedings_url
    assert_selector "h1", text: "Seedings"
  end

  test "creating a Seeding" do
    visit seedings_url
    click_on "New Seeding"

    fill_in "Ba state", with: @seeding.ba_state
    fill_in "Balls goal", with: @seeding.balls_goal
    fill_in "Data", with: @seeding.data
    fill_in "Player", with: @seeding.player_id
    fill_in "Playing discipline", with: @seeding.playing_discipline_id
    fill_in "Position", with: @seeding.position
    fill_in "State", with: @seeding.state
    fill_in "Tournament", with: @seeding.tournament_id
    click_on "Create Seeding"

    assert_text "Seeding was successfully created"
    assert_selector "h1", text: "Seedings"
  end

  test "updating a Seeding" do
    visit seeding_url(@seeding)
    click_on "Edit", match: :first

    fill_in "Ba state", with: @seeding.ba_state
    fill_in "Balls goal", with: @seeding.balls_goal
    fill_in "Data", with: @seeding.data
    fill_in "Player", with: @seeding.player_id
    fill_in "Playing discipline", with: @seeding.playing_discipline_id
    fill_in "Position", with: @seeding.position
    fill_in "State", with: @seeding.state
    fill_in "Tournament", with: @seeding.tournament_id
    click_on "Update Seeding"

    assert_text "Seeding was successfully updated"
    assert_selector "h1", text: "Seedings"
  end

  test "destroying a Seeding" do
    visit edit_seeding_url(@seeding)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Seeding was successfully destroyed"
  end
end
