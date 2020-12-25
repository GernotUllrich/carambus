require "application_system_test_case"

class DisciplineTournamentPlansTest < ApplicationSystemTestCase
  setup do
    @discipline_tournament_plan = discipline_tournament_plans(:one)
  end

  test "visiting the index" do
    visit discipline_tournament_plans_url
    assert_selector "h1", text: "Discipline Tournament Plans"
  end

  test "creating a Discipline tournament plan" do
    visit discipline_tournament_plans_url
    click_on "New Discipline Tournament Plan"

    fill_in "Discipline", with: @discipline_tournament_plan.discipline_id
    fill_in "Innings", with: @discipline_tournament_plan.innings
    fill_in "Player class", with: @discipline_tournament_plan.player_class
    fill_in "Players", with: @discipline_tournament_plan.players
    fill_in "Points", with: @discipline_tournament_plan.points
    fill_in "Tournament plan", with: @discipline_tournament_plan.tournament_plan_id
    click_on "Create Discipline tournament plan"

    assert_text "Discipline tournament plan was successfully created"
    assert_selector "h1", text: "Discipline Tournament Plans"
  end

  test "updating a Discipline tournament plan" do
    visit discipline_tournament_plan_url(@discipline_tournament_plan)
    click_on "Edit", match: :first

    fill_in "Discipline", with: @discipline_tournament_plan.discipline_id
    fill_in "Innings", with: @discipline_tournament_plan.innings
    fill_in "Player class", with: @discipline_tournament_plan.player_class
    fill_in "Players", with: @discipline_tournament_plan.players
    fill_in "Points", with: @discipline_tournament_plan.points
    fill_in "Tournament plan", with: @discipline_tournament_plan.tournament_plan_id
    click_on "Update Discipline tournament plan"

    assert_text "Discipline tournament plan was successfully updated"
    assert_selector "h1", text: "Discipline Tournament Plans"
  end

  test "destroying a Discipline tournament plan" do
    visit edit_discipline_tournament_plan_url(@discipline_tournament_plan)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Discipline tournament plan was successfully destroyed"
  end
end
