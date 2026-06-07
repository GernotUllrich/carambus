class ValidateBallConfigurationClassificationChecks < ActiveRecord::Migration[7.2]
  def change
    validate_check_constraint :ball_configurations, name: "ball_configs_flow_direction_check"
    validate_check_constraint :ball_configurations, name: "ball_configs_biais_degrees_check"
    validate_check_constraint :ball_configurations, name: "ball_configs_biais_class_check"
    validate_check_constraint :ball_configurations, name: "ball_configs_orientation_check"
    validate_check_constraint :ball_configurations, name: "ball_configs_target_cushion_check"
    validate_check_constraint :ball_configurations, name: "ball_configs_position_type_check"
  end
end
