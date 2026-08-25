# frozen_string_literal: true

# Plan 40-01 (Erweiterung auf Betreiber-Anforderung 2026-08-25): Grundsprache je Tisch.
#
# Die Turniersprache (tournament_monitors.locale) deckt nur Turnierbetrieb ab. Beim TRAINING
# gibt es keinen TournamentMonitor — und der URL-Parameter erreicht den Broadcast-Pfad nicht,
# weil der ohne Request rendert. Ohne diese Spalte waere die Sprache bei turnierlosen Spielen
# gar nicht mehr einstellbar (fuer internationale Gaeste beim Training genau der Fall).
#
# `table_locals` ist die richtige Ebene: lokal (ApiProtector), traegt bereits die ortsgebundene
# Konfiguration eines Tisches (IP, Tischheizung, Kalender-Event). Nullable ohne Default —
# `nil` heisst "nicht konfiguriert" und reicht an die naechste Stufe weiter.
class AddLocaleToTableLocals < ActiveRecord::Migration[7.2]
  def change
    add_column :table_locals, :locale, :string
  end
end
