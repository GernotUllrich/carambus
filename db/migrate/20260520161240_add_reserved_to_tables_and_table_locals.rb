# frozen_string_literal: true

# Phase 17 / 17-01: Tischbezogene Reservierung als lokales Attribut.
# Spalte MUSS auf BEIDEN Tabellen liegen: Der LOCAL_METHODS-Getter in Table routet
# fuer globale Tische (id < MIN_ID) auf table_local; fehlt dort eine Row, faellt er
# auf read_attribute(:reserved) der tables-Spalte zurueck. Beide default false.
class AddReservedToTablesAndTableLocals < ActiveRecord::Migration[7.2]
  def change
    add_column :tables, :reserved, :boolean, default: false, null: false
    add_column :table_locals, :reserved, :boolean, default: false, null: false
  end
end
