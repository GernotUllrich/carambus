require 'test_helper'

class PlayerRankingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @player_ranking = player_rankings(:one)
  end

  test "should get index" do
    get player_rankings_url
    assert_response :success
  end

  test "should get new" do
    get new_player_ranking_url
    assert_response :success
  end

  test "should create player_ranking" do
    assert_difference('PlayerRanking.count') do
      post player_rankings_url, params: { player_ranking: { balls: @player_ranking.balls, bed: @player_ranking.bed, btg: @player_ranking.btg, discipline_id: @player_ranking.discipline_id, g: @player_ranking.g, gd: @player_ranking.gd, hs: @player_ranking.hs, org_level: @player_ranking.org_level, p_gd: @player_ranking.p_gd, p_player_class_id: @player_ranking.p_player_class_id, player_class_id: @player_ranking.player_class_id, player_id: @player_ranking.player_id, points: @player_ranking.points, pp_gd: @player_ranking.pp_gd, pp_player_class_id: @player_ranking.pp_player_class_id, quote: @player_ranking.quote, rank: @player_ranking.rank, region_id: @player_ranking.region_id, remarks: @player_ranking.remarks, season_id: @player_ranking.season_id, sets: @player_ranking.sets, sp_g: @player_ranking.sp_g, sp_quote: @player_ranking.sp_quote, sp_v: @player_ranking.sp_v, status: @player_ranking.status, t_ids: @player_ranking.t_ids, tournament_player_class_id: @player_ranking.tournament_player_class_id, v: @player_ranking.v } }
    end

    assert_redirected_to player_ranking_url(PlayerRanking.last)
  end

  test "should show player_ranking" do
    get player_ranking_url(@player_ranking)
    assert_response :success
  end

  test "should get edit" do
    get edit_player_ranking_url(@player_ranking)
    assert_response :success
  end

  test "should update player_ranking" do
    patch player_ranking_url(@player_ranking), params: { player_ranking: { balls: @player_ranking.balls, bed: @player_ranking.bed, btg: @player_ranking.btg, discipline_id: @player_ranking.discipline_id, g: @player_ranking.g, gd: @player_ranking.gd, hs: @player_ranking.hs, org_level: @player_ranking.org_level, p_gd: @player_ranking.p_gd, p_player_class_id: @player_ranking.p_player_class_id, player_class_id: @player_ranking.player_class_id, player_id: @player_ranking.player_id, points: @player_ranking.points, pp_gd: @player_ranking.pp_gd, pp_player_class_id: @player_ranking.pp_player_class_id, quote: @player_ranking.quote, rank: @player_ranking.rank, region_id: @player_ranking.region_id, remarks: @player_ranking.remarks, season_id: @player_ranking.season_id, sets: @player_ranking.sets, sp_g: @player_ranking.sp_g, sp_quote: @player_ranking.sp_quote, sp_v: @player_ranking.sp_v, status: @player_ranking.status, t_ids: @player_ranking.t_ids, tournament_player_class_id: @player_ranking.tournament_player_class_id, v: @player_ranking.v } }
    assert_redirected_to player_ranking_url(@player_ranking)
  end

  test "should destroy player_ranking" do
    assert_difference('PlayerRanking.count', -1) do
      delete player_ranking_url(@player_ranking)
    end

    assert_redirected_to player_rankings_url
  end
end
