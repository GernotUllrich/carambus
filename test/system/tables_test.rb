require "application_system_test_case"

class TablesTest < ApplicationSystemTestCase
  setup do
    @table = tables(:one)
  end

  test "visiting the index" do
    visit tables_url
    assert_selector "h1", text: "Tables"
  end

  test "creating a Table" do
    visit tables_url
    click_on "New Table"

    fill_in "Data", with: @table.data
    fill_in "Ip address", with: @table.ip_address
    fill_in "Location", with: @table.location_id
    fill_in "Name", with: @table.name
    fill_in "Table kind", with: @table.table_kind_id
    click_on "Create Table"

    assert_text "Table was successfully created"
    assert_selector "h1", text: "Tables"
  end

  test "updating a Table" do
    visit table_url(@table)
    click_on "Edit", match: :first

    fill_in "Data", with: @table.data
    fill_in "Ip address", with: @table.ip_address
    fill_in "Location", with: @table.location_id
    fill_in "Name", with: @table.name
    fill_in "Table kind", with: @table.table_kind_id
    click_on "Update Table"

    assert_text "Table was successfully updated"
    assert_selector "h1", text: "Tables"
  end

  test "destroying a Table" do
    visit edit_table_url(@table)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Table was successfully destroyed"
  end
end
