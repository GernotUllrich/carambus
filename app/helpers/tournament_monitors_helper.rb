# frozen_string_literal: true

module TournamentMonitorsHelper
  # Spaltenzahl des Kachelrasters der Turnieruebersicht
  # (app/views/locations/scoreboard_tournament_scores.html.erb).
  #
  # Die Tabelle ist von Hand getuned und bleibt unveraendert; neu ist nur, WAS man ihr
  # uebergibt. Bis 2026-10-18 zaehlte die View ALLE gebundenen TableMonitors, rendert aber
  # nur die mit laufendem Spiel: vier gebundene Tische bei zwei Halbfinals ergaben ein
  # 4-Spalten-Raster mit zwei winzigen Kacheln und zusaetzlich die kleinere Schrift
  # (23. DBU Grand Prix Biathlon, 17.10.2026 — im Saal kaum lesbar).
  #
  # ⚠️ `bound_count` ist NICHT das Raster, sondern nur die Untergrenze: solange mehr als ein
  # Tisch gebunden ist, bleiben es mindestens 2 Spalten. Das Grid wird nach dem Seitenaufbau
  # nie neu gerendert (der "teaser"-Job ersetzt nur den Inhalt bestehender Kacheln,
  # table_monitor_job.rb:108ff) — ein Full Reload mitten im Rundenwechsel saehe sonst eine
  # einzelne Kachel ueber die ganze Breite und behielte sie bis zum naechsten Reload.
  #
  # ⚠️ Der `|| 3`-Fallback wird durch die Umstellung anders erreichbar: in der Tabelle fehlt
  # der Schluessel 7 (und alles ueber 18). Bisher traf das nur Hallen mit sieben GEBUNDENEN
  # Tischen, jetzt sieben LAUFENDE Partien. `7 → 3` ist plausibel (6 und 9 ergeben
  # ebenfalls 3), aber es ist eine andere Haeufigkeit als vorher.
  #
  # Als Helfer und nicht inline in der View, damit die Rechnung pruefbar ist: ein
  # Integrationstest auf diese Seite erreicht den Zweig mit dem vorhandenen Fixture-Bestand
  # nicht (ein einziges `games`-Fixture) und waere gruen, ohne etwas zu zeigen — genau so ist
  # es dem `_advance_round_button` bis 2026-09-23 ergangen.
  # Bis 2026-10-18 stand in der View eine zweite, AUSKOMMENTIERTE Fassung dieser Tabelle —
  # sie vergibt bei vielen Tischen mehr Spalten statt sie auf vier zu deckeln. Sie ist beim
  # Umbau hierher gewandert, damit sie nicht verlorengeht; wer sie ausprobieren will, tauscht
  # nur die Werte, nicht die Aufrufstelle:
  #
  #   { 1 => 1, 2 => 2, 3 => 2, 4 => 2, 5 => 2, 6 => 2, 8 => 2, 9 => 2, 10 => 5,
  #     11 => 6, 12 => 6, 13 => 7, 14 => 7, 15 => 5, 16 => 6, 17 => 6, 18 => 6 }
  #
  # ⚠️ Vor einem Versuch pruefen, ob die noetigen grid-cols-N im Build sind: 5, 6 und 7 kommen
  # dort heute nur deshalb vor, weil locations/_table_scores.html.erb:11-17 sieben leere Divs
  # allein zu diesem Zweck haelt.
  TEASER_GRID_COLS = {
    1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 4, 6 => 3, 8 => 4, 9 => 3, 10 => 4,
    11 => 4, 12 => 4, 13 => 4, 14 => 4, 15 => 3, 16 => 4, 17 => 4, 18 => 4
  }.freeze

  def teaser_grid_cols(active_count:, bound_count:)
    min_cols = [bound_count, 2].min
    grid_count = [active_count, min_cols].max
    TEASER_GRID_COLS[grid_count] || 3
  end
end
