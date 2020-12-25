require "application_system_test_case"

class TournamentMonitorsTest < ApplicationSystemTestCase
  setup do
    @tournament_monitor = tournament_monitors(:one)
  end

  test "visiting the index" do
    visit tournament_monitors_url
    assert_selector "h1", text: "Tournament Monitors"
  end

  test "creating a Tournament monitor" do
    visit tournament_monitors_url
    click_on "New Tournament Monitor"

    fill_in "Balls goal", with: @tournament_monitor.balls_goal
    fill_in "Date", with: @tournament_monitor.date
    fill_in "Innings goal", with: @tournament_monitor.innings_goal
    fill_in "State", with: @tournament_monitor.state
    fill_in "Tournament", with: @tournament_monitor.tournament_id
    click_on "Create Tournament monitor"

    assert_text "Tournament monitor was successfully created"
    assert_selector "h1", text: "Tournament Monitors"
  end

  test "updating a Tournament monitor" do
    visit tournament_monitor_url(@tournament_monitor)
    click_on "Edit", match: :first

    fill_in "Balls goal", with: @tournament_monitor.balls_goal
    fill_in "Date", with: @tournament_monitor.date
    fill_in "Innings goal", with: @tournament_monitor.innings_goal
    fill_in "State", with: @tournament_monitor.state
    fill_in "Tournament", with: @tournament_monitor.tournament_id
    click_on "Update Tournament monitor"

    assert_text "Tournament monitor was successfully updated"
    assert_selector "h1", text: "Tournament Monitors"
  end

  test "destroying a Tournament monitor" do
    visit edit_tournament_monitor_url(@tournament_monitor)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Tournament monitor was successfully destroyed"
  end
end
