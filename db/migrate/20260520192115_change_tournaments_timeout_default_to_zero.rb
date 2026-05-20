# frozen_string_literal: true

# Genereller Fix (Phase 17 / 17-03 Live-Verify-Befund): Der DB-Default
# tournaments.timeout = 45 sickerte ueber initialize_tournament_monitor in den
# TournamentMonitor und damit in den Scoreboard-Timer (langjaehriges Aergernis).
# Neuer Default 0 (kein Shot-Clock), sofern nicht explizit gesetzt. Bestehende
# Tournament-Records bleiben unveraendert (nur der Default fuer neue Records aendert sich).
class ChangeTournamentsTimeoutDefaultToZero < ActiveRecord::Migration[7.2]
  def change
    change_column_default :tournaments, :timeout, from: 45, to: 0
  end
end
