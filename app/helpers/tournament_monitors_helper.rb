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
