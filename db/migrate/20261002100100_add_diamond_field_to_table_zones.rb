# frozen_string_literal: true

class AddDiamondFieldToTableZones < ActiveRecord::Migration[7.2]
  # Neuer zone_type diamond_field: die 32 Felder, die die Verbindungslinien der
  # Diamanten bilden (8 x 4). Weingartners Versammlungszone ist immer eines davon
  # (Handoff Claudia 2026-10-02). Muster wie 20260902232138: Check ersetzen, down
  # verweigern, solange Zeilen den neuen Wert nutzen.

  CONSTRAINT = "table_zones_zone_type_check"
  OLD = "zone_type IN ('band_strip','corner_region','line_passage','custom')"
  NEW = "zone_type IN ('band_strip','corner_region','line_passage','custom','diamond_field')"

  def up
    safety_assured do
      remove_check_constraint :table_zones, name: CONSTRAINT
      add_check_constraint :table_zones, NEW, name: CONSTRAINT
    end
  end

  def down
    offending = select_value("SELECT COUNT(*) FROM table_zones WHERE zone_type = 'diamond_field'").to_i
    if offending.positive?
      raise ActiveRecord::IrreversibleMigration,
        "#{offending} Zone(n) nutzen diamond_field — erst entfernen oder umtypisieren."
    end

    safety_assured do
      remove_check_constraint :table_zones, name: CONSTRAINT
      add_check_constraint :table_zones, OLD, name: CONSTRAINT
    end
  end
end
