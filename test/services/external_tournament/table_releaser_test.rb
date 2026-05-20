# frozen_string_literal: true

require "test_helper"

# Plan 17-05 (Vision L/M/N): TableReleaser — Lifecycle-Exit (Tisch-Freigabe).
module ExternalTournament
  class TableReleaserTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @location = locations(:one)
      @player_a = Player.create!(id: 50_100_601, firstname: "RelA", lastname: "Test", dbu_nr: 44001, ba_id: 44001)
      @player_b = Player.create!(id: 50_100_602, firstname: "RelB", lastname: "Test", dbu_nr: 44002, ba_id: 44002)
      @seqno = 0
    end

    teardown do
      GameParticipation.where(player: [@player_a, @player_b].compact).destroy_all
      TableMonitor.where("created_at > ?", 1.minute.ago).destroy_all
      Game.where("created_at > ?", 1.minute.ago).destroy_all
      Player.where(id: [@player_a&.id, @player_b&.id].compact).destroy_all
    end

    BA = {"Spieler1" => 44001, "Spieler2" => 44002, "Sets1" => 1, "Sets2" => 0,
          "Ergebnis1" => 100, "Ergebnis2" => 60, "Tischnummer" => 1}.freeze

    def app_tournament(external_id:)
      LocalTournamentCreator.new(region: @nbv, payload: {
        external_id: external_id, title: external_id, location: {id: @location.id}
      }).call.tournament
    end

    # An owner gebundener TableMonitor; optional ein App-Spiel im Hold (final_match_score, unbestätigt).
    def bind_tm(owner, hold: false, external_id: nil)
      tm = TableMonitor.create!(state: "ready", tournament_monitor: owner, data: {})
      if hold
        g = Game.create!(group_no: 1, seqno: rand(700000..799999), table_no: 1,
          data: {"external_id" => external_id, "ba_results" => BA})
        GameParticipation.create!(game: g, player: @player_a, role: "playera")
        GameParticipation.create!(game: g, player: @player_b, role: "playerb")
        tm.update!(game_id: g.id)
        tm.update_columns(state: "final_match_score")
      end
      tm.reload
    end

    test "reset_table_monitor force gibt unbestätigtes App-Spiel frei; ohne force geschützt (AC-1)" do
      t = app_tournament(external_id: "rel-ac1")
      tm = bind_tm(t.tournament_monitor, hold: true, external_id: "rel-ac1-g")
      assert tm.external_result_pending?, "precondition: Hold unbestätigt"

      tm.reset_table_monitor # ohne force → Operator-Schutz (17-04)
      tm.reload
      assert_equal t.tournament_monitor.id, tm.tournament_monitor_id, "ohne force weiterhin gebunden"

      tm.reset_table_monitor(force: true)
      tm.reload
      assert_nil tm.tournament_monitor_id, "force gibt frei"
      assert_nil tm.game_id
    end

    test "release_tournament gibt alle Tische frei + schließt TM, idempotent (AC-2)" do
      t = app_tournament(external_id: "rel-ac2")
      owner = t.tournament_monitor
      tm1 = bind_tm(owner, hold: true, external_id: "rel-ac2-g1")
      tm2 = bind_tm(owner, hold: false)

      r = TableReleaser.release_tournament(t)
      assert_equal 2, r.released
      assert_equal 1, r.unacknowledged, "ein Tisch hatte unbestätigtes Ergebnis"
      assert_equal "closed", r.tournament_monitor_state
      assert_nil tm1.reload.tournament_monitor_id
      assert_nil tm2.reload.tournament_monitor_id

      r2 = TableReleaser.release_tournament(t.reload)
      assert_equal 0, r2.released, "idempotent"
      assert_equal "closed", r2.tournament_monitor_state
    end

    test "release_stale_local gibt lokale App-Turniere frei, managed unberührt (AC-3/AC-4)" do
      app = app_tournament(external_id: "rel-stale-app")
      app_tm = bind_tm(app.tournament_monitor, hold: false)

      managed = app_tournament(external_id: "rel-stale-managed")
      managed.update_columns(manual_assignment: false) # simuliert managed (nicht-App) Turnier
      managed_tm = bind_tm(managed.tournament_monitor, hold: false)

      res = TableReleaser.release_stale_local
      assert res[:released] >= 1, "mind. ein lokaler App-Tisch freigegeben"
      assert_nil app_tm.reload.tournament_monitor_id, "lokales App-Turnier freigegeben"
      assert_equal managed.tournament_monitor.id, managed_tm.reload.tournament_monitor_id, "managed Turnier unberührt (AC-4)"
    end
  end
end
