# frozen_string_literal: true

# Plan 40-01: Anzeigesprache je Turnier.
#
# Bewusst NULLABLE und ohne Default: `nil` heisst "nicht konfiguriert" und muss von einem
# ausdruecklich gesetzten "de" unterscheidbar bleiben — sonst kann die Aufloesung nicht
# entscheiden, ob sie auf die bestehende Kette (params -> user -> header -> default)
# zurueckfallen darf.
#
# Kein Index: der Wert wird ausschliesslich ueber die Assoziation gelesen
# (TableMonitor#display_locale), nie gefiltert.
class AddLocaleToTournamentMonitors < ActiveRecord::Migration[7.2]
  def change
    add_column :tournament_monitors, :locale, :string
  end
end
