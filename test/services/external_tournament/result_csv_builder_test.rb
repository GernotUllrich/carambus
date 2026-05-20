# frozen_string_literal: true

require "test_helper"
require "csv"

# Plan 17-06: Tests fuer ExternalTournament::ResultCsvBuilder.
#
# Validiert: CSV aus game.data["ba_results"] (manual_assignment ⇒ GP-Spalten leer),
# dbu_nr-Spalten je Spieler, durable + turnier-eindeutige Enumerierung via
# game.data["tournament_external_id"] (D-17-06-A/B).
module ExternalTournament
  class ResultCsvBuilderTest < ActiveSupport::TestCase
    BA = {
      "Ergebnis1" => 100, "Ergebnis2" => 60,
      "Aufnahmen1" => 5, "Aufnahmen2" => 5,
      "Höchstserie1" => 50, "Höchstserie2" => 30
    }.freeze

    setup do
      @nbv = regions(:nbv)
      @location = locations(:one)
      @discipline = disciplines(:carom_3band)
      @season = seasons(:current)

      @pa = Player.create!(id: 50_170_601, firstname: "CsvA", lastname: "Spieler", cc_id: 17_611, dbu_nr: 17_801, ba_id: 17_801)
      @pb = Player.create!(id: 50_170_602, firstname: "CsvB", lastname: "Spieler", cc_id: 17_612, dbu_nr: 17_802, ba_id: 17_802)

      @monitor = TableMonitor.create!(state: "ready", data: {})
      @table = Table.create!(name: "CSV-T1", location: @location, table_kind: table_kinds(:one), table_monitor: @monitor)

      @tournament = Tournament.create!(
        title: "CSV Export Test 17-06", region_id: @nbv.id, discipline: @discipline, season: @season,
        organizer: clubs(:bcw), balls_goal: 30, innings_goal: 25, sets_to_play: 1,
        date: Time.zone.parse("2026-05-20 11:00:00 +0200"),
        external_id: "csv-ep-1", manual_assignment: true,
        data: {"table_ids" => [@table.id.to_s]}
      )
    end

    teardown do
      GameParticipation.where(player: [@pa, @pb].compact).delete_all
      # Games haben keinen table_monitor_id-FK — Aufraeumen ueber den data-Marker.
      Game.where("data LIKE ?", "%csv-ep-1%").destroy_all
      Game.where("data LIKE ?", "%OTHER-ep%").destroy_all
      @table&.destroy
      @monitor&.destroy
      @tournament&.destroy
      Player.where(id: [@pa&.id, @pb&.id].compact).delete_all
    end

    test "returns header-only when tournament has no finished games" do
      csv = ExternalTournament::ResultCsvBuilder.new(tournament: @tournament).call
      rows = CSV.parse(csv, col_sep: ";")
      assert_equal 1, rows.size, "nur Header-Zeile"
      assert_equal ResultCsvBuilder::HEADER, rows.first
    end

    test "builds one row per finished game from ba_results with dbu_nr columns" do
      create_game("csv-g1", "csv-ep-1", BA, ended: Time.zone.parse("2026-05-20 12:30:00 +0200"))

      csv = ExternalTournament::ResultCsvBuilder.new(tournament: @tournament).call
      rows = CSV.parse(csv, col_sep: ";", headers: true)
      assert_equal 1, rows.size

      r = rows.first
      assert_equal "csv-g1", r["ExternalId"]
      assert_equal @pa.cc_id.to_s, r["Spieler1_cc_id"]
      assert_equal "17801", r["Spieler1_dbu_nr"]
      assert_equal @pa.fl_name, r["Spieler1"]
      assert_equal "100", r["Ergebnis1"]
      assert_equal "5", r["Aufnahmen1"]
      assert_equal "50", r["HS1"]
      assert_equal @pb.cc_id.to_s, r["Spieler2_cc_id"]
      assert_equal "17802", r["Spieler2_dbu_nr"]
      assert_equal "60", r["Ergebnis2"]
      assert_equal "20.05.2026", r["Datum"]
    end

    test "excludes games of other tournaments sharing the same table monitor" do
      create_game("csv-g1", "csv-ep-1", BA, ended: Time.zone.parse("2026-05-20 12:30:00 +0200"))
      # Fremdes Turnier, gleicher Monitor (Tisch-Wiederverwendung) → MUSS ausgeschlossen sein
      create_game("other-g1", "OTHER-ep", BA, ended: Time.zone.parse("2026-05-20 13:00:00 +0200"))

      csv = ExternalTournament::ResultCsvBuilder.new(tournament: @tournament).call
      rows = CSV.parse(csv, col_sep: ";", headers: true)
      assert_equal 1, rows.size
      assert_equal "csv-g1", rows.first["ExternalId"]
    end

    test "excludes games without ba_results (not finished)" do
      create_game("csv-open", "csv-ep-1", nil, ended: nil)

      csv = ExternalTournament::ResultCsvBuilder.new(tournament: @tournament).call
      rows = CSV.parse(csv, col_sep: ";", headers: true)
      assert_equal 0, rows.size
    end

    test "enumerates durably even after table monitor was unbound (lifecycle exit)" do
      create_game("csv-g1", "csv-ep-1", BA, ended: Time.zone.parse("2026-05-20 12:30:00 +0200"))
      # Simuliere 17-05-Entbindung: TableMonitor verliert Turnier-Bindung + game_id.
      # Die Enumerierung haengt NICHT am Monitor, sondern am durablen data-Marker → Spiel bleibt findbar.
      @monitor.update_columns(tournament_monitor_id: nil, game_id: nil)

      csv = ExternalTournament::ResultCsvBuilder.new(tournament: @tournament).call
      rows = CSV.parse(csv, col_sep: ";", headers: true)
      assert_equal 1, rows.size
      assert_equal "csv-g1", rows.first["ExternalId"]
    end

    private

    def create_game(external_id, tournament_external_id, ba, ended:)
      data = {"external_id" => external_id, "tournament_external_id" => tournament_external_id}
      data["ba_results"] = ba if ba
      @seqno = (@seqno || 0) + 1 # uniqueness scope (tournament_id,gname) — distinkte seqno noetig
      game = Game.create!(
        seqno: @seqno, table_no: 1,
        started_at: Time.zone.parse("2026-05-20 12:00:00 +0200"), ended_at: ended,
        data: data
      )
      GameParticipation.create!(game: game, player: @pa, role: "playera")
      GameParticipation.create!(game: game, player: @pb, role: "playerb")
      game
    end
  end
end
