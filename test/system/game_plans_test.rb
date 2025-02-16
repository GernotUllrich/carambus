require "application_system_test_case"

class GamePlansTest < ApplicationSystemTestCase
  setup do
    @game_plan = game_plans(:one)
  end

  test "visiting the index" do
    visit game_plans_url
    assert_selector "h1", text: "Game Plans"
  end

  test "creating a Game plan" do
    visit game_plans_url
    click_on "New Game Plan"

    fill_in "Data", with: @game_plan.data
    fill_in "Footprint", with: @game_plan.footprint
    fill_in "Name", with: @game_plan.name
    click_on "Create Game plan"

    assert_text "Game plan was successfully created"
    assert_selector "h1", text: "Game Plans"
  end

  test "updating a Game plan" do
    visit game_plan_url(@game_plan)
    click_on "Edit", match: :first

    fill_in "Data", with: @game_plan.data
    fill_in "Footprint", with: @game_plan.footprint
    fill_in "Name", with: @game_plan.name
    click_on "Update Game plan"

    assert_text "Game plan was successfully updated"
    assert_selector "h1", text: "Game Plans"
  end

  test "destroying a Game plan" do
    visit edit_game_plan_url(@game_plan)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Game plan was successfully destroyed"
  end
end
