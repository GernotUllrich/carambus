# frozen_string_literal: true

# Entfernt die ungenutzte Spalte `players.pin4` (Plan 02.1-04).
#
# Die Spalte kam mit 20240313200943 und ist seither in 47.774 Datensaetzen KEIN EINZIGES MAL
# gefuellt worden. Sie war global eindeutig validiert — bei vier Stellen waeren systemweit
# hoechstens ~9.980 PINs vergebbar gewesen, und ein erratener PIN identifizierte einen Spieler
# — und sie speicherte im KLARTEXT. Der Spieler-PIN lebt seit 3ab79224 in `PlayerLocal`:
# gehasht, lokal, ohne Eindeutigkeitszwang.
#
# ⚠️ WARUM DAS HIER GEFAHRLOS IST — beides musste VORHER auf allen Instanzen liegen:
#
# 1. `Player.ignored_columns` traegt `pin4` seit 75340514. Ohne das laeuft zwischen
#    `db:migrate` und dem Puma-Neustart alter Code gegen eine fehlende Spalte.
# 2. `Version.reject_unknown_columns!` (ebenfalls 75340514) verwirft `pin4` aus den
#    Authority-Snapshots. Das ist DAUERHAFT noetig, nicht nur uebergangsweise: die bereits
#    bestehenden Authority-Versionen tragen `pin4` fuer immer in ihrem YAML und werden jedem
#    nachhinkenden Server nachgespielt. Ohne den Filter scheiterte dort jeder Player-Apply.
#
# `safety_assured` ist Pflicht — `strong_migrations` verweigert `remove_column` grundsaetzlich.
# Vorbild im Repo: 20240308151850_remove_club_id_from_locations.rb.
#
# ⚠️ Der Typ `:string` wird MITGEGEBEN, anders als in jenem Vorbild: ohne ihn ist
# `remove_column` nicht umkehrbar und ein `db:rollback` scheitert.
class RemovePin4FromPlayers < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :players, :pin4, :string }
  end
end
