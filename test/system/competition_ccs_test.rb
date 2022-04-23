require "application_system_test_case"

class CompetitionCcsTest < ApplicationSystemTestCase
  setup do
    @competition_cc = competition_ccs(:one)
  end

  test "visiting the index" do
    visit competition_ccs_url
    assert_selector "h1", text: "Competition Ccs"
  end

  test "creating a Competition cc" do
    visit competition_ccs_url
    click_on "New Competition Cc"

    fill_in "Branch cc", with: @competition_cc.branch_cc_id
    fill_in "Cc", with: @competition_cc.cc_id
    fill_in "Context", with: @competition_cc.context
    fill_in "Discipline", with: @competition_cc.discipline_id
    fill_in "Name", with: @competition_cc.name
    click_on "Create Competition cc"

    assert_text "Competition cc was successfully created"
    assert_selector "h1", text: "Competition Ccs"
  end

  test "updating a Competition cc" do
    visit competition_cc_url(@competition_cc)
    click_on "Edit", match: :first

    fill_in "Branch cc", with: @competition_cc.branch_cc_id
    fill_in "Cc", with: @competition_cc.cc_id
    fill_in "Context", with: @competition_cc.context
    fill_in "Discipline", with: @competition_cc.discipline_id
    fill_in "Name", with: @competition_cc.name
    click_on "Update Competition cc"

    assert_text "Competition cc was successfully updated"
    assert_selector "h1", text: "Competition Ccs"
  end

  test "destroying a Competition cc" do
    visit edit_competition_cc_url(@competition_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Competition cc was successfully destroyed"
  end
end
