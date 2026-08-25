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

  # `TableLocal` traegt `ApiProtector`: dessen after_save-Guard rollt jedes Anlegen zurueck,
  # solange `local_server?` false ist — und dieses Repo IST die Authority. Das ist richtig so,
  # TableLocals entstehen ausschliesslich auf den lokalen Servern (dort steht der Tisch).
  # Im Test wird der Guard deshalb ausdruecklich entsperrt, statt die Server-Rolle zu faelschen.
  #
  # Zweite Fussangel, und die ist auch fachlich relevant: zu `tables(:one)` existieren ZWEI
  # TableLocal-Fixtures (`one` und `two`, beide `table_id: 50000001`), und `table_locals` hat
  # keinen Unique-Index auf `table_id`. `has_one` greift dann einen davon — nicht
  # deterministisch: gemessen lieferten `table.table_local` und
  # `table_monitor.table.table_local` verschiedene Records.
  #
  # Der Test geht deshalb ueber GENAU den Record, den die Aufloesung selbst nutzt. Fuer den
  # Betrieb heisst derselbe Befund: solange ein Tisch mehrere TableLocals hat, ist die
  # Tischsprache nicht verlaesslich — als eigener Punkt gemeldet, nicht hier geflickt.
  def set_table_locale!(table_monitor, locale)
    table = table_monitor.reload.table
    refute_nil table, "Vorbedingung: der TableMonitor muss an einem Tisch haengen"

    # Dublette aufloesen, damit `has_one` eindeutig ist — sonst liefert jeder Zugriff
    # potenziell einen anderen Record und der Test misst Zufall.
    all = TableLocal.where(table_id: table.id).order(:id).to_a
    keeper = all.first || TableLocal.new(table: table)
    TableLocal.where(table_id: table.id).where.not(id: keeper.id).delete_all if keeper.persisted?

    keeper.unprotected = true
    keeper.locale = locale
    keeper.save!
    table.reload
    keeper
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

  # Betreiber-Anforderung 2026-08-25: internationale Gaeste beim TRAINING. Dort gibt es keinen
  # TournamentMonitor, und der URL-Parameter erreicht den Broadcast-Pfad nicht — ohne die
  # Tisch-Stufe waere die Sprache in diesem Fall gar nicht einstellbar.
  test "ohne Turnier greift die Grundsprache des Tisches (Trainingsbetrieb)" do
    table = tables(:one)
    table.update_columns(table_monitor_id: @table_monitor.id)
    set_table_locale!(@table_monitor, "en")

    @table_monitor.update_columns(tournament_monitor_id: nil, tournament_monitor_type: nil)
    assert_equal :en, @table_monitor.reload.display_locale
  end

  test "das laufende Turnier schlaegt die Grundsprache des Tisches" do
    table = tables(:one)
    table.update_columns(table_monitor_id: @table_monitor.id)
    set_table_locale!(@table_monitor, "en")
    attach_monitor!
    @tournament_monitor.update!(locale: "de")

    assert_equal :de, @table_monitor.reload.display_locale,
      "Ein Turnier mit eigener Sprache muss die Tisch-Grundeinstellung ueberschreiben"
  end

  test "ein Turnier OHNE eigene Sprache reicht an den Tisch weiter" do
    table = tables(:one)
    table.update_columns(table_monitor_id: @table_monitor.id)
    set_table_locale!(@table_monitor, "en")
    attach_monitor!
    assert_nil @tournament_monitor.locale

    assert_equal :en, @table_monitor.reload.display_locale,
      "nil heisst 'nicht konfiguriert' und reicht weiter — nicht 'Deutsch'"
  end

  test "TableLocal#locale akzeptiert nur verfuegbare Sprachen" do
    tl = TableLocal.new(table: tables(:one), locale: "kl")
    refute tl.valid?
    assert_includes tl.errors.attribute_names, :locale
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
