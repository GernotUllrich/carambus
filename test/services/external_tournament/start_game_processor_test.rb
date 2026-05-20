# frozen_string_literal: true

require "test_helper"

# Plan 17-03 (B1): StartGameProcessor — App startet Spiel mit per-Spieler-Disziplinen → Warmup.
module ExternalTournament
  class StartGameProcessorTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @location = locations(:one)
      @tournament = LocalTournamentCreator.new(region: @nbv, payload: {
        external_id: "app-sg-1", title: "SG Cup", location: {id: @location.id}
      }).call.tournament

      @monitor = TableMonitor.create!(state: "ready", data: {})
      @table = tables(:one)
      @table.update_columns(table_monitor_id: @monitor.id)
      # Tisch an Turnier binden (17-02)
      TableLocker.new(region: @nbv, payload: {tournament_id: @tournament.id, table: {id: @table.id}}).call
      @monitor.reload
    end

    # Transaktionale Tests rollen Änderungen zurück; expliziter Teardown nur defensiv.
    teardown do
      @table&.update_columns(table_monitor_id: nil)
    end

    def start_payload(external_id:, disc_a: "3-Band", disc_b: "3-Band", ba: 30, bb: 30)
      {
        tournament_id: @tournament.id,
        table: {id: @table.id},
        external_id: external_id,
        free_game_form: "karambol",
        innings_goal: 25, sets_to_play: 1, sets_to_win: 1,
        participants: [
          {role: "playera", player: {firstname: "Dick", lastname: "JASPERS"}, discipline: disc_a, balls_goal: ba},
          {role: "playerb", player: {firstname: "Myung Woo", lastname: "CHO"}, discipline: disc_b, balls_goal: bb}
        ]
      }
    end

    test "startet Spiel mit per-Spieler-Disziplinen und bringt Tisch in Warmup" do
      result = StartGameProcessor.new(region: @nbv,
        payload: start_payload(external_id: "game-sg-1", disc_a: "3-Band", disc_b: "Freie Partie", ba: 30, bb: 100)).call

      tm = result.table_monitor
      assert result.created?
      assert tm.game.present?, "Game erzeugt"
      assert_includes %w[warmup warmup_a warmup_b match_shootout playing], tm.state.to_s, "tm spielbereit (warmup)"
      assert_equal "3-Band", tm.data.dig("playera", "discipline")
      assert_equal "Freie Partie", tm.data.dig("playerb", "discipline"), "per-Spieler-Disziplin"
      assert_equal 30, tm.data.dig("playera", "balls_goal")
      assert_equal 100, tm.data.dig("playerb", "balls_goal")
      assert_equal 2, tm.game.game_participations.count
      assert_equal "game-sg-1", tm.game.data["external_id"]
      # Plan 17-06 (D-17-06-A): durabler Turnier-Marker fuer die CSV-Enumerierung gestempelt.
      assert_equal @tournament.external_id, tm.game.data["tournament_external_id"]
    end

    test "ungebundener Tisch wird abgelehnt" do
      other_mon = TableMonitor.create!(state: "ready", data: {})
      other_table = tables(:two)
      other_table.update_columns(table_monitor_id: other_mon.id)
      assert_raises(StartGameProcessor::TableNotBoundError) do
        payload = start_payload(external_id: "game-sg-x").merge(table: {id: other_table.id})
        StartGameProcessor.new(region: @nbv, payload: payload).call
      end
    ensure
      other_table&.update_columns(table_monitor_id: nil)
      other_mon&.destroy
    end

    test "Game-Swap haengt altes Spiel ab, neues im Warmup" do
      StartGameProcessor.new(region: @nbv, payload: start_payload(external_id: "game-sg-A")).call
      first_game = @monitor.reload.game
      assert first_game.present?

      StartGameProcessor.new(region: @nbv, payload: start_payload(external_id: "game-sg-B")).call
      @monitor.reload

      assert_not_equal first_game.id, @monitor.game.id, "neues Game"
      assert_nil first_game.reload.table_monitor, "altes Game abgehaengt (has_one table_monitor nil)"
      assert first_game.data["swap_snapshot"].present?, "alter Stand gesichert"
      assert_includes %w[warmup warmup_a warmup_b match_shootout playing], @monitor.state.to_s
    end

    test "idempotent bei gleichem external_id" do
      r1 = StartGameProcessor.new(region: @nbv, payload: start_payload(external_id: "game-sg-id")).call
      r2 = StartGameProcessor.new(region: @nbv, payload: start_payload(external_id: "game-sg-id")).call
      assert r1.created?
      assert_not r2.created?, "2. Aufruf idempotent"
      assert_equal r1.game.id, r2.game.id
    end
  end
end
