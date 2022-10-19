require "test_helper"

class TournamentSeriesCcsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tournament_series_cc = tournament_series_ccs(:one)
  end

  test "should get index" do
    get tournament_series_ccs_url
    assert_response :success
  end

  test "should get new" do
    get new_tournament_series_cc_url
    assert_response :success
  end

  test "should create tournament_series_cc" do
    assert_difference('TournamentSeriesCc.count') do
      post tournament_series_ccs_url, params: { tournament_series_cc: { branch_cc_id: @tournament_series_cc.branch_cc_id, cc_id: @tournament_series_cc.cc_id, club_id: @tournament_series_cc.club_id, currency: @tournament_series_cc.currency, data: @tournament_series_cc.data, jackpot: @tournament_series_cc.jackpot, min_points: @tournament_series_cc.min_points, name: @tournament_series_cc.name, no_tournaments: @tournament_series_cc.no_tournaments, point_formula: @tournament_series_cc.point_formula, point_fraction: @tournament_series_cc.point_fraction, price_money: @tournament_series_cc.price_money, season: @tournament_series_cc.season, series_valuation: @tournament_series_cc.series_valuation, show_jackpot: @tournament_series_cc.show_jackpot, status: @tournament_series_cc.status, valuation: @tournament_series_cc.valuation } }
    end

    assert_redirected_to tournament_series_cc_url(TournamentSeriesCc.last)
  end

  test "should show tournament_series_cc" do
    get tournament_series_cc_url(@tournament_series_cc)
    assert_response :success
  end

  test "should get edit" do
    get edit_tournament_series_cc_url(@tournament_series_cc)
    assert_response :success
  end

  test "should update tournament_series_cc" do
    patch tournament_series_cc_url(@tournament_series_cc), params: { tournament_series_cc: { branch_cc_id: @tournament_series_cc.branch_cc_id, cc_id: @tournament_series_cc.cc_id, club_id: @tournament_series_cc.club_id, currency: @tournament_series_cc.currency, data: @tournament_series_cc.data, jackpot: @tournament_series_cc.jackpot, min_points: @tournament_series_cc.min_points, name: @tournament_series_cc.name, no_tournaments: @tournament_series_cc.no_tournaments, point_formula: @tournament_series_cc.point_formula, point_fraction: @tournament_series_cc.point_fraction, price_money: @tournament_series_cc.price_money, season: @tournament_series_cc.season, series_valuation: @tournament_series_cc.series_valuation, show_jackpot: @tournament_series_cc.show_jackpot, status: @tournament_series_cc.status, valuation: @tournament_series_cc.valuation } }
    assert_redirected_to tournament_series_cc_url(@tournament_series_cc)
  end

  test "should destroy tournament_series_cc" do
    assert_difference('TournamentSeriesCc.count', -1) do
      delete tournament_series_cc_url(@tournament_series_cc)
    end

    assert_redirected_to tournament_series_ccs_url
  end
end
