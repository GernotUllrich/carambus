# frozen_string_literal: true

require "test_helper"

# Plan 17-04 (Vision J): AcknowledgeResultProcessor — App pulls the held result + releases the table.
module ExternalTournament
  class AcknowledgeResultProcessorTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @location = locations(:one)
      @tournament = LocalTournamentCreator.new(region: @nbv, payload: {
        external_id: "app-ack-1", title: "Ack Cup", location: {id: @location.id}
      }).call.tournament
      @owner = @tournament.tournament_monitor
      @player_a = Player.create!(id: 50_100_401, firstname: "AckA", lastname: "Test", dbu_nr: 42001, ba_id: 42001)
      @player_b = Player.create!(id: 50_100_402, firstname: "AckB", lastname: "Test", dbu_nr: 42002, ba_id: 42002)
      @seqno = 0
    end

    teardown do
      @bound_table&.update_columns(table_monitor_id: nil)
      GameParticipation.where(player: [@player_a, @player_b].compact).destroy_all
      TableMonitor.where("created_at > ?", 1.minute.ago).destroy_all
      Game.where("created_at > ?", 1.minute.ago).destroy_all
      Player.where(id: [@player_a&.id, @player_b&.id].compact).destroy_all
    end

    BA = {
      "Spieler1" => 42001, "Spieler2" => 42002,
      "Sets1" => 1, "Sets2" => 0, "Ergebnis1" => 100, "Ergebnis2" => 60,
      "Aufnahmen1" => 5, "Aufnahmen2" => 5, "Höchstserie1" => 50, "Höchstserie2" => 30,
      "Tischnummer" => 1
    }.freeze

    # Held App game at :final_match_score with ba_results in game.data + tm.data.
    def build_held_game(external_id:, state: "final_match_score", with_table: false)
      @seqno += 1
      game = Game.create!(tournament_id: @tournament.id, group_no: 1, seqno: @seqno, table_no: 1,
        data: {"external_id" => external_id, "ba_results" => BA, "tmp_results" => {"sets" => [BA]}})
      GameParticipation.create!(game: game, player: @player_a, role: "playera")
      GameParticipation.create!(game: game, player: @player_b, role: "playerb")
      tm = TableMonitor.create!(state: "playing", game: game, tournament_monitor: @owner,
        data: {"ba_results" => BA, "sets" => [BA]})
      if with_table
        @bound_table = tables(:one)
        @bound_table.update_columns(table_monitor_id: tm.id)
      end
      tm.update_columns(state: state)
      tm.reload
      [game, tm]
    end

    def payload(external_id:)
      {tournament_id: @tournament.id, game: {external_id: external_id}}
    end

    test "happy path: returns ba_results, sets acknowledged_at, releases table" do
      game, tm = build_held_game(external_id: "g-ack-1")
      result = AcknowledgeResultProcessor.new(region: @nbv, payload: payload(external_id: "g-ack-1")).call

      assert_not result.already_acknowledged
      assert_equal 100, result.result["Ergebnis1"]
      assert_equal 60, result.result["Ergebnis2"]
      assert_equal [BA], result.result["sets"]
      assert game.reload.result_acknowledged_at.present?, "acknowledged_at gesetzt"
      assert_equal "ready_for_new_match", tm.reload.state, "Tisch freigegeben (Hold verlassen)"
    end

    test "idempotent: second call returns same result, no second release" do
      build_held_game(external_id: "g-ack-2")
      r1 = AcknowledgeResultProcessor.new(region: @nbv, payload: payload(external_id: "g-ack-2")).call
      first_ack = r1.acknowledged_at
      r2 = AcknowledgeResultProcessor.new(region: @nbv, payload: payload(external_id: "g-ack-2")).call

      assert_not r1.already_acknowledged
      assert r2.already_acknowledged, "2. Aufruf idempotent"
      assert_equal first_ack.to_i, r2.acknowledged_at.to_i, "acknowledged_at unveraendert"
      assert_equal 100, r2.result["Ergebnis1"]
    end

    test "not ready: game not at hold raises NotReadyError" do
      build_held_game(external_id: "g-ack-3", state: "playing")
      assert_raises(AcknowledgeResultProcessor::NotReadyError) do
        AcknowledgeResultProcessor.new(region: @nbv, payload: payload(external_id: "g-ack-3")).call
      end
    end

    test "unknown external_id raises GameNotFoundError" do
      assert_raises(AcknowledgeResultProcessor::GameNotFoundError) do
        AcknowledgeResultProcessor.new(region: @nbv, payload: payload(external_id: "does-not-exist")).call
      end
    end

    test "region scope: tournament from another region not found" do
      bbv = regions(:bbv)
      build_held_game(external_id: "g-ack-1")
      assert_raises(AcknowledgeResultProcessor::TournamentNotFoundError) do
        AcknowledgeResultProcessor.new(region: bbv, payload: payload(external_id: "g-ack-1")).call
      end
    end
  end
end
