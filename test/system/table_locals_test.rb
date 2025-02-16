require "application_system_test_case"

class TableLocalsTest < ApplicationSystemTestCase
  setup do
    @table_local = table_locals(:one)
  end

  test "visiting the index" do
    visit table_locals_url
    assert_selector "h1", text: "Table Locals"
  end

  test "creating a Table local" do
    visit table_locals_url
    click_on "New Table Local"

    fill_in "Ip address", with: @table_local.ip_address
    fill_in "Table", with: @table_local.table_id
    fill_in "Tpl ip address", with: @table_local.tpl_ip_address
    click_on "Create Table local"

    assert_text "Table local was successfully created"
    assert_selector "h1", text: "Table Locals"
  end

  test "updating a Table local" do
    visit table_local_url(@table_local)
    click_on "Edit", match: :first

    fill_in "Ip address", with: @table_local.ip_address
    fill_in "Table", with: @table_local.table_id
    fill_in "Tpl ip address", with: @table_local.tpl_ip_address
    click_on "Update Table local"

    assert_text "Table local was successfully updated"
    assert_selector "h1", text: "Table Locals"
  end

  test "destroying a Table local" do
    visit edit_table_local_url(@table_local)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Table local was successfully destroyed"
  end
end
