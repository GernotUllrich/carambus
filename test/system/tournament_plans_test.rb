require "application_system_test_case"

class TournamentPlansTest < ApplicationSystemTestCase
  setup do
    @tournament_plan = tournament_plans(:one)
  end

  test "visiting the index" do
    visit tournament_plans_url
    assert_selector "h1", text: "Tournament Plans"
  end

  test "creating a Tournament plan" do
    visit tournament_plans_url
    click_on "New Tournament Plan"

    fill_in "Even more description", with: @tournament_plan.even_more_description
    fill_in "Executor class", with: @tournament_plan.executor_class
    fill_in "Executor params", with: @tournament_plan.executor_params
    fill_in "More description", with: @tournament_plan.more_description
    fill_in "Name", with: @tournament_plan.name
    fill_in "Ngroups", with: @tournament_plan.ngroups
    fill_in "Nrepeats", with: @tournament_plan.nrepeats
    fill_in "Players", with: @tournament_plan.players
    fill_in "Rulesystem", with: @tournament_plan.rulesystem
    fill_in "Tables", with: @tournament_plan.tables
    click_on "Create Tournament plan"

    assert_text "Tournament plan was successfully created"
    assert_selector "h1", text: "Tournament Plans"
  end

  test "updating a Tournament plan" do
    visit tournament_plan_url(@tournament_plan)
    click_on "Edit", match: :first

    fill_in "Even more description", with: @tournament_plan.even_more_description
    fill_in "Executor class", with: @tournament_plan.executor_class
    fill_in "Executor params", with: @tournament_plan.executor_params
    fill_in "More description", with: @tournament_plan.more_description
    fill_in "Name", with: @tournament_plan.name
    fill_in "Ngroups", with: @tournament_plan.ngroups
    fill_in "Nrepeats", with: @tournament_plan.nrepeats
    fill_in "Players", with: @tournament_plan.players
    fill_in "Rulesystem", with: @tournament_plan.rulesystem
    fill_in "Tables", with: @tournament_plan.tables
    click_on "Update Tournament plan"

    assert_text "Tournament plan was successfully updated"
    assert_selector "h1", text: "Tournament Plans"
  end

  test "destroying a Tournament plan" do
    visit edit_tournament_plan_url(@tournament_plan)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Tournament plan was successfully destroyed"
  end
end
