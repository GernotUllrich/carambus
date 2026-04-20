class AddBallConfigurationFkToStartingPositions < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :starting_positions, :ball_configurations, validate: false
  end
end
