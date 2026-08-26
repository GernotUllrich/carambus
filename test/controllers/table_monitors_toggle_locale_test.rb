# frozen_string_literal: true

require "test_helper"

# Plan 40-02: Sprachumschaltung direkt am Tisch-Scoreboard.
#
# Bewusst OHNE eigenen Autorisierungs-Guard: wer am Scoreboard steht, kann dort bereits den
# Spielstand aendern — die Anzeigesprache umzuschalten ist geringerwertig. Ein strengerer Guard
# waere inkonsistent zum bestehenden Schreibpfad.
#
# Der Renderpfad selbst ist durch 40-01 abgedeckt und wird hier NICHT erneut geprueft.
class TableMonitorsToggleLocaleTest < ActionDispatch::IntegrationTest
  BASE_ID = 54_300_000

  setup do
    # `TableLocal` traegt ApiProtector: sein after_save-Guard rollt jedes Schreiben zurueck,
    # solange `local_server?` false ist — und dieses Repo IST die Authority. Genau das ist
    # gewollt (auf der Authority steht kein Tisch), fuer den Test wird die Rolle umgestellt.
    @original_api_url = Carambus.config.carambus_api_url
    Carambus.config.carambus_api_url = "http://local.test"

    @table_monitor = table_monitors(:one)   # haengt an tables(:one), die einen TableLocal hat
    @table_local = table_locals(:one)
    @table_local.update!(locale: nil)
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  test "ohne Turnier schaltet das Icon die Tischsprache um und speichert sie" do
    get toggle_locale_table_monitor_url(@table_monitor)

    assert_response :redirect
    assert_equal "en", @table_local.reload.locale,
      "Ausgangslage ist die effektive Sprache (default :de) — ein Klick muss auf :en fuehren"

    get toggle_locale_table_monitor_url(@table_monitor)
    assert_equal "de", @table_local.reload.locale, "Der zweite Klick schaltet zurueck"
  end

  # AC-5 — der Test, den der Guard in der Action traegt.
  test "gibt das Turnier die Sprache vor, bleibt die Tischsprache unveraendert" do
    tournament_monitor = TournamentMonitor.create!(id: BASE_ID + 1,
      tournament: tournaments(:local), locale: "en")
    @table_monitor.update_columns(tournament_monitor_id: tournament_monitor.id,
      tournament_monitor_type: "TournamentMonitor")
    # Tischsprache ABSICHTLICH gleich der Turniersprache: nur so unterscheiden sich "Guard greift"
    # und "Guard fehlt" im Ergebnis. Mit `de` am Tisch waere der Test blind gewesen — die
    # ungeschuetzte Action haette aus display_locale `:en` ebenfalls `de` gemacht, und die
    # Gegenprobe blieb gruen (gemessen 2026-08-26).
    @table_local.update!(locale: "en")

    get toggle_locale_table_monitor_url(@table_monitor)

    assert_response :redirect
    assert_equal "en", @table_local.reload.locale,
      "Das Turnier schlaegt den Tisch — ein Klick darf die Tischsprache dann nicht still aendern"
  end

  # Das Menue-Partial wird von keinem anderen Test gerendert — ein ERB-Fehler oder ein nil-Zugriff
  # auf den polymorphen `tournament_monitor` faellt sonst erst am Scoreboard auf.
  test "die Icon-Leiste zeigt den Umschalter, und bei Turniersprache den gesperrten Zustand" do
    html = ApplicationController.render(partial: "table_monitors/menu",
      locals: {table_monitor: @table_monitor})
    assert_includes html, "toggle_locale", "ohne Turnier muss das Icon bedienbar sein"
    refute_includes html, "cursor-not-allowed opacity-50"

    tournament_monitor = TournamentMonitor.create!(id: BASE_ID + 2,
      tournament: tournaments(:local), locale: "en")
    @table_monitor.update_columns(tournament_monitor_id: tournament_monitor.id,
      tournament_monitor_type: "TournamentMonitor")

    html = ApplicationController.render(partial: "table_monitors/menu",
      locals: {table_monitor: @table_monitor.reload})
    refute_includes html, "toggle_locale_table_monitor", "gibt das Turnier die Sprache vor, kein Link"
    assert_includes html, "cursor-not-allowed"
    assert_includes html, I18n.t("table_monitor.locale_from_tournament")
  end

  test "ein Tisch ohne TableLocal legt keinen an und wirft nicht" do
    table_monitor = table_monitors(:two)   # tables(:two) hat absichtlich keinen TableLocal
    assert_nil table_monitor.table&.table_local, "Vorbedingung: dieser Tisch hat keinen TableLocal"

    assert_no_difference("TableLocal.count") do
      get toggle_locale_table_monitor_url(table_monitor)
    end
    assert_response :redirect
  end
end
