require "application_system_test_case"

class TableKindsTest < ApplicationSystemTestCase
  setup do
    @table_kind = table_kinds(:one)
  end

  test "visiting the index" do
    visit table_kinds_url
    assert_selector "h1", text: "Table Kinds"
  end

  test "creating a Table kind" do
    visit table_kinds_url
    click_on "New Table Kind"

    fill_in "Measures", with: @table_kind.measures
    fill_in "Name", with: @table_kind.name
    fill_in "Short", with: @table_kind.short
    click_on "Create Table kind"

    assert_text "Table kind was successfully created"
    assert_selector "h1", text: "Table Kinds"
  end

  test "updating a Table kind" do
    visit table_kind_url(@table_kind)
    click_on "Edit", match: :first

    fill_in "Measures", with: @table_kind.measures
    fill_in "Name", with: @table_kind.name
    fill_in "Short", with: @table_kind.short
    click_on "Update Table kind"

    assert_text "Table kind was successfully updated"
    assert_selector "h1", text: "Table Kinds"
  end

  test "destroying a Table kind" do
    visit edit_table_kind_url(@table_kind)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Table kind was successfully destroyed"
  end
end
