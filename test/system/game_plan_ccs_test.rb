require "application_system_test_case"

class GamePlanCcsTest < ApplicationSystemTestCase
  setup do
    @game_plan_cc = game_plan_ccs(:one)
  end

  test "visiting the index" do
    visit game_plan_ccs_url
    assert_selector "h1", text: "Game Plan Ccs"
  end

  test "creating a Game plan cc" do
    visit game_plan_ccs_url
    click_on "New Game Plan Cc"

    fill_in "Bez brett", with: @game_plan_cc.bez_brett
    fill_in "Branch cc", with: @game_plan_cc.branch_cc_id
    fill_in "Cc", with: @game_plan_cc.cc_id
    fill_in "Data", with: @game_plan_cc.data
    fill_in "Discipline", with: @game_plan_cc.discipline_id
    fill_in "Ersatzspieler regel", with: @game_plan_cc.ersatzspieler_regel
    fill_in "Mb draw", with: @game_plan_cc.mb_draw
    fill_in "Mp lost", with: @game_plan_cc.mp_lost
    fill_in "Mp won", with: @game_plan_cc.mp_won
    fill_in "Name", with: @game_plan_cc.name
    fill_in "Pez partie", with: @game_plan_cc.pez_partie
    check "Plausi" if @game_plan_cc.plausi
    fill_in "Rang kegel", with: @game_plan_cc.rang_kegel
    fill_in "Rang mgd", with: @game_plan_cc.rang_mgd
    fill_in "Rang partie", with: @game_plan_cc.rang_partie
    fill_in "Row type", with: @game_plan_cc.row_type_id
    fill_in "Vorgabe", with: @game_plan_cc.vorgabe
    fill_in "Znp", with: @game_plan_cc.znp
    click_on "Create Game plan cc"

    assert_text "Game plan cc was successfully created"
    assert_selector "h1", text: "Game Plan Ccs"
  end

  test "updating a Game plan cc" do
    visit game_plan_cc_url(@game_plan_cc)
    click_on "Edit", match: :first

    fill_in "Bez brett", with: @game_plan_cc.bez_brett
    fill_in "Branch cc", with: @game_plan_cc.branch_cc_id
    fill_in "Cc", with: @game_plan_cc.cc_id
    fill_in "Data", with: @game_plan_cc.data
    fill_in "Discipline", with: @game_plan_cc.discipline_id
    fill_in "Ersatzspieler regel", with: @game_plan_cc.ersatzspieler_regel
    fill_in "Mb draw", with: @game_plan_cc.mb_draw
    fill_in "Mp lost", with: @game_plan_cc.mp_lost
    fill_in "Mp won", with: @game_plan_cc.mp_won
    fill_in "Name", with: @game_plan_cc.name
    fill_in "Pez partie", with: @game_plan_cc.pez_partie
    check "Plausi" if @game_plan_cc.plausi
    fill_in "Rang kegel", with: @game_plan_cc.rang_kegel
    fill_in "Rang mgd", with: @game_plan_cc.rang_mgd
    fill_in "Rang partie", with: @game_plan_cc.rang_partie
    fill_in "Row type", with: @game_plan_cc.row_type_id
    fill_in "Vorgabe", with: @game_plan_cc.vorgabe
    fill_in "Znp", with: @game_plan_cc.znp
    click_on "Update Game plan cc"

    assert_text "Game plan cc was successfully updated"
    assert_selector "h1", text: "Game Plan Ccs"
  end

  test "destroying a Game plan cc" do
    visit edit_game_plan_cc_url(@game_plan_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Game plan cc was successfully destroyed"
  end
end
