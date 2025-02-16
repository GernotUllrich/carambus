require "application_system_test_case"

class DisciplinePhasesTest < ApplicationSystemTestCase
  setup do
    @discipline_phase = discipline_phases(:one)
  end

  test "visiting the index" do
    visit discipline_phases_url
    assert_selector "h1", text: "Discipline Phases"
  end

  test "creating a Discipline phase" do
    visit discipline_phases_url
    click_on "New Discipline Phase"

    fill_in "Data", with: @discipline_phase.data
    fill_in "Discipline", with: @discipline_phase.discipline_id
    fill_in "Name", with: @discipline_phase.name
    fill_in "Parent discipline", with: @discipline_phase.parent_discipline_id
    fill_in "Position", with: @discipline_phase.position
    click_on "Create Discipline phase"

    assert_text "Discipline phase was successfully created"
    assert_selector "h1", text: "Discipline Phases"
  end

  test "updating a Discipline phase" do
    visit discipline_phase_url(@discipline_phase)
    click_on "Edit", match: :first

    fill_in "Data", with: @discipline_phase.data
    fill_in "Discipline", with: @discipline_phase.discipline_id
    fill_in "Name", with: @discipline_phase.name
    fill_in "Parent discipline", with: @discipline_phase.parent_discipline_id
    fill_in "Position", with: @discipline_phase.position
    click_on "Update Discipline phase"

    assert_text "Discipline phase was successfully updated"
    assert_selector "h1", text: "Discipline Phases"
  end

  test "destroying a Discipline phase" do
    visit edit_discipline_phase_url(@discipline_phase)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Discipline phase was successfully destroyed"
  end
end
