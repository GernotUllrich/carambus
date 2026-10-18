# frozen_string_literal: true

require "test_helper"

# Kachelraster der Turnieruebersicht (sb_state=tournament_scores).
#
# Der Fall, der die Aenderung ausgeloest hat: 23. DBU Grand Prix Biathlon, 17.10.2026, BC Wedel.
# Vier Tische ans Turnier gebunden, in den Halbfinals liefen zwei Partien. Die View zaehlte die
# GEBUNDENEN (4) und rendert die LAUFENDEN (2) — vier Spalten mit zwei Kacheln, dazu die
# kleinere Schrift (text-2vw statt 3vw), im Saal kaum lesbar.
#
# Die Erwartungswerte stammen aus HANDOFF-to-carambus-tournament-scores-raster.md.
class TournamentMonitorsHelperTest < ActionView::TestCase
  # --- der Fall vom 17.10. und seine Nachbarn ------------------------------------------------

  test "4 gebunden / 2 laufend ergibt 2 Spalten — der Fall vom 17.10.2026" do
    assert_equal 2, teaser_grid_cols(active_count: 2, bound_count: 4)
  end

  test "4 gebunden / 4 laufend bleibt bei 4 Spalten — unveraendert gegenueber vorher" do
    assert_equal 4, teaser_grid_cols(active_count: 4, bound_count: 4)
  end

  test "1 gebunden / 1 laufend ergibt 1 Spalte" do
    assert_equal 1, teaser_grid_cols(active_count: 1, bound_count: 1)
  end

  # --- die Untergrenze ----------------------------------------------------------------------
  #
  # Sie faengt den Reload mitten im Rundenwechsel ab: das Grid wird nach dem Seitenaufbau nie
  # neu gerendert, eine einzelne Kachel ueber die ganze Breite blieb also bis zum naechsten
  # Reload stehen.

  test "4 gebunden / 1 laufend: Untergrenze haelt 2 Spalten" do
    assert_equal 2, teaser_grid_cols(active_count: 1, bound_count: 4),
      "Ohne Untergrenze waere es 1 Spalte — eine Kachel ueber die ganze Bildschirmbreite"
  end

  test "4 gebunden / 0 laufend: 2 Spalten, leeres Grid, keine Exception" do
    assert_equal 2, teaser_grid_cols(active_count: 0, bound_count: 4)
  end

  # Die andere Seite der Untergrenze: bei einem einzigen gebundenen Tisch darf sie NICHT auf
  # 2 aufblasen. `[bound_count, 2].min` ist genau dafuer da — ein Test nur mit bound_count: 4
  # wuerde ein hartes `2` nicht von der Rechnung unterscheiden.
  test "1 gebunden / 0 laufend bleibt bei 1 Spalte — Untergrenze greift nicht" do
    assert_equal 1, teaser_grid_cols(active_count: 0, bound_count: 1)
  end

  # --- der Fallback -------------------------------------------------------------------------
  #
  # ⚠️ In der Tabelle fehlt der Schluessel 7 (und alles ueber 18). Bisher traf das nur Hallen
  # mit sieben GEBUNDENEN Tischen, nach der Umstellung sieben LAUFENDE Partien — also eine
  # andere Haeufigkeit. 7 -> 3 passt zu 6 -> 3 und 9 -> 3 und ist damit plausibel; der Test
  # haelt den Wert fest, damit die Luecke nicht unbemerkt zu etwas anderem wird.

  test "7 laufend trifft den Fallback und ergibt 3 Spalten" do
    assert_equal 3, teaser_grid_cols(active_count: 7, bound_count: 7)
  end

  test "mehr als 18 laufend trifft ebenfalls den Fallback" do
    assert_equal 3, teaser_grid_cols(active_count: 19, bound_count: 19)
  end

  # --- die Schriftformel haengt am Ergebnis -------------------------------------------------
  #
  # Die View setzt `text-<%= cols < 4 ? "3" : "2" %>vw`. Das ist der Grund, warum der Fehler
  # doppelt wehtat: vier Spalten brachten zugleich die kleinere Schrift.

  test "die Schriftgroesse folgt der Spaltenzahl" do
    assert_operator teaser_grid_cols(active_count: 2, bound_count: 4), :<, 4,
      "2 laufende Partien muessen text-3vw ergeben (cols < 4)"
    assert_equal 4, teaser_grid_cols(active_count: 4, bound_count: 4),
      "4 laufende Partien bleiben bei text-2vw (cols == 4)"
  end
end
