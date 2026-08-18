# frozen_string_literal: true

require "test_helper"

# Plan 16-01 (D-16-GC-A): AppTournamentCleaner — Teardown/GC fuer lokale App-Turniere.
module ExternalTournament
  class AppTournamentCleanerTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @location = locations(:one)
      @player_a = Player.create!(id: 50_100_701, firstname: "ClnA", lastname: "Test", dbu_nr: 45001, ba_id: 45001)
      @player_b = Player.create!(id: 50_100_702, firstname: "ClnB", lastname: "Test", dbu_nr: 45002, ba_id: 45002)
    end

    teardown do
      GameParticipation.where(player: [@player_a, @player_b].compact).destroy_all
      Game.where("created_at > ?", 5.minutes.ago).destroy_all
      Tournament.where(region_id: @nbv.id, external_id: %w[cln-ac1 cln-managed cln-sweep-closed cln-sweep-active]).each do |t|
        t.tournament_monitor&.destroy
        t.destroy
      end
      Player.where(id: [@player_a&.id, @player_b&.id].compact).destroy_all
    end

    BA = {"Spieler1" => 45001, "Spieler2" => 45002, "Sets1" => 1, "Sets2" => 0,
          "Ergebnis1" => 100, "Ergebnis2" => 60, "Tischnummer" => 1}.freeze

    def app_tournament(external_id:)
      LocalTournamentCreator.new(region: @nbv, payload: {
        external_id: external_id, title: external_id, location: {id: @location.id}
      }).call.tournament
    end

    # Ein App-Spiel mit durablem Marker (tournament_external_id) + 2 GameParticipations.
    def marker_game(tournament, external_id:, ba_results: BA)
      g = Game.create!(group_no: 1, seqno: rand(700000..799999), table_no: 1,
        data: {"external_id" => external_id,
               "tournament_external_id" => tournament.external_id,
               "ba_results" => ba_results})
      GameParticipation.create!(game: g, player: @player_a, role: "playera")
      GameParticipation.create!(game: g, player: @player_b, role: "playerb")
      g
    end

    test "cleanup loescht Marker-Games(+GP)+Tournament, fremde Games bleiben, idempotent (AC-1)" do
      t = app_tournament(external_id: "cln-ac1")
      g1 = marker_game(t, external_id: "cln-ac1-g1")
      g2 = marker_game(t, external_id: "cln-ac1-g2", ba_results: nil) # unbeendetes Spiel (kein ba_results)
      tm_id = t.tournament_monitor.id
      # Fremdes Spiel mit anderem Marker — darf NICHT geloescht werden.
      foreign = Game.create!(group_no: 1, seqno: rand(700000..799999), table_no: 1,
        data: {"tournament_external_id" => "some-other-tournament"})

      r = AppTournamentCleaner.cleanup(t)
      assert_equal 2, r[:games_deleted], "beide Marker-Games (auch das unbeendete) geloescht"
      assert_equal true, r[:tournament_deleted]
      refute Game.exists?(g1.id), "Marker-Game 1 geloescht"
      refute Game.exists?(g2.id), "Marker-Game 2 geloescht"
      assert_equal 0, GameParticipation.where(game_id: [g1.id, g2.id]).count, "GameParticipations kaskadiert"
      refute Tournament.exists?(t.id), "Tournament geloescht"
      refute TournamentMonitor.exists?(tm_id), "TournamentMonitor kaskadiert"
      assert Game.exists?(foreign.id), "fremdes Game (anderer Marker) bleibt unberuehrt"

      # Idempotenz: 2. Aufruf auf dem (zerstoerten) Turnier ist no-op.
      r2 = AppTournamentCleaner.cleanup(t)
      assert_equal 0, r2[:games_deleted]
      assert_equal false, r2[:tournament_deleted]
    end

    test "cleanup ruehrt managed/nicht-App-Turnier nicht an (AC-2)" do
      managed = app_tournament(external_id: "cln-managed")
      managed.update_columns(manual_assignment: false) # simuliert managed (nicht-App) Turnier
      g = marker_game(managed, external_id: "cln-managed-g")

      r = AppTournamentCleaner.cleanup(managed)
      assert_equal 0, r[:games_deleted]
      assert_equal false, r[:tournament_deleted]
      assert Tournament.exists?(managed.id), "managed Turnier bleibt"
      assert Game.exists?(g.id), "Game des managed Turniers bleibt"
    end

    test "sweep_closed_local loescht nur abgeschlossene lokale App-Turniere (AC-4)" do
      closed = app_tournament(external_id: "cln-sweep-closed")
      closed_g = marker_game(closed, external_id: "cln-sweep-closed-g")
      closed.tournament_monitor.update_columns(state: "closed")

      active = app_tournament(external_id: "cln-sweep-active")
      active_g = marker_game(active, external_id: "cln-sweep-active-g")
      assert_not_equal "closed", active.tournament_monitor.state, "precondition: aktiver Monitor nicht closed"

      res = AppTournamentCleaner.sweep_closed_local
      assert res[:tournaments_deleted] >= 1, "mind. ein abgeschlossenes lokales App-Turnier geloescht"
      refute Tournament.exists?(closed.id), "abgeschlossenes lokales App-Turnier geloescht"
      refute Game.exists?(closed_g.id), "Marker-Game des abgeschlossenen Turniers geloescht"
      assert Tournament.exists?(active.id), "aktives lokales App-Turnier bleibt"
      assert Game.exists?(active_g.id), "Marker-Game des aktiven Turniers bleibt"
    end

    # HANDOFF multiday-app-tournaments (2026-08-19): Der Mitternachts-GC loeschte ein laufendes
    # mehrtaegiges Attach-Turnier am 2. Turniertag (samt aller erfassten Ergebnisse).
    # end_date in der Zukunft -> schonen; abgelaufen/nil -> weiterhin abraeumen.
    test "sweep_closed_local schont laufende mehrtaegige Turniere (end_date in der Zukunft)" do
      running = app_tournament(external_id: "cln-sweep-multiday")
      running.update_columns(end_date: 2.days.from_now)
      running.tournament_monitor.update_columns(state: "closed")

      expired = app_tournament(external_id: "cln-sweep-expired")
      expired.update_columns(end_date: 1.day.ago)
      expired.tournament_monitor.update_columns(state: "closed")

      AppTournamentCleaner.sweep_closed_local

      assert Tournament.exists?(running.id), "laufendes mehrtaegiges Turnier bleibt erhalten"
      refute Tournament.exists?(expired.id), "abgelaufenes Turnier wird weiterhin abgeraeumt"
    end

    # HANDOFF reset-app-tournament-task (2026-08-19): Attach-Turniere werden im Web/per Console
    # angelegt -> external_id nil -> der tournament_external_id-Marker findet nichts und die
    # App-Games blieben beim cleanup als Waisen liegen. Zweiter Pfad: "attach-<id>-…".
    test "marker_games findet Attach-Games ueber das attach-Praefix (external_id nil)" do
      t = app_tournament(external_id: "cln-attach")
      t.update_columns(external_id: nil) # Attach-Turnier: kein LocalTournamentCreator-Marker
      t.reload

      attach_g = Game.create!(group_no: 1, seqno: rand(700000..799999), table_no: 1,
        data: {"external_id" => "attach-#{t.id}-r1t1"})
      fremd = Game.create!(group_no: 1, seqno: rand(700000..799999), table_no: 1,
        data: {"external_id" => "attach-999999-r1t1"})

      found = AppTournamentCleaner.app_games(t).map(&:id)
      assert_includes found, attach_g.id, "Attach-Game ueber das Praefix gefunden"
      refute_includes found, fremd.id, "Attach-Game eines anderen Turniers bleibt unberuehrt"

      AppTournamentCleaner.cleanup(t)
      refute Game.exists?(attach_g.id), "Attach-Game wird mit abgeraeumt (keine Waise mehr)"
      assert Game.exists?(fremd.id), "fremdes Attach-Game bleibt"
    end
  end
end
