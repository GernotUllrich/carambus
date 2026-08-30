# frozen_string_literal: true

require "test_helper"

# Die Sprachumschaltung am Tisch-Scoreboard (Plan 40-02) ist ENTFALLEN.
#
# Betreiber-Entscheidung 2026-08-30: die Anzeigesprache kommt aus
# `Carambus.config.scoreboard_locale` und gilt für den ganzen Server. Eine Umschaltung am
# einzelnen Tisch wirkte auf ALLE Betrachter dieses Scoreboards — nicht nur auf den
# Klickenden — und war damit die letzte Stelle, an der eine Anzeige aus der Reihe tanzen
# konnte. Wo die Sprache stattdessen herkommt, prüft `locale_persistence_test.rb`.
#
# Was von 40-02 bleibt: dieser Renderpfad. Das Menü-Partial wird von keinem anderen Test
# gerendert — ein ERB-Fehler oder ein nil-Zugriff auf den polymorphen `tournament_monitor`
# fiele sonst erst am Scoreboard auf.
class TableMonitorsToggleLocaleTest < ActionDispatch::IntegrationTest
  BASE_ID = 54_300_000

  setup do
    @table_monitor = table_monitors(:one)
  end

  test "die Icon-Leiste rendert ohne Turnier" do
    html = ApplicationController.render(partial: "table_monitors/menu",
      locals: {table_monitor: @table_monitor})

    refute_includes html, "toggle_locale", "der Umschalter ist entfallen"
    assert_includes html, "circle-info", "die übrigen Icons stehen weiter da"
  end

  # `tournament_monitor` ist polymorph: bei Liga-Spielen hängt dort ein PartyMonitor ohne
  # locale-Spalte. Das Partial fragte das früher ab — der Pfad muss weiter tragen.
  test "die Icon-Leiste rendert auch mit Turnier" do
    tournament_monitor = TournamentMonitor.create!(id: BASE_ID + 2,
      tournament: tournaments(:local), locale: "en")
    @table_monitor.update_columns(tournament_monitor_id: tournament_monitor.id,
      tournament_monitor_type: "TournamentMonitor")

    html = ApplicationController.render(partial: "table_monitors/menu",
      locals: {table_monitor: @table_monitor.reload})

    refute_includes html, "toggle_locale"
    assert_includes html, "circle-info"
  end

  # Die Route ist mit der Action verschwunden — ein Aufruf darf keine 500 mehr erzeugen,
  # sondern muss ins Leere laufen.
  test "die Route ist weg" do
    assert_raises(NoMethodError) do
      Rails.application.routes.url_helpers.toggle_locale_table_monitor_path(@table_monitor)
    end
  end
end
