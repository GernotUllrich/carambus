require "application_system_test_case"

class RegistrationListCcsTest < ApplicationSystemTestCase
  setup do
    @registration_list_cc = registration_list_ccs(:one)
  end

  test "visiting the index" do
    visit registration_list_ccs_url
    assert_selector "h1", text: "Registration List Ccs"
  end

  test "creating a Registration list cc" do
    visit registration_list_ccs_url
    click_on "New Registration List Cc"

    fill_in "Branch cc", with: @registration_list_cc.branch_cc_id
    fill_in "Category cc", with: @registration_list_cc.category_cc_id
    fill_in "Cc", with: @registration_list_cc.cc_id
    fill_in "Context", with: @registration_list_cc.context
    fill_in "Data", with: @registration_list_cc.data
    fill_in "Deadline", with: @registration_list_cc.deadline
    fill_in "Discipline", with: @registration_list_cc.discipline_id
    fill_in "Name", with: @registration_list_cc.name
    fill_in "Qualifying date", with: @registration_list_cc.qualifying_date
    fill_in "Season", with: @registration_list_cc.season_id
    fill_in "Status", with: @registration_list_cc.status
    click_on "Create Registration list cc"

    assert_text "Registration list cc was successfully created"
    assert_selector "h1", text: "Registration List Ccs"
  end

  test "updating a Registration list cc" do
    visit registration_list_cc_url(@registration_list_cc)
    click_on "Edit", match: :first

    fill_in "Branch cc", with: @registration_list_cc.branch_cc_id
    fill_in "Category cc", with: @registration_list_cc.category_cc_id
    fill_in "Cc", with: @registration_list_cc.cc_id
    fill_in "Context", with: @registration_list_cc.context
    fill_in "Data", with: @registration_list_cc.data
    fill_in "Deadline", with: @registration_list_cc.deadline
    fill_in "Discipline", with: @registration_list_cc.discipline_id
    fill_in "Name", with: @registration_list_cc.name
    fill_in "Qualifying date", with: @registration_list_cc.qualifying_date
    fill_in "Season", with: @registration_list_cc.season_id
    fill_in "Status", with: @registration_list_cc.status
    click_on "Update Registration list cc"

    assert_text "Registration list cc was successfully updated"
    assert_selector "h1", text: "Registration List Ccs"
  end

  test "destroying a Registration list cc" do
    visit edit_registration_list_cc_url(@registration_list_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Registration list cc was successfully destroyed"
  end
end
