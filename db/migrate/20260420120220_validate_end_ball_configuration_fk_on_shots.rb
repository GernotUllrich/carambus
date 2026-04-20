class ValidateEndBallConfigurationFkOnShots < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :shots, column: :end_ball_configuration_id
  end
end
