# frozen_string_literal: true

require "test_helper"

# Plan 40-01: Anzeigesprache am Turnier + die gemeinsame Aufloesungsstelle.
#
# Die Sprache haengt bewusst am TournamentMonitor und nicht am Tisch oder an der Location:
# TournamentMonitor ist lokal (ApiProtector) und damit auch dann beschreibbar, wenn das Turnier
# selbst ein globaler Record ist — `Location` waere es nicht (LocalProtector), `TableLocal`
# waere die Tisch- statt der Turnier-Achse.
class TournamentMonitorLocaleTest < ActiveSupport::TestCase
  BASE_ID = 54_100_000

  setup do
    @tournament = tournaments(:local)
    @tournament_monitor = TournamentMonitor.create!(id: BASE_ID + 1, tournament: @tournament)
    @table_monitor = table_monitors(:free)
  end

  def attach_monitor!
    @table_monitor.update_columns(tournament_monitor_id: @tournament_monitor.id,
      tournament_monitor_type: "TournamentMonitor")
  end

  test "locale ist ohne Konfiguration nil — unterscheidbar von ausdruecklichem 'de'" do
    assert_nil @tournament_monitor.locale
    @tournament_monitor.update!(locale: "de")
    assert_equal "de", @tournament_monitor.reload.locale
  end

  test "locale akzeptiert nur verfuegbare Sprachen" do
    @tournament_monitor.locale = "kl"
    refute @tournament_monitor.valid?, "Ein Tippfehler darf nicht in die DB gelangen"
    assert_includes @tournament_monitor.errors.attribute_names, :locale

    @tournament_monitor.locale = I18n.available_locales.first.to_s
    assert @tournament_monitor.valid?
  end

  test "display_locale liefert die konfigurierte Sprache als Symbol" do
    attach_monitor!
    @tournament_monitor.update!(locale: "en")
    assert_equal :en, @table_monitor.reload.display_locale
  end

  test "display_locale liefert nil ohne Konfiguration — der Aufrufer faellt auf seine Kette zurueck" do
    attach_monitor!
    assert_nil @table_monitor.reload.display_locale
  end

  test "display_locale ist nil-sicher ohne TournamentMonitor" do
    tm = TableMonitor.new
    assert_nil tm.display_locale
  end

  # `tournament_monitor` ist polymorph: bei Liga-Spielen haengt dort ein PartyMonitor, der
  # keine locale-Spalte hat. `respond_to?` statt Typpruefung — sonst wirft die Aufloesung
  # ausgerechnet im Ligabetrieb.
  test "display_locale vertraegt einen PartyMonitor ohne locale-Spalte" do
    party_monitor = PartyMonitor.new
    @table_monitor.define_singleton_method(:tournament_monitor) { party_monitor }
    assert_nil @table_monitor.display_locale
  end
end
