require "application_system_test_case"

class DisciplinesTest < ApplicationSystemTestCase
  setup do
    @discipline = disciplines(:one)
  end

  test "visiting the index" do
    visit disciplines_url
    assert_selector "h1", text: "Disciplines"
  end

  test "creating a Discipline" do
    visit disciplines_url
    click_on "New Discipline"

    fill_in "Data", with: @discipline.data
    fill_in "Name", with: @discipline.name
    fill_in "Super discipline", with: @discipline.super_discipline_id
    fill_in "Table kind", with: @discipline.table_kind_id
    click_on "Create Discipline"

    assert_text "Discipline was successfully created"
    assert_selector "h1", text: "Disciplines"
  end

  test "updating a Discipline" do
    visit discipline_url(@discipline)
    click_on "Edit", match: :first

    fill_in "Data", with: @discipline.data
    fill_in "Name", with: @discipline.name
    fill_in "Super discipline", with: @discipline.super_discipline_id
    fill_in "Table kind", with: @discipline.table_kind_id
    click_on "Update Discipline"

    assert_text "Discipline was successfully updated"
    assert_selector "h1", text: "Disciplines"
  end

  test "destroying a Discipline" do
    visit edit_discipline_url(@discipline)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Discipline was successfully destroyed"
  end
end
