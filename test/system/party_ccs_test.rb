require "application_system_test_case"

class PartyCcsTest < ApplicationSystemTestCase
  setup do
    @party_cc = party_ccs(:one)
  end

  test "visiting the index" do
    visit party_ccs_url
    assert_selector "h1", text: "Party Ccs"
  end

  test "creating a Party cc" do
    visit party_ccs_url
    click_on "New Party Cc"

    fill_in "Cc", with: @party_cc.cc_id
    fill_in "Data", with: @party_cc.data
    fill_in "Day seqno", with: @party_cc.day_seqno
    fill_in "Integer", with: @party_cc.integer
    fill_in "League cc", with: @party_cc.league_cc_id
    fill_in "League team a cc", with: @party_cc.league_team_a_cc_id
    fill_in "League team b cc", with: @party_cc.league_team_b_cc_id
    fill_in "League team host cc", with: @party_cc.league_team_host_cc_id
    fill_in "Party", with: @party_cc.party_id
    fill_in "Remarks", with: @party_cc.remarks
    click_on "Create Party cc"

    assert_text "Party cc was successfully created"
    assert_selector "h1", text: "Party Ccs"
  end

  test "updating a Party cc" do
    visit party_cc_url(@party_cc)
    click_on "Edit", match: :first

    fill_in "Cc", with: @party_cc.cc_id
    fill_in "Data", with: @party_cc.data
    fill_in "Day seqno", with: @party_cc.day_seqno
    fill_in "Integer", with: @party_cc.integer
    fill_in "League cc", with: @party_cc.league_cc_id
    fill_in "League team a cc", with: @party_cc.league_team_a_cc_id
    fill_in "League team b cc", with: @party_cc.league_team_b_cc_id
    fill_in "League team host cc", with: @party_cc.league_team_host_cc_id
    fill_in "Party", with: @party_cc.party_id
    fill_in "Remarks", with: @party_cc.remarks
    click_on "Update Party cc"

    assert_text "Party cc was successfully updated"
    assert_selector "h1", text: "Party Ccs"
  end

  test "destroying a Party cc" do
    visit edit_party_cc_url(@party_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Party cc was successfully destroyed"
  end
end
