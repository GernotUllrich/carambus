# frozen_string_literal: true

require "test_helper"

module NuLiga
  class ScraperTest < ActiveSupport::TestCase
    def build_scraper
      Scraper.new(federation: "BBV", season: "2025/2026")
    end

    test "leagues lists a branch's groups with ids" do
      VCR.use_cassette("nuliga/leaguePage_pool_2025-26") do
        leagues = build_scraper.leagues("Pool")
        assert_operator leagues.size, :>, 0
        first = leagues.first
        assert_kind_of Integer, first[:group_id]
        assert first[:name].present?
        # eindeutige group_ids
        assert_equal leagues.map { |l| l[:group_id] }.uniq.size, leagues.size
      end
    end

    test "group parses the standings table into teams with teamtable ids and data" do
      VCR.use_cassette("nuliga/groupPage_pool_group1001") do
        grp = build_scraper.group(1001, branch: "Pool")
        assert_equal 1001, grp[:group_id]
        assert grp[:name].present?
        assert_operator grp[:teams].size, :>, 0

        top = grp[:teams].first
        assert_kind_of Integer, top[:teamtable_id]
        assert top[:name].present?
        assert_kind_of Integer, top[:rank]
        assert top[:data].key?(:punkte)
        assert top[:data].key?(:begegnungen)
      end
    end

    test "group is robust against rows without a team link" do
      VCR.use_cassette("nuliga/groupPage_pool_group1001") do
        assert_nothing_raised { build_scraper.group(1001, branch: "Pool") }
      end
    end

    test "meetings lists begegnungen with meeting ids, dates and teams" do
      VCR.use_cassette("nuliga/groupPage_meetings_group1001") do
        meetings = build_scraper.meetings(1001, branch: "Pool")
        assert_operator meetings.size, :>, 0

        first = meetings.first
        assert_kind_of Integer, first[:meeting_id]
        assert_match(/\d{2}\.\d{2}\.\d{4}/, first[:date])
        assert first[:home_team].present?
        assert first[:guest_team].present?
        # keine Header-/Trennzeilen als Begegnung
        assert(meetings.all? { |m| m[:meeting_id].is_a?(Integer) })
      end
    end

    test "meeting_report returns parsed single games incl. doubles, stats and final result" do
      VCR.use_cassette("nuliga/groupMeetingReport_7112978") do
        report = build_scraper.meeting_report(7112978, group_id: 1001, branch: "Pool")
        assert report[:home_team].present?
        assert_operator report[:games].size, :>, 0
        assert report[:final_result][:home].is_a?(Integer)

        doubles = report[:games].find { |g| g[:home_players].size == 2 }
        assert doubles, "expected a doubles game with two home players"
        assert report[:games].any? { |g| g[:stats] }, "expected at least one game with inline stats"
      end
    end

    test "team returns teamtable with own club_id and name" do
      VCR.use_cassette("nuliga/teamPortrait_1809539") do
        t = build_scraper.team(1809539, group_id: 1001, branch: "Pool")
        assert_equal 1809539, t[:teamtable_id]
        assert_kind_of Integer, t[:club][:club_id]
        assert t[:club][:name].present?
      end
    end

    test "player_ranking lists roster with person ids and team names" do
      VCR.use_cassette("nuliga/groupPlayerRankingLists_group1001") do
        roster = build_scraper.player_ranking(1001, branch: "Pool")
        assert_operator roster.size, :>, 0

        first = roster.first
        assert_kind_of Integer, first[:person_id]
        assert_match(/,/, first[:name])   # "Nachname, Vorname"
        assert first[:team_name].present?
      end
    end
  end
end
