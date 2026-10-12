# frozen_string_literal: true

require "test_helper"

# ClubCloud-Upload bei Einsatz-Partien.
#
# Seit 2b800a9f (2026-04-26, Phase 38.4 R5-2) entsteht `ba_results` nur noch in
# `ResultRecorder#perform_save_current_set` — um eine Doppelzaehlung von Sets1/Sets2 bei
# Mehrsatz-Partien zu beheben. Der Zweig fuer EINSATZ-Partien in `perform_evaluate_result`
# ("Branch C") ruft diese Methode aber nie auf; `admin_ack_result` und `force_next_state`
# ebenso wenig. Folge: Bei jeder einsaetzigen Partie — praktisch jedem Karambol-Turnier —
# blieb `ba_results` leer, und der Upload scheiterte mit
# "No game results (ba_results) found". Auf bc-wedel seit mindestens 2026-08-30 kein
# einziger erfolgreicher Upload (gefunden 2026-09-18 beim Test der NDM Freie Partie Kl. 7).
#
# Die Tests fahren den echten Weg: TournamentMonitor#report_result mit einem Tisch im
# Zustand final_set_score, wie ihn alle vier Aufrufer uebergeben.
class TournamentMonitor::CcUploadSingleSetTest < ActiveSupport::TestCase
  include KoTournamentTestHelper

  self.use_transactional_tests = true

  setup do
    @test_data = create_ko_tournament_with_seedings(4, {balls_goal: 40, innings_goal: 20})
    @tournament = @test_data[:tournament]
    @players = @test_data[:players]
    @tournament.update_columns(auto_upload_to_cc: true)
    TournamentCc.create!(tournament_id: @tournament.id, cc_id: 948, name: "Test-Turnier")

    @tournament.initialize_tournament_monitor
    @tm = @tournament.tournament_monitor
    @tm.data ||= {}
    @tm.data["rankings"] ||= {}
    @tm.save!

    @game = @tournament.games.create!(id: 66_000_001, gname: "group1:2-5", group_no: 1, seqno: 1, data: {})
    GameParticipation.create!(game: @game, player: @players[0], role: "playera")
    GameParticipation.create!(game: @game, player: @players[1], role: "playerb")
  end

  teardown do
    cleanup_ko_tournament(@test_data) if @test_data
  end

  # Tisch nach bestaetigtem Protokoll einer Einsatz-Partie (40:11 in 2 Aufnahmen) —
  # ohne ba_results, genau wie Branch C ihn an report_result uebergibt.
  def single_set_table_monitor!(extra_data = {})
    TableMonitor.create!(
      tournament_monitor: @tm,
      game: @game,
      state: "final_set_score",
      panel_state: "pointer_mode",
      data: {
        "playera" => {"result" => 40, "innings" => 2, "hs" => 30, "innings_list" => [10, 30], "balls_goal" => 40},
        "playerb" => {"result" => 11, "innings" => 2, "hs" => 10, "innings_list" => [1, 10], "balls_goal" => 40},
        "sets_to_win" => 1,
        "sets_to_play" => 1,
        "sets" => []
      }.merge(extra_data)
    )
  end

  # Faengt den Upload ab und merkt sich, was er zu sehen bekam.
  def report_with_upload_probe(table_monitor)
    seen = []
    probe = lambda do |tabmon|
      seen << (tabmon.data["ba_results"] || tabmon.game&.data&.[]("ba_results"))
      {success: true}
    end
    Setting.stub :upload_game_to_cc, probe do
      TournamentMonitorUpdateResultsJob.stub :perform_later, ->(*) {} do
        TournamentStatusUpdateJob.stub :perform_later, ->(*) {} do
          @tm.report_result(table_monitor)
        end
      end
    end
    seen
  end

  test "Einsatz-Partie: der Upload bekommt das Ergebnis" do
    table_monitor = single_set_table_monitor!
    seen = report_with_upload_probe(table_monitor)

    assert_equal 1, seen.size, "Der Upload wurde nicht (genau einmal) versucht"
    ba = seen.first
    assert ba.present?, "Der Upload sah keine ba_results — genau der Fehler aus dem Produktionslog"
    assert_equal 40, ba["Ergebnis1"]
    assert_equal 11, ba["Ergebnis2"]
    assert_equal 2, ba["Aufnahmen1"]
    assert_equal 30, ba["Höchstserie1"]
    assert_equal 1, ba["Sets1"], "Der Sieger der Einsatz-Partie hat den Satz"
    assert_equal 0, ba["Sets2"]
  end

  test "Einsatz-Partie: ba_results landen auch am Spiel" do
    report_with_upload_probe(single_set_table_monitor!)
    assert_equal 40, @game.reload.data.dig("ba_results", "Ergebnis1"),
      "game.data['ba_results'] fehlt — write_game_result_data hat uebersprungen"
  end

  test "Einsatz-Partie: keine Satzliste und keine andere Anzeige am Tisch" do
    # Betreiber-Vorgabe 2026-09-18: der Fix darf das Protokoll am Ende NICHT erneut oder
    # mehrfach zeigen. Er schreibt nur ba_results — data['sets'] (bisher bei Einsatz-
    # Partien leer) und panel_state bleiben, wie sie ohne den Fix waeren.
    table_monitor = single_set_table_monitor!
    report_with_upload_probe(table_monitor)
    table_monitor.reload
    assert_equal [], Array(table_monitor.data["sets"]), "data['sets'] wurde befuellt"
    assert_equal "pointer_mode", table_monitor.panel_state, "panel_state wurde veraendert"
  end

  test "Mehrsatz-Partie: vorhandene ba_results bleiben unveraendert (keine Doppelzaehlung)" do
    vorhanden = {"Ergebnis1" => 80, "Ergebnis2" => 60, "Sets1" => 2, "Sets2" => 1,
                 "Aufnahmen1" => 9, "Aufnahmen2" => 9, "Höchstserie1" => 20, "Höchstserie2" => 15}
    table_monitor = single_set_table_monitor!("ba_results" => vorhanden, "sets_to_win" => 2)
    seen = report_with_upload_probe(table_monitor)

    assert_equal 2, seen.first["Sets1"], "Sets1 wurde erneut hochgezaehlt"
    assert_equal 80, seen.first["Ergebnis1"], "Vorhandene ba_results wurden ueberschrieben"
  end
end
