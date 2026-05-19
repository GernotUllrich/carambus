# frozen_string_literal: true

require "test_helper"

# Plan 15-04 Task 3b: Tests für ExternalTournament::RoundResultAggregator.
#
# Coverage:
#   - Spec-konforme Top-Level-Felder (schema/region/tournament/round_no)
#   - Leere Runde → results: []
#   - Aggregation: GameParticipations → participants[]
#   - innings_played = max(participant.innings)
#   - gd-Fallback (DB-Wert oder berechnet)
#   - Laufende Games (ended_at nil) inkludiert
#   - Sortierung nach seqno
module ExternalTournament
  class RoundResultAggregatorTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @discipline = disciplines(:carom_3band)
      @season = seasons(:current)

      @tournament = Tournament.create!(
        title: "Test RoundResultAggregator 15-04",
        region_id: @nbv.id,
        discipline: @discipline,
        season: @season,
        organizer: clubs(:bcw),
        balls_goal: 30,
        innings_goal: 25,
        date: Time.zone.parse("2026-05-17 11:00:00 +0200")
      )
      @tournament_cc = TournamentCc.create!(
        cc_id: 888_401,
        context: @nbv.shortname.downcase,
        name: @tournament.title,
        tournament: @tournament
      )

      @player_a = players(:jaspers)
      @player_b = players(:cho)
    end

    teardown do
      if @tournament&.persisted?
        Game.where(tournament: @tournament).each do |g|
          GameParticipation.where(game_id: g.id).delete_all
          g.delete
        end
      end
      TournamentCc.where(cc_id: 888_401).delete_all
      Tournament.where(title: "Test RoundResultAggregator 15-04").delete_all
    end

    test "returns spec-compliant top-level fields with empty results when no games" do
      payload = build_aggregator(round_no: 1).call

      assert_equal "carambus.round_result/v1", payload[:schema]
      assert_equal "NBV", payload[:region][:shortname]
      assert_equal 888_401, payload[:tournament][:cc_id]
      assert_equal 1, payload[:round_no]
      assert_equal [], payload[:results]
    end

    test "aggregates GameParticipations into participants array with mapped fields" do
      g = make_game(round_no: 1, seqno: 1, table_no: 5, external_id: "rr-agg-1", ended: true)
      GameParticipation.create!(game: g, player: @player_a, role: "playera",
                                points: 30, innings: 22, hs: 5, gd: 1.364)
      GameParticipation.create!(game: g, player: @player_b, role: "playerb",
                                points: 24, innings: 22, hs: 4)

      payload = build_aggregator(round_no: 1).call
      assert_equal 1, payload[:results].size

      result = payload[:results].first
      assert_equal "rr-agg-1", result[:external_id]
      assert_equal 5, result[:table_no]
      assert_equal 22, result[:innings_played]
      assert_equal 2, result[:participants].size

      pa = result[:participants].find { |p| p[:role] == "playera" }
      assert_equal 30, pa[:points]
      assert_equal 22, pa[:innings]
      assert_equal 5, pa[:high_series]
      assert_equal 1.364, pa[:gd]
      assert_equal @player_a.firstname, pa[:player][:firstname]
      assert_equal @player_a.lastname, pa[:player][:lastname]
    end

    test "innings_played is max of participant innings (Nachstoß-tolerant)" do
      g = make_game(round_no: 1, seqno: 1, table_no: 5, external_id: "rr-imax", ended: true)
      GameParticipation.create!(game: g, player: @player_a, role: "playera",
                                points: 30, innings: 22, hs: 5)
      GameParticipation.create!(game: g, player: @player_b, role: "playerb",
                                points: 18, innings: 21, hs: 3)

      payload = build_aggregator(round_no: 1).call
      assert_equal 22, payload[:results].first[:innings_played]
    end

    test "gd uses DB value when present, else computes from points/innings" do
      g = make_game(round_no: 1, seqno: 1, table_no: 5, external_id: "rr-gd", ended: true)
      GameParticipation.create!(game: g, player: @player_a, role: "playera",
                                points: 30, innings: 22, hs: 5, gd: 1.364)
      # Player B: gd nicht gesetzt → muss aus 24/22 = 1.0909... berechnet werden
      GameParticipation.create!(game: g, player: @player_b, role: "playerb",
                                points: 24, innings: 22, hs: 4)

      payload = build_aggregator(round_no: 1).call
      pa = payload[:results].first[:participants].find { |p| p[:role] == "playera" }
      pb = payload[:results].first[:participants].find { |p| p[:role] == "playerb" }
      assert_equal 1.364, pa[:gd]
      assert_equal 1.091, pb[:gd]
    end

    test "includes games with ended_at nil (ongoing)" do
      g = make_game(round_no: 1, seqno: 1, table_no: 5, external_id: "rr-ongoing", ended: false)
      GameParticipation.create!(game: g, player: @player_a, role: "playera",
                                points: 12, innings: 10, hs: 3)

      payload = build_aggregator(round_no: 1).call
      result = payload[:results].first
      assert_equal "rr-ongoing", result[:external_id]
      assert_nil result[:ended_at]
      assert_not_nil result[:started_at]
      assert_equal 10, result[:innings_played]
    end

    test "results are ordered by seqno" do
      g3 = make_game(round_no: 1, seqno: 3, table_no: 7, external_id: "rr-seq-3", ended: true)
      g1 = make_game(round_no: 1, seqno: 1, table_no: 5, external_id: "rr-seq-1", ended: true)
      g2 = make_game(round_no: 1, seqno: 2, table_no: 6, external_id: "rr-seq-2", ended: true)
      [g1, g2, g3].each do |game|
        GameParticipation.create!(game: game, player: @player_a, role: "playera",
                                  points: 10, innings: 8, hs: 2)
      end

      payload = build_aggregator(round_no: 1).call
      external_ids = payload[:results].map { |r| r[:external_id] }
      assert_equal %w[rr-seq-1 rr-seq-2 rr-seq-3], external_ids
    end

    test "gd is nil when innings is zero (no division by zero)" do
      g = make_game(round_no: 1, seqno: 1, table_no: 5, external_id: "rr-zero", ended: true)
      GameParticipation.create!(game: g, player: @player_a, role: "playera",
                                points: 0, innings: 0, hs: 0)

      payload = build_aggregator(round_no: 1).call
      pa = payload[:results].first[:participants].first
      assert_nil pa[:gd]
    end

    private

    def build_aggregator(round_no:)
      RoundResultAggregator.new(
        tournament: @tournament,
        tournament_cc: @tournament_cc,
        region: @nbv,
        round_no: round_no
      )
    end

    # Tournament hat `has_many :games, as: :tournament` (polymorphic-from-Tournament-side);
    # daher MUSS via @tournament.games.create! erstellt werden, damit tournament_type gesetzt
    # wird. Game.create!(tournament: ...) lässt tournament_type nil → Game wird nicht gefunden.
    def make_game(round_no:, seqno:, table_no:, external_id:, ended:)
      @tournament.games.create!(
        round_no: round_no,
        gname: "RR-#{external_id}",
        seqno: seqno,
        table_no: table_no,
        started_at: Time.zone.parse("2026-05-17 11:05:00 +0200"),
        ended_at: ended ? Time.zone.parse("2026-05-17 11:42:00 +0200") : nil,
        data: {external_id: external_id}
      )
    end
  end
end
