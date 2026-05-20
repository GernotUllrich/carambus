# frozen_string_literal: true

# Phase 17 / 17-04 (App-driven Result-Hold + Pull): Zeitstempel, wann die externe
# Turnier-App das erfasste Spielergebnis abgerufen/bestaetigt hat
# (POST /api/external_tournament/acknowledge_result, carambus.ack/v1).
#
# Nullable: nil = Ergebnis noch nicht von der App bestaetigt. Wird zusammen mit
# game.data["external_id"] vom TableMonitor-Guard external_result_pending? gelesen,
# der den Operator-Release (close_match/start_rematch) bis zur App-Bestaetigung
# blockiert. KEIN Index in diesem Slice (Lokal-Games-Menge klein; der spaetere
# Mitternachts-Job (17-05) filtert ueber table_monitors + id>=MIN_ID, nicht via
# games-Full-Scan) — Index nachruesten falls 17-05 ihn braucht.
class AddResultAcknowledgedAtToGames < ActiveRecord::Migration[7.2]
  def change
    add_column :games, :result_acknowledged_at, :datetime, null: true
  end
end
