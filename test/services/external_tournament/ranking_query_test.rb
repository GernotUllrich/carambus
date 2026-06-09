# frozen_string_literal: true

require "test_helper"

# Plan 19-01 (v0.6 F1): Tests fuer ExternalTournament::RankingQuery (Disziplin-Ranking-Setzliste).
# Default-Saison = VORSAISON (D-19-01-SEASON); Nicht-Saison-Tests pinnen die Saison via season_name.
module ExternalTournament
  class RankingQueryTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @discipline = Discipline.create!(name: "RankTest-Dreiband", synonyms: "RT-3B\nRankTest-Syn")
      @season = Season.create!(name: "RANKQ-2099/2100")
      @season_name = @season.name
      @p1 = mk_player("RQ1", 196_001, 96_001)
      @p2 = mk_player("RQ2", 196_002, 96_002)
      @p3 = mk_player("RQ3", 196_003, 96_003)
    end

    teardown do
      PlayerRanking.where(discipline_id: @discipline&.id).delete_all
      Player.where(id: [@p1, @p2, @p3].compact.map(&:id)).delete_all
      Season.where(name: ["RANKQ-2099/2100", "RANKQ-VOR-2098/2099", "RANKQ-CUR-2099/2100"]).delete_all
      @discipline&.destroy
    end

    def mk_player(suffix, cc_id, dbu_nr)
      Player.create!(firstname: "RQ-#{suffix}", lastname: "Test#{suffix}",
        region_id: @nbv.id, cc_id: cc_id, dbu_nr: dbu_nr)
    end

    def rank!(player, season, rank:, gd:, hs: 5, balls: 100, innings: 30)
      PlayerRanking.create!(region_id: @nbv.id, season_id: season.id, discipline_id: @discipline.id,
        player_id: player.id, rank: rank, gd: gd, hs: hs, balls: balls, innings: innings)
    end

    test "sortiert nach rank aufsteigend, bei Gleichstand gd absteigend (AC-1)" do
      rank!(@p1, @season, rank: 2, gd: 1.0)
      rank!(@p2, @season, rank: 1, gd: 5.0)
      rank!(@p3, @season, rank: 2, gd: 9.0) # gleicher rank wie p1, hoeheres gd -> vor p1
      r = RankingQuery.players(region: @nbv, discipline_name: "RankTest-Dreiband", season_name: @season_name)
      assert_equal [196_002, 196_003, 196_001], r.ranked.map { |h| h[:cc_id] }
      assert_equal @season.id, r.season.id
      assert_equal 1, r.ranked.first[:rank]
      assert_equal "96002", r.ranked.first[:dbu_nr]
    end

    test "Disziplin via Synonym aufloesbar (AC-1)" do
      rank!(@p1, @season, rank: 1, gd: 1.0)
      r = RankingQuery.players(region: @nbv, discipline_name: "RankTest-Syn", season_name: @season_name)
      assert_not_nil r
      assert_equal "RankTest-Dreiband", r.discipline.name
      assert_equal 1, r.ranked.size
    end

    test "Default-Saison = VORSAISON, laufende Saison wird ignoriert (D-19-01-SEASON)" do
      cur = Season.find_or_create_by!(name: "RANKQ-CUR-2099/2100")
      prev = Season.find_or_create_by!(name: "RANKQ-VOR-2098/2099")
      rank!(@p1, prev, rank: 1, gd: 1.0)   # Vorsaison-Ranking -> soll geliefert werden
      rank!(@p2, cur, rank: 1, gd: 9.0)    # laufende Saison -> soll IGNORIERT werden
      # current_season -> cur (Name "…2099/2100"); previous_season leitet "…2098/2099" ab.
      Season.stub(:current_season, cur) do
        # previous_season parst das Startjahr aus dem Namen; hier explizit über prev gepinnt,
        # daher Stub auch auf previous_season für deterministisches Ergebnis:
        RankingQuery.stub(:previous_season, prev) do
          r = RankingQuery.players(region: @nbv, discipline_name: "RankTest-Dreiband")
          assert_equal prev.id, r.season.id, "Default ist die Vorsaison"
          assert_equal [196_001], r.ranked.map { |h| h[:cc_id] }, "nur Vorsaison-Ranking, laufende ignoriert"
        end
      end
    end

    test "player_cc_ids filtert + unranked fuer angeforderte ohne Ranking (AC-2)" do
      rank!(@p1, @season, rank: 1, gd: 1.0)
      rank!(@p2, @season, rank: 2, gd: 1.0)
      # p3 (196_003) hat kein Ranking
      r = RankingQuery.players(region: @nbv, discipline_name: "RankTest-Dreiband",
        player_cc_ids: [196_001, 196_003], season_name: @season_name)
      assert_equal [196_001], r.ranked.map { |h| h[:cc_id] }
      assert_equal ["196003"], r.unranked
    end

    test "dedupe je cc_id auf bestes (kleinstes) rank (AC-2)" do
      rank!(@p1, @season, rank: 5, gd: 1.0)
      rank!(@p1, @season, rank: 2, gd: 1.0) # selber Spieler, besseres rank
      r = RankingQuery.players(region: @nbv, discipline_name: "RankTest-Dreiband", season_name: @season_name)
      assert_equal 1, r.ranked.size
      assert_equal 2, r.ranked.first[:rank]
    end

    test "unbekannte Disziplin -> nil (AC-2: Controller mappt auf 404)" do
      assert_nil RankingQuery.players(region: @nbv, discipline_name: "Gibt-Es-Nicht-XYZ-12345")
    end

    # Plan 21-07 (D-21-07-A): serialize liefert age_class + gender aus den persistierten
    # Player-Spalten (21-04). KEIN Server-Filter (D-21-07-D — Ranking ist disziplin-zentriert).
    test "serialize includes age_class + gender from persisted player columns (D-21-07-A)" do
      @p1.update!(age_class: "Senioren 45-99", gender: "M")
      rank!(@p1, @season, rank: 1, gd: 9.0)
      r = RankingQuery.players(region: @nbv, discipline_name: "RankTest-Dreiband",
        season_name: @season_name)
      item = r.ranked.first
      assert_equal "Senioren 45-99", item[:age_class]
      assert_equal "M", item[:gender]
    end
  end
end
