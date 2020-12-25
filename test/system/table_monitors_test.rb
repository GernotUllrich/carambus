require "application_system_test_case"

class TableMonitorsTest < ApplicationSystemTestCase
  setup do
    @table_monitor = table_monitors(:one)
  end

  test "visiting the index" do
    visit table_monitors_url
    assert_selector "h1", text: "Table Monitors"
  end

  test "creating a Table monitor" do
    visit table_monitors_url
    click_on "New Table Monitor"

    fill_in "Data", with: @table_monitor.data
    fill_in "Game", with: @table_monitor.game_id
    fill_in "Ip address", with: @table_monitor.ip_address
    fill_in "Name", with: @table_monitor.name
    fill_in "Next game", with: @table_monitor.next_game_id
    fill_in "State", with: @table_monitor.state
    fill_in "Tournament monitor", with: @table_monitor.tournament_monitor_id
    click_on "Create Table monitor"

    assert_text "Table monitor was successfully created"
    assert_selector "h1", text: "Table Monitors"
  end

  test "updating a Table monitor" do
    visit table_monitor_url(@table_monitor)
    click_on "Edit", match: :first

    fill_in "Data", with: @table_monitor.data
    fill_in "Game", with: @table_monitor.game_id
    fill_in "Ip address", with: @table_monitor.ip_address
    fill_in "Name", with: @table_monitor.name
    fill_in "Next game", with: @table_monitor.next_game_id
    fill_in "State", with: @table_monitor.state
    fill_in "Tournament monitor", with: @table_monitor.tournament_monitor_id
    click_on "Update Table monitor"

    assert_text "Table monitor was successfully updated"
    assert_selector "h1", text: "Table Monitors"
  end

  test "destroying a Table monitor" do
    visit edit_table_monitor_url(@table_monitor)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Table monitor was successfully destroyed"
  end
end
