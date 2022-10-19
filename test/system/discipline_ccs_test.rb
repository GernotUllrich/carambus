require "application_system_test_case"

class DisciplineCcsTest < ApplicationSystemTestCase
  setup do
    @discipline_cc = discipline_ccs(:one)
  end

  test "visiting the index" do
    visit discipline_ccs_url
    assert_selector "h1", text: "Discipline Ccs"
  end

  test "creating a Discipline cc" do
    visit discipline_ccs_url
    click_on "New Discipline Cc"

    fill_in "Branch cc", with: @discipline_cc.branch_cc_id
    fill_in "Cc", with: @discipline_cc.cc_id
    fill_in "Context", with: @discipline_cc.context
    fill_in "Discipline", with: @discipline_cc.discipline_id
    fill_in "Name", with: @discipline_cc.name
    click_on "Create Discipline cc"

    assert_text "Discipline cc was successfully created"
    assert_selector "h1", text: "Discipline Ccs"
  end

  test "updating a Discipline cc" do
    visit discipline_cc_url(@discipline_cc)
    click_on "Edit", match: :first

    fill_in "Branch cc", with: @discipline_cc.branch_cc_id
    fill_in "Cc", with: @discipline_cc.cc_id
    fill_in "Context", with: @discipline_cc.context
    fill_in "Discipline", with: @discipline_cc.discipline_id
    fill_in "Name", with: @discipline_cc.name
    click_on "Update Discipline cc"

    assert_text "Discipline cc was successfully updated"
    assert_selector "h1", text: "Discipline Ccs"
  end

  test "destroying a Discipline cc" do
    visit edit_discipline_cc_url(@discipline_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Discipline cc was successfully destroyed"
  end
end
