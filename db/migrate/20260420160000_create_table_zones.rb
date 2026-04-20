class CreateTableZones < ActiveRecord::Migration[7.2]
  # v0.8 Tier 2B: benannte Tisch-Regionen als first-class Entities.
  # polygon_normalized hält die Umrisse in [0,1]-Koords, tisch-variant-
  # unabhängig; Denormalisierung per table_variant bei der Darstellung.
  def change
    create_table :table_zones do |t|
      t.string  :key,                null: false
      t.string  :label,              null: false
      t.string  :zone_type,          null: false
      t.jsonb   :polygon_normalized, null: false, default: []
      t.text    :description
      t.string  :gretillat_ref
      t.string  :weingartner_ref

      t.timestamps
    end

    add_index :table_zones, :key, unique: true

    add_check_constraint :table_zones,
      "zone_type IN ('band_strip','corner_region','line_passage','custom')",
      name: "table_zones_zone_type_check"
  end
end
