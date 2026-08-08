# frozen_string_literal: true

# Backfill: Off-by-one in seedings.rank korrigieren (Fix-Folgetask)
#
# Hintergrund: TournamentMonitor::ResultProcessor#update_ranking schrieb die
# DB-Spalte seedings.rank frueher mit `ix + 1`, waehrend die 1-basierte Quelle
# rankings["total"][...]["rank"] den Sieger auf 1 setzt. Bestandsdaten tragen
# damit pro Monitor-Turnier Raenge 2..N+1 statt 1..N. Der Code-Fix
# (update(rank: ix)) korrigiert nur neue Turniere; dieser Task holt Altdaten nach.
#
# Betroffen sind ausschliesslich Regional-/Local-Server: seedings.rank wird nie
# nach oben synchronisiert (Authority carambus_api hat 0 Rank-Werte), der Wert
# entsteht rein lokal durch den Monitor. Die geschriebenen Rank-Zeilen sind local
# (id >= MIN_ID) — LocalProtector blockiert nicht.
#
# Idempotenter Selektor: Unter dem Bug bekommt die Siegergruppe immer ix=1 -> rank=2,
# also gilt pro betroffenem Turnier min(rank) == 2. Nach der Korrektur ist
# min(rank) == 1. Damit ist der Task beliebig oft wiederholbar:
#   - min(rank) == 2  -> Kandidat: alle Raenge des Turniers -1
#   - min(rank) == 1  -> bereits korrekt -> skip
#   - min(rank) >= 3  -> Anomalie (z.B. fehlende Sieger-Seedingzeile) -> NICHT anfassen
#
# Usage:
#   bundle exec rake seedings:backfill_rank                 # DRY-RUN (Default, keine Writes)
#   bundle exec rake seedings:backfill_rank VERBOSE=true    # DRY-RUN mit Zeilen-Detail
#   bundle exec rake seedings:backfill_rank ARMED=true      # LIVE (schreibt)
#
# Auf Produktion nur nach Freigabe und ueber den jeweiligen Regional-Server laufen.
#
# Sicherheits-Mechanik:
# - Writes broadcast-frei via Seeding.skip_cable_ready_updates (Bulk-Konvention).
# - update_column umgeht Validations, Callbacks, PaperTrail und LocalProtector.
#   Backfill ist eine Daten-Korrektur, kein User-Edit — keine Versionierung gewollt.

namespace :seedings do
  desc "Backfill Off-by-one in seedings.rank (ARMED=true zum Schreiben, sonst DRY-RUN)"
  task backfill_rank: :environment do
    armed = ENV["ARMED"] == "true"
    verbose = ENV["VERBOSE"] == "true"

    # Pro Turnier den kleinsten gesetzten Rang bestimmen (nur rank IS NOT NULL).
    min_by_tournament = Seeding.where.not(rank: nil).group(:tournament_id).minimum(:rank)

    candidates = min_by_tournament.select { |_tid, mn| mn == 2 }.keys
    already_ok = min_by_tournament.select { |_tid, mn| mn == 1 }.keys
    anomalies = min_by_tournament.reject { |_tid, mn| [1, 2].include?(mn) }

    puts "=" * 70
    puts "seedings.rank Off-by-one backfill"
    puts "=" * 70
    puts "Mode:            #{armed ? "LIVE (ARMED)" : "DRY-RUN (no DB writes)"}"
    puts "Selektor:        pro Turnier min(rank) == 2 -> alle Raenge -1"
    puts "Turniere gesamt: #{min_by_tournament.size} (mit gesetztem rank)"
    puts "  Kandidaten:    #{candidates.size} (min == 2)"
    puts "  bereits ok:    #{already_ok.size} (min == 1)"
    puts "  Anomalien:     #{anomalies.size} (min >= 3 — werden NICHT angefasst)"
    puts ""

    if anomalies.any?
      puts "!! ANOMALIEN — manuell pruefen, nicht automatisch dekrementiert:"
      anomalies.sort.each { |tid, mn| puts "   Tournament ##{tid}: min(rank) = #{mn}" }
      puts ""
    end

    shifted_seedings = 0

    Seeding.skip_cable_ready_updates do
      candidates.sort.each do |tid|
        rows = Seeding.where(tournament_id: tid).where.not(rank: nil).order(:rank)
        puts "Tournament ##{tid} (#{rows.size} Seedings): #{rows.pluck(:rank)} -> #{rows.pluck(:rank).map { |r| r - 1 }}"
        rows.each do |seeding|
          if verbose
            puts "  #{armed ? "SET  " : "WOULD"} Seeding ##{seeding.id} player ##{seeding.player_id}: #{seeding.rank} -> #{seeding.rank - 1}"
          end
          seeding.update_column(:rank, seeding.rank - 1) if armed
          shifted_seedings += 1
        end
      end
    end

    puts ""
    puts "-" * 70
    puts "Summary"
    puts "-" * 70
    puts "Turniere korrigiert: #{candidates.size}#{" (would fix)" unless armed}"
    puts "Seedings verschoben: #{shifted_seedings}#{" (would shift)" unless armed}"
    puts "Anomalien belassen:  #{anomalies.size}"
    puts ""
    puts armed ? "LIVE-Lauf abgeschlossen." : "DRY-RUN — nichts geschrieben. Mit ARMED=true ausfuehren zum Schreiben."
  end
end
