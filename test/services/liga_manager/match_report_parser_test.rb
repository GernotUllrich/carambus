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
  end
end
