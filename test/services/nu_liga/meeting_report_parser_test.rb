# frozen_string_literal: true

require "test_helper"

module NuLiga
  class MeetingReportParserTest < ActiveSupport::TestCase
    # Reales Recon-Fixture (03) — wie der Client gereinigt (WebObjects-Artefakte), damit Nokogiri
    # die Tabelle findet. Deterministisch, kein Netz.
    def parsed
      raw = File.read(Rails.root.join("test/snapshots/vcr/nuliga/03_groupMeetingReport_7112978.html"))
      html = raw.gsub("//--", "--")
        .gsub(%r{<meta name="uLigaStatsRefUrl"\s*/>}, "")
        .gsub("</meta>", "")
      MeetingReportParser.new(html).parse
    end

    test "parses the meeting header teams" do
      result = parsed
      assert result[:home_team].present?
      assert result[:guest_team].present?
    end

    test "parses single games with discipline, players, set result and match points" do
      games = parsed[:games]
      assert_operator games.size, :>, 0

      single = games.find { |g| g[:home_players].size == 1 && !g[:discipline].include?("Doppel") }
      assert single, "expected at least one singles game"
      assert single[:discipline].present?
      assert_equal 1, single[:guest_players].size
      assert_match(/\d+\s*:\s*\d+/, single[:set_result])
      assert_match(/\d+\s*:\s*\d+/, single[:match_points])
    end

    test "parses doubles with two players per side from person links" do
      doubles = parsed[:games].find { |g| g[:discipline].include?("Doppel") }
      assert doubles, "expected a doubles game"
      assert_equal 2, doubles[:home_players].size
      assert_equal 2, doubles[:guest_players].size
    end

    test "parses inline statistics (balls/innings/hs) for 8-cell rows" do
      with_stats = parsed[:games].find { |g| g[:stats] }
      assert with_stats, "expected at least one game with inline stats"
      assert with_stats[:stats][:balls].key?(:home)
      assert with_stats[:stats][:balls].key?(:guest)
      assert_kind_of Integer, with_stats[:stats][:balls][:home]
    end

    test "positions are a running 1-based index over games" do
      games = parsed[:games]
      assert_equal (1..games.size).to_a, games.map { |g| g[:position] }
    end

    test "parses the final result from the summary row" do
      final = parsed[:final_result]
      assert final, "expected a final result"
      assert_kind_of Integer, final[:home]
      assert_kind_of Integer, final[:guest]
    end
  end
end
