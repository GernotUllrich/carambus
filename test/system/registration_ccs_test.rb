require "application_system_test_case"

class RegistrationCcsTest < ApplicationSystemTestCase
  setup do
    @registration_cc = registration_ccs(:one)
  end

  test "visiting the index" do
    visit registration_ccs_url
    assert_selector "h1", text: "Registration Ccs"
  end

  test "creating a Registration cc" do
    visit registration_ccs_url
    click_on "New Registration Cc"

    fill_in "Player", with: @registration_cc.player_id
    fill_in "Registration list cc", with: @registration_cc.registration_list_cc_id
    fill_in "Status", with: @registration_cc.status
    click_on "Create Registration cc"

    assert_text "Registration cc was successfully created"
    assert_selector "h1", text: "Registration Ccs"
  end

  test "updating a Registration cc" do
    visit registration_cc_url(@registration_cc)
    click_on "Edit", match: :first

    fill_in "Player", with: @registration_cc.player_id
    fill_in "Registration list cc", with: @registration_cc.registration_list_cc_id
    fill_in "Status", with: @registration_cc.status
    click_on "Update Registration cc"

    assert_text "Registration cc was successfully updated"
    assert_selector "h1", text: "Registration Ccs"
  end

  test "destroying a Registration cc" do
    visit edit_registration_cc_url(@registration_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Registration cc was successfully destroyed"
  end
end
