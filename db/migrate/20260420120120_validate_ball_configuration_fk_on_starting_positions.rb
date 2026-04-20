class ValidateBallConfigurationFkOnStartingPositions < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :starting_positions, :ball_configurations
  end
end
