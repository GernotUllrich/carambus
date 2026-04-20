class AddEndBallConfigurationFkToShots < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :shots, :ball_configurations,
      column: :end_ball_configuration_id,
      validate: false
  end
end
