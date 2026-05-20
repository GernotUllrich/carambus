# frozen_string_literal: true

require "test_helper"

# Plan 15-02 Task 3: Tests für ExternalTournament::PlayerMatcher.
#
# Validiert 3-Path-Fallback-Kette: region+cc_id → dbu_nr → name+club.
module ExternalTournament
  class PlayerMatcherTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @bbv = regions(:bbv)
      @matcher = ExternalTournament::PlayerMatcher.new(region: @nbv)
    end

    # Cleanup für inline-erstellte Player
    teardown do
      Player.where("firstname LIKE ?", "Test15-02-%").delete_all
    end

    # Path 1: region+cc_id positiv (Player in NBV mit cc_id=9001 → match)
    test "matches player by region+cc_id when player exists in region" do
      player = Player.create!(
        firstname: "Test15-02-One", lastname: "MatchByCcId",
        region_id: @nbv.id, cc_id: 9_001
      )
      result = @matcher.match(cc_id: 9_001, dbu_nr: nil, firstname: nil, lastname: nil)
      assert_equal player.id, result&.id
    end

    # Path 1: region+cc_id negativ (Cross-Region — selber cc_id in BVBW darf nicht matchen)
    test "does NOT match player when cc_id exists in different region" do
      Player.create!(
        firstname: "Test15-02-Two", lastname: "WrongRegion",
        region_id: @bbv.id, cc_id: 9_001
      )
      result = @matcher.match(cc_id: 9_001, dbu_nr: nil, firstname: nil, lastname: nil)
      assert_nil result, "Cross-region cc_id should not match (region-scoped Path 1)"
    end

    # Path 2: dbu_nr (cross-region — DBU-Mitgliedschaft global eindeutig)
    test "matches player by dbu_nr when cc_id path fails" do
      player = Player.create!(
        firstname: "Test15-02-Three", lastname: "MatchByDbuNr",
        region_id: @bbv.id, cc_id: 7_777, dbu_nr: 12_001
      )
      # Input mit cc_id=9999 (nicht in NBV vorhanden) und dbu_nr=12_001
      result = @matcher.match(cc_id: 9_999, dbu_nr: "12001", firstname: nil, lastname: nil)
      assert_equal player.id, result&.id, "Path 2 (dbu_nr cross-region) should match"
    end

    # Path 3: firstname+lastname
    test "matches player by firstname+lastname when cc_id and dbu_nr paths fail" do
      player = Player.create!(
        firstname: "Test15-02-Hans", lastname: "Müller",
        region_id: @nbv.id, cc_id: 5_555, dbu_nr: 8_888
      )
      result = @matcher.match(
        cc_id: nil, dbu_nr: nil,
        firstname: "Test15-02-Hans", lastname: "Müller"
      )
      assert_equal player.id, result&.id
    end

    # No-Match: nil (KEINE Exception)
    test "returns nil when no path matches without raising" do
      assert_nothing_raised do
        result = @matcher.match(
          cc_id: 99_999, dbu_nr: "99999",
          firstname: "Test15-02-NonExistent", lastname: "NobodyHere"
        )
        assert_nil result
      end
    end

    # Empty-Attrs: nil
    test "returns nil for empty attrs without raising" do
      assert_nothing_raised do
        result = @matcher.match(cc_id: nil, dbu_nr: nil, firstname: nil, lastname: nil)
        assert_nil result
      end
    end

    # Attrs as String keys (symbolize_keys-Test)
    test "accepts attrs with String keys (auto-symbolize)" do
      player = Player.create!(
        firstname: "Test15-02-StringKey", lastname: "Works",
        region_id: @nbv.id, cc_id: 6_001
      )
      result = @matcher.match("cc_id" => 6_001)
      assert_equal player.id, result&.id
    end
  end
end
