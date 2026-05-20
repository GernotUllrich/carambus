# frozen_string_literal: true

require "test_helper"

# Plan 17-06: Tests fuer ExternalTournament::PlayerReconciler.
#
# Batch-Wrapper um PlayerMatcher: liefert pro Eintrag dbu_nr + kanonischen Player,
# region-scoped, KEIN Player-Create (D-17-vision-2 / D-17-06-C).
module ExternalTournament
  class PlayerReconcilerTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @bbv = regions(:bbv)
      @reconciler = ExternalTournament::PlayerReconciler.new(region: @nbv)
    end

    teardown do
      Player.where("firstname LIKE ?", "Test17-06-%").delete_all
    end

    # Happy-Path: gemischte Liste (matched via cc_id + matched via dbu_nr + unmatched)
    test "reconciles a mixed list — matched entries carry dbu_nr, unmatched are matched:false" do
      p_cc = Player.create!(
        firstname: "Test17-06-CcId", lastname: "Match",
        region_id: @nbv.id, cc_id: 17_061, dbu_nr: 17_900
      )
      p_dbu = Player.create!(
        firstname: "Test17-06-Dbu", lastname: "Match",
        region_id: @bbv.id, cc_id: 17_062, dbu_nr: 17_901
      )

      results = @reconciler.call(participants: [
        {ref: "a", cc_id: 17_061},
        {ref: "b", cc_id: 999_999, dbu_nr: "17901"},
        {ref: "c", firstname: "Test17-06-Ghost", lastname: "Nobody"}
      ])

      assert_equal 3, results.size

      first = results[0]
      assert_equal "a", first[:ref]
      assert_equal true, first[:matched]
      assert_equal p_cc.id, first[:player][:id]
      assert_equal "17900", first[:player][:dbu_nr], "dbu_nr als String zurueckgegeben"

      second = results[1]
      assert_equal true, second[:matched], "Cross-Region-dbu_nr-Fallback matcht"
      assert_equal p_dbu.id, second[:player][:id]
      assert_equal "17901", second[:player][:dbu_nr]

      third = results[2]
      assert_equal "c", third[:ref]
      assert_equal false, third[:matched]
      assert_nil third[:player]
    end

    # KEIN Create: ein nicht-matchbarer Eintrag legt keinen Player an
    test "does not create players for unmatched entries" do
      before = Player.count
      results = @reconciler.call(participants: [
        {ref: "x", cc_id: 888_888, firstname: "Test17-06-NoCreate", lastname: "Ever"}
      ])
      assert_equal false, results.first[:matched]
      assert_equal before, Player.count, "PlayerReconciler darf keine Player anlegen"
    end

    # club wird serialisiert wenn vorhanden
    test "includes club when player has one" do
      club = clubs(:bcw)
      player = Player.create!(firstname: "Test17-06-Club", lastname: "Member", region_id: @nbv.id, cc_id: 17_063)
      # clubs laeuft ueber season_participations → Mitgliedschaft fuer die aktuelle Season anlegen.
      SeasonParticipation.create!(player: player, club: club, season: seasons(:current))

      results = @reconciler.call(participants: [{ref: "k", cc_id: 17_063}])
      assert_equal true, results.first[:matched]
      club_hash = results.first.dig(:player, :club)
      assert_not_nil club_hash, "club serialisiert"
      assert_equal club.shortname, club_hash[:shortname]
    end

    # leere Liste → leeres Ergebnis (kein Crash)
    test "returns empty array for empty participants" do
      assert_equal [], @reconciler.call(participants: [])
    end

    # String-Keys werden akzeptiert (analog PlayerMatcher symbolize)
    test "accepts participant hashes with string keys" do
      player = Player.create!(firstname: "Test17-06-Str", lastname: "Keys", region_id: @nbv.id, cc_id: 17_064)
      results = @reconciler.call(participants: [{"ref" => "s", "cc_id" => 17_064}])
      assert_equal true, results.first[:matched]
      assert_equal player.id, results.first.dig(:player, :id)
      assert_equal "s", results.first[:ref]
    end
  end
end
