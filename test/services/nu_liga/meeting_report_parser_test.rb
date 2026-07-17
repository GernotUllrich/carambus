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

    # --- Karambol (Dreiband): 9-Zellen-Zeilen mit GD-Spalte, 7-Zellen-Summenzeile ---
    KARAMBOL_HTML = <<~HTML
      <table class="result-set">
        <tr><th></th><th>BC München</th><th>BC München II</th><th></th><th></th><th>GD</th><th>Ergebnis</th><th>Partien</th></tr>
        <tr><td>1. Dreiband</td><td>Hermann, Robertino</td><td>Kieferle, Oliver</td><td>40:12 Bälle (x1,00)</td><td>35:35 Aufn. (x1,00)</td><td>6:3 HS</td><td>1,142:0,342</td><td>2:0</td><td>2:0</td></tr>
        <tr><td>2. Dreiband</td><td>Suhr, Gerd</td><td>Suckau, Andreas</td><td>28:23 Bälle (x1,00)</td><td>50:50 Aufn. (x1,00)</td><td>6:3 HS</td><td>0,560:0,460</td><td>2:0</td><td>2:0</td></tr>
        <tr><td></td><td>121:85</td><td>185:185</td><td></td><td>0,654:0,459</td><td>6:2</td><td>6:2</td></tr>
      </table>
    HTML

    test "Karambol: parses 9-cell Dreiband rows incl. GD statistic" do
      result = MeetingReportParser.new(KARAMBOL_HTML).parse
      assert_equal "BC München", result[:home_team]
      assert_equal "BC München II", result[:guest_team]
      assert_equal 2, result[:games].size, "Summenzeile (7 Zellen, td[0] leer) darf kein Einzelspiel sein"

      g = result[:games].first
      assert_equal "1. Dreiband", g[:discipline]
      assert_equal ["Hermann, Robertino"], g[:home_players]
      assert_equal "2:0", g[:set_result]
      assert_equal({home: 40, guest: 12}, g[:stats][:balls])
      assert_equal({home: 35, guest: 35}, g[:stats][:innings])
      assert_equal({home: 6, guest: 3}, g[:stats][:hs])
      assert_in_delta 1.142, g[:stats][:gd][:home], 0.0001
      assert_in_delta 0.342, g[:stats][:gd][:guest], 0.0001
    end

    test "Karambol: final result from 7-cell summary row" do
      result = MeetingReportParser.new(KARAMBOL_HTML).parse
      assert_equal({home: 6, guest: 2}, result[:final_result])
    end
  end
end
