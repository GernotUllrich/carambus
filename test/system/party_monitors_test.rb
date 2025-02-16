require "application_system_test_case"

class PartyMonitorsTest < ApplicationSystemTestCase
  setup do
    @party_monitor = party_monitors(:one)
  end

  test "visiting the index" do
    visit party_monitors_url
    assert_selector "h1", text: "Party Monitors"
  end

  test "creating a Party monitor" do
    visit party_monitors_url
    click_on "New Party Monitor"

    fill_in "Data", with: @party_monitor.data
    fill_in "Ended at", with: @party_monitor.ended_at
    fill_in "Party", with: @party_monitor.party_id
    fill_in "Started at", with: @party_monitor.started_at
    fill_in "State", with: @party_monitor.state
    click_on "Create Party monitor"

    assert_text "Party monitor was successfully created"
    assert_selector "h1", text: "Party Monitors"
  end

  test "updating a Party monitor" do
    visit party_monitor_url(@party_monitor)
    click_on "Edit", match: :first

    fill_in "Data", with: @party_monitor.data
    fill_in "Ended at", with: @party_monitor.ended_at
    fill_in "Party", with: @party_monitor.party_id
    fill_in "Started at", with: @party_monitor.started_at
    fill_in "State", with: @party_monitor.state
    click_on "Update Party monitor"

    assert_text "Party monitor was successfully updated"
    assert_selector "h1", text: "Party Monitors"
  end

  test "destroying a Party monitor" do
    visit edit_party_monitor_url(@party_monitor)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Party monitor was successfully destroyed"
  end
end
