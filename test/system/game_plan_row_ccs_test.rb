require "application_system_test_case"

class GamePlanRowCcsTest < ApplicationSystemTestCase
  setup do
    @game_plan_row_cc = game_plan_row_ccs(:one)
  end

  test "visiting the index" do
    visit game_plan_row_ccs_url
    assert_selector "h1", text: "Game Plan Row Ccs"
  end

  test "creating a Game plan row cc" do
    visit game_plan_row_ccs_url
    click_on "New Game Plan Row Cc"

    fill_in "Cc", with: @game_plan_row_cc.cc_id
    fill_in "Discipline", with: @game_plan_row_cc.discipline_id
    fill_in "Game plan", with: @game_plan_row_cc.game_plan_id
    fill_in "Home brett", with: @game_plan_row_cc.home_brett
    fill_in "Mpg", with: @game_plan_row_cc.mpg
    fill_in "Pmv", with: @game_plan_row_cc.pmv
    fill_in "Ppg", with: @game_plan_row_cc.ppg
    fill_in "Ppu", with: @game_plan_row_cc.ppu
    fill_in "Ppv", with: @game_plan_row_cc.ppv
    fill_in "Score", with: @game_plan_row_cc.score
    fill_in "Sets", with: @game_plan_row_cc.sets
    fill_in "Visitor brett", with: @game_plan_row_cc.visitor_brett
    click_on "Create Game plan row cc"

    assert_text "Game plan row cc was successfully created"
    assert_selector "h1", text: "Game Plan Row Ccs"
  end

  test "updating a Game plan row cc" do
    visit game_plan_row_cc_url(@game_plan_row_cc)
    click_on "Edit", match: :first

    fill_in "Cc", with: @game_plan_row_cc.cc_id
    fill_in "Discipline", with: @game_plan_row_cc.discipline_id
    fill_in "Game plan", with: @game_plan_row_cc.game_plan_id
    fill_in "Home brett", with: @game_plan_row_cc.home_brett
    fill_in "Mpg", with: @game_plan_row_cc.mpg
    fill_in "Pmv", with: @game_plan_row_cc.pmv
    fill_in "Ppg", with: @game_plan_row_cc.ppg
    fill_in "Ppu", with: @game_plan_row_cc.ppu
    fill_in "Ppv", with: @game_plan_row_cc.ppv
    fill_in "Score", with: @game_plan_row_cc.score
    fill_in "Sets", with: @game_plan_row_cc.sets
    fill_in "Visitor brett", with: @game_plan_row_cc.visitor_brett
    click_on "Update Game plan row cc"

    assert_text "Game plan row cc was successfully updated"
    assert_selector "h1", text: "Game Plan Row Ccs"
  end

  test "destroying a Game plan row cc" do
    visit edit_game_plan_row_cc_url(@game_plan_row_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Game plan row cc was successfully destroyed"
  end
end
