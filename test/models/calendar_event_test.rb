# frozen_string_literal: true

require "test_helper"

# Tischerkennung aus Kalender-Titeln (Vorfall 2026-09-21: der Clubabend blieb kalt).
#
# Zwei Fehlerklassen, beide legten den gesamten Heizungslauf lahm, nicht nur einen Termin:
#   1. Ein Termin OHNE Titel — `nil.match` in carambus.rake:105 / calendar_event.rb:16
#   2. Eine Tischnummer, die es am Spielort nicht gibt — `nil.table_kind` beim Aufrufer
# Dazu die Toleranz beim Lesen: `T5(!)` und `T1-5` wurden nicht erkannt (Betreiber, 2026-09-21).
class CalendarEventTest < ActiveSupport::TestCase
  setup do
    @location = locations(:one)
    # Die Zuordnung ist positionsbasiert: tables.order(:name).to_a[n-1]
    @tables = @location.tables.order(:name).to_a
  end

  # --- Was schon vor dem Fix funktionierte: darf nicht kaputtgehen ---

  test "Tischnummer am Anfang" do
    assert_equal [@tables[0]], CalendarEvent.tables_from_summary("T1 Hajo + Georg", @location)
  end

  test "Tischnummer hinter dem Namen, mit Leerzeichen vor der Klammer" do
    assert_equal [@tables[1]], CalendarEvent.tables_from_summary("Ulf T2 (!)", @location)
  end

  test "Komma-Liste" do
    assert_equal [@tables[0], @tables[1]], CalendarEvent.tables_from_summary("T1,T2 (!) Clubabend", @location)
  end

  test "Bereich mit zwei T" do
    assert_equal @tables[0..1], CalendarEvent.tables_from_summary("T1-T2 (!) Clubabend", @location)
  end

  test "Titel ohne Tischangabe ergibt nichts" do
    assert_empty CalendarEvent.tables_from_summary("13:00 Frau Britta Friseur", @location)
  end

  # --- Neu: Toleranz (Betreiber-Entscheidung 2026-09-21) ---

  test "Klammer klebt an der Tischnummer" do
    assert_equal [@tables[1]], CalendarEvent.tables_from_summary("Nils T2(!)", @location)
  end

  test "Kleinschreibung" do
    assert_equal [@tables[1]], CalendarEvent.tables_from_summary("Nils t2 (!)", @location)
  end

  test "Satzzeichen hinter einem Bereich" do
    assert_equal @tables[0..1], CalendarEvent.tables_from_summary("T1-T2.", @location)
  end

  test "Bereich ohne zweites T" do
    assert_equal @tables[0..1], CalendarEvent.tables_from_summary("T1-2 Clubabend", @location)
  end

  test "Bereich mit anklebender Klammer" do
    assert_equal @tables[0..1], CalendarEvent.tables_from_summary("T1-T2(!) Clubabend", @location)
  end

  # --- Neu: kein Absturz mehr bei unbrauchbarer Eingabe ---

  test "Titel nil ergibt leere Liste statt NoMethodError" do
    assert_empty CalendarEvent.tables_from_summary(nil, @location)
  end

  test "Tischnummer, die es am Spielort nicht gibt, wird uebersprungen" do
    too_big = "T#{@tables.size + 1} Mueller"
    result = CalendarEvent.tables_from_summary(too_big, @location)
    assert_empty result, "Tisch #{@tables.size + 1} existiert nicht und darf nicht als nil im Ergebnis landen"
    assert_not_includes result, nil
  end

  test "gueltige und ungueltige Nummer gemischt: der gueltige Tisch bleibt" do
    mixed = "T1,T#{@tables.size + 5} Clubabend"
    assert_equal [@tables[0]], CalendarEvent.tables_from_summary(mixed, @location)
  end

  test "T0 wird uebersprungen (waere sonst der letzte Tisch)" do
    assert_empty CalendarEvent.tables_from_summary("T0 Unsinn", @location)
  end

  # --- Bestehende Regel bleibt: `Wort:` ist kein Tischereignis ---
  # (Die Regel steht beim Aufrufer, nicht hier — dieser Test haelt fest, dass
  #  tables_from_summary selbst den Doppelpunkt-Titel nicht plötzlich deutet.)

  test "Doppelpunkt-Titel ohne Tischangabe ergibt nichts" do
    assert_empty CalendarEvent.tables_from_summary("Reparatur: Heizung pruefen", @location)
  end
end
