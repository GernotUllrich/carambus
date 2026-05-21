# frozen_string_literal: true

require "test_helper"

# Plan 18-01: Tests fuer ExternalTournament::ClubRosterQuery.
#
# Read-only Discovery-Substrat: clubs(region) + players(region:, club:, season:).
# Eligibility strikt status="active" der laufenden Saison (D-18-01-A), region-scoped
# (D-18-01-D), dbu_nr als String durchgereicht (nullable).
module ExternalTournament
  class ClubRosterQueryTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @season = Season.create!(name: "ROSTER-2099/2100")
      @club = Club.create!(region: @nbv, cc_id: 180_101, shortname: "TST-RC", name: "Test Roster Club")
      @other_club = Club.create!(region: @nbv, cc_id: 180_102, shortname: "TST-RC2", name: "Other Roster Club")
    end

    teardown do
      SeasonParticipation.where(season_id: @season&.id).delete_all
      Player.where("firstname LIKE ?", "Test18-01-%").delete_all
      Club.where(cc_id: [180_101, 180_102]).delete_all
      @season&.destroy
    end

    def make_player(suffix, cc_id, dbu_nr)
      Player.create!(firstname: "Test18-01-#{suffix}", lastname: "Roster#{suffix}",
        region_id: @nbv.id, cc_id: cc_id, dbu_nr: dbu_nr)
    end

    def participate(player, club, status)
      SeasonParticipation.create!(season: @season, club: club, player: player, status: status)
    end

    test "players returns only status=active, with cc_id+firstname+lastname+dbu_nr(String)+status" do
      active = make_player("Active", 180_111, 91_001)
      participate(active, @club, "active")
      participate(make_player("Temp", 180_112, 91_002), @club, "temporary")
      participate(make_player("Guest", 180_113, 91_003), @club, "guest")
      participate(make_player("Nil", 180_114, 91_004), @club, nil)

      rows = ClubRosterQuery.players(region: @nbv, club: @club, season: @season)

      assert_equal [180_111], rows.map { |r| r[:cc_id] }, "only active participation returned"
      row = rows.first
      assert_equal "active", row[:status]
      assert_equal "91001", row[:dbu_nr], "dbu_nr emitted as String"
      assert_equal "Test18-01-Active", row[:firstname]
      assert_equal "RosterActive", row[:lastname]
    end

    test "players is club-scoped (excludes other clubs of same region)" do
      participate(make_player("C1", 180_121, 92_001), @club, "active")
      participate(make_player("C2", 180_122, 92_002), @other_club, "active")

      rows = ClubRosterQuery.players(region: @nbv, club: @club, season: @season)
      assert_equal [180_121], rows.map { |r| r[:cc_id] }
    end

    test "players passes through nil dbu_nr" do
      participate(make_player("NoDbu", 180_131, nil), @club, "active")
      rows = ClubRosterQuery.players(region: @nbv, club: @club, season: @season)
      assert_nil rows.first[:dbu_nr]
    end

    test "players defaults to Season.current_season" do
      participate(make_player("Default", 180_141, 93_001), @club, "active")
      Season.stub(:current_season, @season) do
        rows = ClubRosterQuery.players(region: @nbv, club: @club)
        assert_equal [180_141], rows.map { |r| r[:cc_id] }
      end
    end

    test "clubs returns region clubs with cc_id as {cc_id,shortname,name}, sorted by shortname" do
      rows = ClubRosterQuery.clubs(@nbv)
      mine = rows.select { |r| [180_101, 180_102].include?(r[:cc_id]) }
      assert_equal 2, mine.size
      assert(mine.all? { |r| r.key?(:cc_id) && r.key?(:shortname) && r.key?(:name) })
      assert(rows.index { |r| r[:cc_id] == 180_101 } < rows.index { |r| r[:cc_id] == 180_102 },
        "stable sort by shortname (TST-RC before TST-RC2)")
    end

    test "find_club is region-scoped via cc_id" do
      assert_equal @club, ClubRosterQuery.find_club(@nbv, 180_101)
      assert_nil ClubRosterQuery.find_club(@nbv, 999_999)
    end
  end
end
