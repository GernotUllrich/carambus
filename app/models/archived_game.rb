# frozen_string_literal: true

# Plan 41-01: Archiv-Zeile eines abgeschlossenen App-Turniers.
#
# Warum eine eigene STI-Klasse und nicht einfach ein Game: carambus_app pusht den Endstand
# ausdruecklich NACH JEDER RUNDE, also waehrend der TournamentMonitor noch laeuft. Lagen
# Archiv- und Live-Games ungetrennt am selben Turnier, haette das zwei Folgen:
#
#   * `finals_finished?` (lib/tournament_monitor_state.rb:74) vergleicht `n_games` mit
#     `n_games_done`. Bei gesetztem `executor_params["GK"]` ist `n_games` ein FESTER Sollwert,
#     waehrend Archiv-Games mit `ended_at` nur `n_games_done` erhoehen — die Gleichheit traefe
#     nie zu und das Turnier koennte seine Endphase nicht abschliessen.
#   * Die Spieletabelle nimmt die Spaltenkoepfe aus `data.keys` des ERSTEN Games. Live-Games
#     tragen dort TableMonitor-State (playera, innings_list, …), Archiv-Games die Fachspalten
#     der App — gemischt kaeme eine unbrauchbare Tabelle heraus.
#
# `Game` nutzt STI bereits (InternationalGame, 7 910 Records) — die Unterklasse ist also der
# idiomatische Weg, kein Sonderkonstrukt.
#
# ACHTUNG: `tournament.games` liefert als BASISKLASSE auch diese Records. Die Trennung wirkt
# erst dort, wo eine Abfrage sie auswertet — das ist Plan 41-02 (View-Scope, GC,
# finals_finished?). Bis dahin ist der Typ gesetzt, aber noch nirgends ausgewertet.
class ArchivedGame < Game
end
