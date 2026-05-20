# frozen_string_literal: true

# Phase 17 / 17-01-fix: Umbenennung des Phase-17-Tisch-Lock-Flags reserved →
# locked_for_tournament, zur klaren Abgrenzung von der Google-Calendar-"Reservierung"
# (die Heizung/Kommunikation steuert). Das Flag bedeutet: an diesem Tisch kann niemand
# sonst ein Spiel anlegen + Operator kann nicht eingreifen (geordneter Turnierbetrieb).
# safety_assured: Spalte ist brandneu (im selben unreleased Branch eingefuehrt), kein
# laufender Code/Prod nutzt sie → Rename unkritisch.
class RenameReservedToLockedForTournament < ActiveRecord::Migration[7.2]
  def change
    safety_assured do
      rename_column :tables, :reserved, :locked_for_tournament
      rename_column :table_locals, :reserved, :locked_for_tournament
    end
  end
end
