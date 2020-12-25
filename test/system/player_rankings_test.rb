require "application_system_test_case"

class PlayerRankingsTest < ApplicationSystemTestCase
  setup do
    @player_ranking = player_rankings(:one)
  end

  test "visiting the index" do
    visit player_rankings_url
    assert_selector "h1", text: "Player Rankings"
  end

  test "creating a Player ranking" do
    visit player_rankings_url
    click_on "New Player Ranking"

    fill_in "Balls", with: @player_ranking.balls
    fill_in "Bed", with: @player_ranking.bed
    fill_in "Btg", with: @player_ranking.btg
    fill_in "Discipline", with: @player_ranking.discipline_id
    fill_in "G", with: @player_ranking.g
    fill_in "Gd", with: @player_ranking.gd
    fill_in "Hs", with: @player_ranking.hs
    fill_in "Org level", with: @player_ranking.org_level
    fill_in "P gd", with: @player_ranking.p_gd
    fill_in "P player class", with: @player_ranking.p_player_class_id
    fill_in "Player class", with: @player_ranking.player_class_id
    fill_in "Player", with: @player_ranking.player_id
    fill_in "Points", with: @player_ranking.points
    fill_in "Pp gd", with: @player_ranking.pp_gd
    fill_in "Pp player class", with: @player_ranking.pp_player_class_id
    fill_in "Quote", with: @player_ranking.quote
    fill_in "Rank", with: @player_ranking.rank
    fill_in "Region", with: @player_ranking.region_id
    fill_in "Remarks", with: @player_ranking.remarks
    fill_in "Season", with: @player_ranking.season_id
    fill_in "Sets", with: @player_ranking.sets
    fill_in "Sp g", with: @player_ranking.sp_g
    fill_in "Sp quote", with: @player_ranking.sp_quote
    fill_in "Sp v", with: @player_ranking.sp_v
    fill_in "Status", with: @player_ranking.status
    fill_in "T ids", with: @player_ranking.t_ids
    fill_in "Tournament player class", with: @player_ranking.tournament_player_class_id
    fill_in "V", with: @player_ranking.v
    click_on "Create Player ranking"

    assert_text "Player ranking was successfully created"
    assert_selector "h1", text: "Player Rankings"
  end

  test "updating a Player ranking" do
    visit player_ranking_url(@player_ranking)
    click_on "Edit", match: :first

    fill_in "Balls", with: @player_ranking.balls
    fill_in "Bed", with: @player_ranking.bed
    fill_in "Btg", with: @player_ranking.btg
    fill_in "Discipline", with: @player_ranking.discipline_id
    fill_in "G", with: @player_ranking.g
    fill_in "Gd", with: @player_ranking.gd
    fill_in "Hs", with: @player_ranking.hs
    fill_in "Org level", with: @player_ranking.org_level
    fill_in "P gd", with: @player_ranking.p_gd
    fill_in "P player class", with: @player_ranking.p_player_class_id
    fill_in "Player class", with: @player_ranking.player_class_id
    fill_in "Player", with: @player_ranking.player_id
    fill_in "Points", with: @player_ranking.points
    fill_in "Pp gd", with: @player_ranking.pp_gd
    fill_in "Pp player class", with: @player_ranking.pp_player_class_id
    fill_in "Quote", with: @player_ranking.quote
    fill_in "Rank", with: @player_ranking.rank
    fill_in "Region", with: @player_ranking.region_id
    fill_in "Remarks", with: @player_ranking.remarks
    fill_in "Season", with: @player_ranking.season_id
    fill_in "Sets", with: @player_ranking.sets
    fill_in "Sp g", with: @player_ranking.sp_g
    fill_in "Sp quote", with: @player_ranking.sp_quote
    fill_in "Sp v", with: @player_ranking.sp_v
    fill_in "Status", with: @player_ranking.status
    fill_in "T ids", with: @player_ranking.t_ids
    fill_in "Tournament player class", with: @player_ranking.tournament_player_class_id
    fill_in "V", with: @player_ranking.v
    click_on "Update Player ranking"

    assert_text "Player ranking was successfully updated"
    assert_selector "h1", text: "Player Rankings"
  end

  test "destroying a Player ranking" do
    visit edit_player_ranking_url(@player_ranking)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Player ranking was successfully destroyed"
  end
end
