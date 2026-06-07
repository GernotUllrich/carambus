class AddClassificationToBallConfigurations < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    # v0.8 Tier 1: Ontologie-Attribute, die in v0.7 nur als Prosa auf
    # ball_configurations.notes existierten. Alle nullable (Tier 1 erzwingt
    # keine Nachpflege), position_type bekommt default 'exact'.
    add_column :ball_configurations, :flow_direction, :string
    add_column :ball_configurations, :biais_degrees,  :float
    add_column :ball_configurations, :biais_class,    :string
    add_column :ball_configurations, :orientation,    :string
    add_column :ball_configurations, :target_cushion, :string
    add_column :ball_configurations, :position_type,  :string, default: "exact", null: false

    add_check_constraint :ball_configurations,
      "flow_direction IS NULL OR flow_direction IN ('centrifugal', 'centripetal')",
      name: "ball_configs_flow_direction_check", validate: false

    add_check_constraint :ball_configurations,
      "biais_degrees IS NULL OR (biais_degrees >= -180 AND biais_degrees <= 180)",
      name: "ball_configs_biais_degrees_check", validate: false

    add_check_constraint :ball_configurations,
      "biais_class IS NULL OR biais_class IN ('imperceptible', 'faible', 'moyen', 'prononce', 'extreme')",
      name: "ball_configs_biais_class_check", validate: false

    add_check_constraint :ball_configurations,
      "orientation IS NULL OR orientation IN ('gather', 'distribute', 'hybrid')",
      name: "ball_configs_orientation_check", validate: false

    add_check_constraint :ball_configurations,
      "target_cushion IS NULL OR target_cushion IN ('short_left', 'short_right', 'long_near', 'long_far')",
      name: "ball_configs_target_cushion_check", validate: false

    add_check_constraint :ball_configurations,
      "position_type IN ('exact', 'approximate', 'qualitative')",
      name: "ball_configs_position_type_check", validate: false
  end
end
