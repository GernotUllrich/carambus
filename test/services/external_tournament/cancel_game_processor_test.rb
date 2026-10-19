# frozen_string_literal: true

require "test_helper"

# Phase 28-01: CancelGameProcessor — ein versehentlich angesetztes Spiel zuruecknehmen.
#
# Der Regressionstest, auf den es ankommt, ist "Tisch bleibt am Turnier gebunden":
# reset_table_monitor setzt tournament_monitor auf nil, und ohne das Neubinden liefe der
# naechste start_game in TableNotBoundError — also in genau das Symptom, das die Ruecknahme
# beseitigen soll.
module ExternalTournament
  class CancelGameProcessorTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @location = locations(:one)
      @tournament = LocalTournamentCreator.new(region: @nbv, payload: {
        external_id: "app-cancel-1", title: "Cancel Cup", location: {id: @location.id}
      }).call.tournament
      @owner = @tournament.tournament_monitor
      @player_a = Player.create!(id: 50_100_501, firstname: "CancelA", lastname: "Test", dbu_nr: 43001, ba_id: 43001)
      @player_b = Player.create!(id: 50_100_502, firstname: "CancelB", lastname: "Test", dbu_nr: 43002, ba_id: 43002)
      @seqno = 0
    end

    teardown do
      @bound_table&.update_columns(table_monitor_id: nil)
      GameParticipation.where(player: [@player_a, @player_b].compact).destroy_all
      TableMonitor.where("created_at > ?", 1.minute.ago).destroy_all
      Game.where("created_at > ?", 1.minute.ago).destroy_all
      Player.where(id: [@player_a&.id, @player_b&.id].compact).destroy_all
    end

    # Ein angesetztes App-Spiel: Game + Participations + gebundener TableMonitor am Tisch.
    # `data` bildet nach, was GameSetup beim Start hinterlaesst (leere innings_list).
    def build_started_game(external_id:, state: "warmup", data: nil)
      @seqno += 1
      game = Game.create!(tournament_id: @tournament.id, group_no: 1, seqno: @seqno, table_no: 1,
        data: {"external_id" => external_id, "warmup_minutes" => 3})
      GameParticipation.create!(game: game, player: @player_a, role: "playera")
      GameParticipation.create!(game: game, player: @player_b, role: "playerb")
      tm_data = data || {
        "playera" => {"result" => 0, "innings" => 0, "innings_list" => []},
        "playerb" => {"result" => 0, "innings" => 0, "innings_list" => []}
      }
      tm = TableMonitor.create!(state: "ready", game: game, tournament_monitor: @owner, data: tm_data)
      @bound_table = tables(:one)
      @bound_table.update_columns(table_monitor_id: tm.id)
      tm.update_columns(state: state)
      [game, tm.reload]
    end

    def payload(external_id:, force: nil)
      p = {tournament_id: @tournament.id, game: {external_id: external_id}}
      p[:force] = force unless force.nil?
      p
    end

    test "warmup ohne Aufnahme: Spiel weg, Tisch frei, Bindung bleibt" do
      game, tm = build_started_game(external_id: "g-cancel-1")
      game_id = game.id

      result = CancelGameProcessor.new(region: @nbv, payload: payload(external_id: "g-cancel-1")).call

      assert_nil Game.find_by(id: game_id), "Game geloescht"
      assert_empty GameParticipation.where(game_id: game_id), "Participations geloescht"
      assert_nil tm.reload.game_id, "Tisch traegt kein Spiel mehr"
      assert result.still_bound, "still_bound meldet die wiederhergestellte Bindung"
      assert_equal @owner.id, tm.tournament_monitor_id, "Tisch bleibt am Turnier gebunden"
    end

    test "still_bound kommt aus dem nachgeladenen Record, nicht aus einer Konstante" do
      _game, tm = build_started_game(external_id: "g-cancel-2")
      result = CancelGameProcessor.new(region: @nbv, payload: payload(external_id: "g-cancel-2")).call

      assert_equal tm.reload.tournament_monitor_id.present?, result.still_bound
      assert_equal @owner.id, result.table_monitor.tournament_monitor_id
    end

    test "erfasste Aufnahme: 409 scoring_recorded mit Stand im detail" do
      build_started_game(external_id: "g-cancel-3", data: {
        "playera" => {"result" => 7, "innings" => 4, "innings_list" => [3, 0, 4, 0]},
        "playerb" => {"result" => 3, "innings" => 4, "innings_list" => [0, 3, 0, 0]}
      })

      err = assert_raises(CancelGameProcessor::ScoringRecordedError) do
        CancelGameProcessor.new(region: @nbv, payload: payload(external_id: "g-cancel-3")).call
      end
      assert_match(/7/, err.detail, "Stand steht im detail")
      assert_match(/3/, err.detail)
    end

    # Der subtile Fall: eine Aufnahme ohne Treffer IST eine gespielte Aufnahme.
    # Eine Pruefung ueber die Ballsumme wuerde sie uebersehen.
    test "Nullaufnahme zaehlt als gespielt: 409" do
      build_started_game(external_id: "g-cancel-4", data: {
        "playera" => {"result" => 0, "innings" => 1, "innings_list" => [0]},
        "playerb" => {"result" => 0, "innings" => 0, "innings_list" => []}
      })

      assert_raises(CancelGameProcessor::ScoringRecordedError) do
        CancelGameProcessor.new(region: @nbv, payload: payload(external_id: "g-cancel-4")).call
      end
    end

    test "playing: 409 auch ohne Aufnahme (die gewaehlte, strengere Grenze)" do
      build_started_game(external_id: "g-cancel-5", state: "playing")

      err = assert_raises(CancelGameProcessor::ScoringRecordedError) do
        CancelGameProcessor.new(region: @nbv, payload: payload(external_id: "g-cancel-5")).call
      end
      assert_equal "playing", err.state
    end

    test "match_shootout ist ruecknehmbar: nur der Anstoss war ausgespielt" do
      game, _tm = build_started_game(external_id: "g-cancel-6", state: "match_shootout")
      game_id = game.id

      result = CancelGameProcessor.new(region: @nbv, payload: payload(external_id: "g-cancel-6")).call

      assert_nil Game.find_by(id: game_id)
      assert result.still_bound
    end

    test "force uebergeht die Vorbedingung" do
      game, _tm = build_started_game(external_id: "g-cancel-7", state: "playing", data: {
        "playera" => {"result" => 20, "innings" => 9, "innings_list" => [20]},
        "playerb" => {"result" => 5, "innings" => 9, "innings_list" => [5]}
      })
      game_id = game.id

      result = CancelGameProcessor.new(region: @nbv, payload: payload(external_id: "g-cancel-7", force: true)).call

      assert_nil Game.find_by(id: game_id), "mit force auch aus playing heraus"
      assert result.still_bound
    end

    test "unbekannte external_id: GameNotFoundError" do
      build_started_game(external_id: "g-cancel-8")

      assert_raises(CancelGameProcessor::GameNotFoundError) do
        CancelGameProcessor.new(region: @nbv, payload: payload(external_id: "gibt-es-nicht")).call
      end
    end

    test "fehlende external_id: GameNotFoundError statt stiller Treffer" do
      build_started_game(external_id: "g-cancel-9")

      assert_raises(CancelGameProcessor::GameNotFoundError) do
        CancelGameProcessor.new(region: @nbv, payload: {tournament_id: @tournament.id, game: {}}).call
      end
    end
  end
end
