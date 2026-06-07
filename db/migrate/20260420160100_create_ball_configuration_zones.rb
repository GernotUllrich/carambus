class CreateBallConfigurationZones < ActiveRecord::Migration[7.2]
  # v0.8 Tier 2B: M2M-Join BallConfiguration ↔ TableZone mit typisierter
  # Ball-Rolle. Eine Konfiguration kann mehrere Zonen gleichzeitig
  # berühren (B1 zielt nach small_line, B2 parkt in catches).
  def change
    create_table :ball_configuration_zones do |t|
      t.references :ball_configuration, null: false, foreign_key: true
      t.references :table_zone,         null: false, foreign_key: true
      t.string     :which_ball,         null: false
      t.string     :role,               null: false
      t.text       :notes

      t.timestamps
    end

    add_index :ball_configuration_zones,
      [:ball_configuration_id, :table_zone_id, :which_ball, :role],
      unique: true, name: "idx_ball_config_zone_unique"

    add_check_constraint :ball_configuration_zones,
      "which_ball IN ('b1','b2','b3','any')",
      name: "ball_configuration_zones_which_ball_check"

    add_check_constraint :ball_configuration_zones,
      "role IN ('target','source','via')",
      name: "ball_configuration_zones_role_check"
  end
end
