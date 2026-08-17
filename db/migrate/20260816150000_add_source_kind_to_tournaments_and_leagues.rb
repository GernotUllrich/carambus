# frozen_string_literal: true

# Saison-abhängige Quellen-Kennung (Phase 34-01). Rein additiv: nullable, ohne Default,
# ohne Backfill in der Migration — 18 522 Turniere und 6 429 Ligen gehören nicht in eine
# Migrationstransaktion. Der Bestand wird per `rake source_kind:backfill` nachgetragen,
# broadcast-frei und versionserzeugend.
#
# Kein Index: die Auswertung ist ein Full-Scan-Report, der Wizard prüft am bereits geladenen
# Record. Ein Index wäre reine Wartungslast.
class AddSourceKindToTournamentsAndLeagues < ActiveRecord::Migration[7.2]
  def change
    add_column :tournaments, :source_kind, :string
    add_column :leagues, :source_kind, :string
  end
end
