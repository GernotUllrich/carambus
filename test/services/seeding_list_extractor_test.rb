# frozen_string_literal: true

require "test_helper"

# Einladungs-PDFs des NBV werden seit September 2026 aus der ClubCloud generiert. Das Format
# unterscheidet sich vom bisherigen an drei Stellen, die der Parser auswertet:
#
#   | Bereich      | bisher                        | CC-Format                                  |
#   |--------------|-------------------------------|--------------------------------------------|
#   | Setzliste    | "1 Nachname Vorname 100"      | "1   1,51   Nachname, Vorname   Verein"    |
#   | Modus        | "Turniermodus: T7 - ..."      | "Modus:   T7 - Jeder gegen jeden"          |
#   | Ausspielziel | "Bälle: 40" (Wort vor Zahl)   | "40 Punkte / 20 Aufnahmen" (Zahl zuerst)   |
#
# ⚠️ Die Zahl beim Spieler bedeutet im CC-Format etwas ANDERES: vorher stand dort das Ballziel
# (die Vorgabe), jetzt der Generaldurchschnitt aus der Rangliste. Wer sie als `balls_goal`
# übernimmt, traegt 1,51 als Vorgabe ein. Deshalb wird die GD hier bewusst NICHT ausgewertet
# (Betreiber-Entscheidung 2026-09-17: nur reparieren, was schon ausgewertet wurde).
#
# Das Fixture ist der echte, per pdf-reader extrahierte Text einer NBV-Einladung — Namen,
# Vereine und Anschrift sind ersetzt, weil dieses Repository oeffentlich ist. Die
# Spaltenstruktur ist unveraendert.
class SeedingListExtractorTest < ActiveSupport::TestCase
  def cc_text
    @cc_text ||= Rails.root.join("test/fixtures/files/nbv_einladung_cc_format.txt").read
  end

  def result
    @result ||= SeedingListExtractor.parse_seeding_list(cc_text)
  end

  # --- Setzliste ------------------------------------------------------------

  test "liest alle sechs Teilnehmer aus der Setzliste" do
    assert result[:success], "Die Extraktion meldet Misserfolg: #{result[:error].inspect}"
    assert_equal 6, Array(result[:players]).size,
      "Erwartet 6 Teilnehmer, gefunden: #{Array(result[:players]).map { |p| p[:full_name] }.inspect}"
  end

  test "trennt Nachname und Vorname am Komma" do
    erster = result[:players].first
    assert_equal 1, erster[:position]
    assert_equal "Mustermann", erster[:lastname]
    assert_equal "Anton", erster[:firstname]
  end

  test "erkennt Doppelnamen und Bindestrich-Vornamen" do
    namen = result[:players].map { |p| [p[:lastname], p[:firstname]] }
    assert_includes namen, ["Beispiel", "Berta"]
    assert_equal 6, result[:players].map { |p| p[:position] }.uniq.size,
      "Positionen sind nicht eindeutig: #{result[:players].map { |p| p[:position] }.inspect}"
  end

  test "die GD wird NICHT als Ballziel uebernommen" do
    # Der gefaehrlichste Fehler beim Formatwechsel: 1,51 als Vorgabe statt als Durchschnitt.
    result[:players].each do |p|
      assert_nil p[:balls_goal],
        "Spieler #{p[:full_name]} hat ein balls_goal #{p[:balls_goal].inspect} — das ist die GD"
    end
  end

  test "Teilnehmer ohne GD (Strich) werden mitgelesen" do
    namen = result[:players].map { |p| p[:full_name] }
    assert_includes namen, "Dahl, Dora", "Der Spieler ohne GD-Wert fehlt"
    assert_includes namen, "Frahm, Frieda"
  end

  # --- Modus und Ausspielziel ----------------------------------------------

  test "erkennt den Turniermodus aus der Zeile 'Modus:'" do
    assert_match(/T7/, result[:plan_info].to_s,
      "Modus nicht erkannt, plan_info: #{result[:plan_info].inspect}")
  end

  test "liest Ausspielziel '40 Punkte / 20 Aufnahmen'" do
    params = result[:extracted_params] || {}
    assert_equal 40, params[:balls_goal], "balls_goal falsch: #{params.inspect}"
    assert_equal 20, params[:innings_goal], "innings_goal falsch: #{params.inspect}"
  end

  # --- Abgrenzung -----------------------------------------------------------

  test "die Abschnitte nach der Setzliste erzeugen keine Geisterspieler" do
    # Nach der Setzliste folgt "Wichtiges" mit Zeilen wie "Regeln:", "Doping:", "Haftung:".
    namen = result[:players].map { |p| p[:lastname] }
    %w[Regeln Doping Haftung Vorbehalte Mit].each do |wort|
      assert_not_includes namen, wort, "'#{wort}' wurde als Spieler gelesen"
    end
  end
end
