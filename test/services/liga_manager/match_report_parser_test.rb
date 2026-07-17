# frozen_string_literal: true

require "test_helper"

module LigaManager
  class MatchReportParserTest < ActiveSupport::TestCase
    FIXTURE = Rails.root.join("test/snapshots/vcr/ligamanager/results_by-matchplan_30.html")

    def parsed
      MatchReportParser.new(File.read(FIXTURE)).parse
    end

    test "extracts the final score" do
      assert_equal({home: 2, guest: 10}, parsed[:final_score])
    end

    test "extracts the individual games with players and set result" do
      games = parsed[:games]
      assert_operator games.size, :>, 0

      first = games.first
      assert_equal 1, first[:position]
      assert_equal "Freie Partie", first[:discipline]
      assert_equal "Wobisch, Nils Roy", first[:home_player]
      assert_equal "Wetzel, Holger", first[:away_player]
      assert_equal "0:2", first[:set_result]
    end

    test "is robust against empty or non-matching html" do
      assert_equal({final_score: nil, games: []}, MatchReportParser.new("<div>nix</div>").parse)
      assert_equal({final_score: nil, games: []}, MatchReportParser.new(nil).parse)
    end

    test "extracts per-game statistics (Bälle/Aufnahmen/HS/GD)" do
      assert_equal(
        {factor: 1, balls: {home: 41, guest: 200}, innings: {home: 18, guest: 18},
         hs: {home: 8, guest: 43}, gd: {home: 2.28, guest: 11.11}},
        parsed[:games].first[:stats]
      )
    end

    test "statistics rows do not add extra games" do
      assert_equal 6, parsed[:games].size
    end

    test "game without following statistics row yields nil stats" do
      html = <<~HTML
        <table>
          <tr><td>1</td><td>Freie Partie</td><td>A, X</td><td>0:2</td><td>B, Y</td><td>0:2</td></tr>
        </table>
      HTML
      result = MatchReportParser.new(html).parse
      assert_equal 1, result[:games].size
      assert_nil result[:games].first[:stats]
    end
  end
end
