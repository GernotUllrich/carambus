require "application_system_test_case"

class TournamentSeriesCcsTest < ApplicationSystemTestCase
  setup do
    @tournament_series_cc = tournament_series_ccs(:one)
  end

  test "visiting the index" do
    visit tournament_series_ccs_url
    assert_selector "h1", text: "Tournament Series Ccs"
  end

  test "creating a Tournament series cc" do
    visit tournament_series_ccs_url
    click_on "New Tournament Series Cc"

    fill_in "Branch cc", with: @tournament_series_cc.branch_cc_id
    fill_in "Cc", with: @tournament_series_cc.cc_id
    fill_in "Club", with: @tournament_series_cc.club_id
    fill_in "Currency", with: @tournament_series_cc.currency
    fill_in "Data", with: @tournament_series_cc.data
    fill_in "Jackpot", with: @tournament_series_cc.jackpot
    fill_in "Min points", with: @tournament_series_cc.min_points
    fill_in "Name", with: @tournament_series_cc.name
    fill_in "No tournaments", with: @tournament_series_cc.no_tournaments
    fill_in "Point formula", with: @tournament_series_cc.point_formula
    fill_in "Point fraction", with: @tournament_series_cc.point_fraction
    fill_in "Price money", with: @tournament_series_cc.price_money
    fill_in "Season", with: @tournament_series_cc.season
    fill_in "Series valuation", with: @tournament_series_cc.series_valuation
    fill_in "Show jackpot", with: @tournament_series_cc.show_jackpot
    fill_in "Status", with: @tournament_series_cc.status
    fill_in "Valuation", with: @tournament_series_cc.valuation
    click_on "Create Tournament series cc"

    assert_text "Tournament series cc was successfully created"
    assert_selector "h1", text: "Tournament Series Ccs"
  end

  test "updating a Tournament series cc" do
    visit tournament_series_cc_url(@tournament_series_cc)
    click_on "Edit", match: :first

    fill_in "Branch cc", with: @tournament_series_cc.branch_cc_id
    fill_in "Cc", with: @tournament_series_cc.cc_id
    fill_in "Club", with: @tournament_series_cc.club_id
    fill_in "Currency", with: @tournament_series_cc.currency
    fill_in "Data", with: @tournament_series_cc.data
    fill_in "Jackpot", with: @tournament_series_cc.jackpot
    fill_in "Min points", with: @tournament_series_cc.min_points
    fill_in "Name", with: @tournament_series_cc.name
    fill_in "No tournaments", with: @tournament_series_cc.no_tournaments
    fill_in "Point formula", with: @tournament_series_cc.point_formula
    fill_in "Point fraction", with: @tournament_series_cc.point_fraction
    fill_in "Price money", with: @tournament_series_cc.price_money
    fill_in "Season", with: @tournament_series_cc.season
    fill_in "Series valuation", with: @tournament_series_cc.series_valuation
    fill_in "Show jackpot", with: @tournament_series_cc.show_jackpot
    fill_in "Status", with: @tournament_series_cc.status
    fill_in "Valuation", with: @tournament_series_cc.valuation
    click_on "Update Tournament series cc"

    assert_text "Tournament series cc was successfully updated"
    assert_selector "h1", text: "Tournament Series Ccs"
  end

  test "destroying a Tournament series cc" do
    visit edit_tournament_series_cc_url(@tournament_series_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Tournament series cc was successfully destroyed"
  end
end
