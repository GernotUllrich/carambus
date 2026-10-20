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

    # Path 1 darf nicht greifen, wenn die dbu_nr des cc_id-Treffers widerspricht
    # (Fremd-LV-Spieler mit derselben cc_id wie ein Spieler der Server-Region)
    test "cc_id hit with contradicting dbu_nr falls through to dbu_nr" do
      Player.create!(
        firstname: "Test15-02-Local", lastname: "SameCcId",
        region_id: @nbv.id, cc_id: 10_050, dbu_nr: 156_194
      )
      foreign = Player.create!(
        firstname: "Test15-02-Foreign", lastname: "SameCcId",
        region_id: @bbv.id, cc_id: 10_050, dbu_nr: 112_395
      )
      result = @matcher.match(cc_id: 10_050, dbu_nr: 112_395, firstname: nil, lastname: nil)
      assert_equal foreign.id, result&.id
    end

    # Gegenprobe: passende dbu_nr -> cc_id-Treffer bleibt
    test "cc_id hit with matching dbu_nr is kept" do
      local = Player.create!(
        firstname: "Test15-02-Local", lastname: "SameDbu",
        region_id: @nbv.id, cc_id: 10_051, dbu_nr: 156_195
      )
      result = @matcher.match(cc_id: 10_051, dbu_nr: "156195", firstname: nil, lastname: nil)
      assert_equal local.id, result&.id
    end

    # Betreiber 2026-10-20: die DBU-Nummer entscheidet, auch wenn eine cc_id in der Region trifft
    # (Spieler sind teils in mehreren Vereinen/Landesverbaenden; cc_id nur je Region eindeutig).
    test "dbu_nr schlaegt einen cc_id-Treffer ohne dbu_nr in der eigenen Region" do
      Player.create!(firstname: "Test15-02-Local", lastname: "NoDbu", region_id: @nbv.id, cc_id: 10_060)
      foreign = Player.create!(firstname: "Test15-02-Foreign", lastname: "WithDbu",
        region_id: @bbv.id, cc_id: 10_060, dbu_nr: 112_396)

      result = @matcher.match(cc_id: 10_060, dbu_nr: "112396", firstname: nil, lastname: nil)

      assert_equal foreign.id, result&.id
    end

    test "doppelte dbu_nr: region+cc_id entscheidet, sonst der Name, Teams nie" do
      older = Player.create!(firstname: "Test15-02-Old", lastname: "Dup", dbu_nr: 999_001)
      local = Player.create!(firstname: "Test15-02-Local", lastname: "Dup", dbu_nr: 999_001,
        region_id: @nbv.id, cc_id: 10_070)
      Team.create!(firstname: "Test15-02-Team", lastname: "Dup", dbu_nr: 999_001)

      assert_equal local.id, @matcher.match(cc_id: 10_070, dbu_nr: 999_001)&.id, "region+cc_id"
      assert_equal older.id, @matcher.match(dbu_nr: 999_001, firstname: "Test15-02-Old", lastname: "Dup")&.id, "Name"
      assert_equal older.id, @matcher.match(dbu_nr: 999_001)&.id, "sonst der aelteste Datensatz"
    end

    test "Team-Datensatz mit dbu_nr wird nie als Spieler getroffen" do
      Team.create!(firstname: "Test15-02-OnlyTeam", lastname: "T", dbu_nr: 999_002)

      assert_nil @matcher.match(dbu_nr: 999_002)
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
