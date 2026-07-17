# frozen_string_literal: true

require "test_helper"

module LigaManager
  class ScraperTest < ActiveSupport::TestCase
    def build_scraper
      Scraper.new(association_id: 1)
    end

    test "association returns a hash" do
      VCR.use_cassette("ligamanager/association") do
        assert_kind_of Hash, build_scraper.association
      end
    end

    test "seasons returns the association's seasons" do
      VCR.use_cassette("ligamanager/seasons") do
        assert_operator build_scraper.seasons.size, :>, 0
      end
    end

    test "game_types parse the disciplines JSON-string into a Hash" do
      VCR.use_cassette("ligamanager/game_types") do
        gt = build_scraper.game_types
        assert_kind_of Hash, gt.first["disciplines"]
      end
    end

    test "leagues lists a season's leagues" do
      VCR.use_cassette("ligamanager/leagues_season_1") do
        assert_operator build_scraper.leagues(1).size, :>, 0
      end
    end

    test "league detail parses discip_leg1 into a Hash" do
      VCR.use_cassette("ligamanager/league_5") do
        assert_kind_of Hash, build_scraper.league(5)["discip_leg1"]
      end
    end

    test "clubs are collected across pagination" do
      VCR.use_cassette("ligamanager/clubs") do
        assert_equal 19, build_scraper.clubs.size
      end
    end

    test "teams lists a league's teams" do
      VCR.use_cassette("ligamanager/teams_league_5") do
        assert_operator build_scraper.teams(5).size, :>, 0
      end
    end

    # --- Tiefen-/Result-Endpunkte (Plan 07-02) ---

    test "match_plans lists a league's encounters" do
      VCR.use_cassette("ligamanager/match_plan_league_5") do
        assert_operator build_scraper.match_plans(5).size, :>, 0
      end
    end

    test "standings returns the league table as an array" do
      VCR.use_cassette("ligamanager/standings_league_5") do
        assert_kind_of Array, build_scraper.standings(5)
      end
    end

    test "ranking returns a hash keyed by discipline" do
      VCR.use_cassette("ligamanager/ranking_league_5") do
        assert_kind_of Hash, build_scraper.ranking(5)
      end
    end

    test "members lists a club's players" do
      VCR.use_cassette("ligamanager/members_club_16") do
        assert_operator build_scraper.members(16).size, :>, 0
      end
    end

    test "match_report parses the HTML report into structured games" do
      VCR.use_cassette("ligamanager/match_report_30") do
        report = build_scraper.match_report(30)
        assert_operator report[:games].size, :>, 0
        refute_nil report[:final_score]
      end
    end
  end
end
