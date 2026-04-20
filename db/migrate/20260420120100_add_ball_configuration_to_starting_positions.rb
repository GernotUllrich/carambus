class AddBallConfigurationToStartingPositions < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :starting_positions, :ball_configuration,
      null: false,
      index: { algorithm: :concurrently }

    # Die JSONB-Spalten sind im v0.7-Schema typisiert und leben jetzt auf
    # ball_configurations. Die Tabelle ist leer, der App-Layer referenziert
    # sie nicht mehr -> safety_assured ist hier korrekt.
    safety_assured do
      remove_column :starting_positions, :ball_measurements, :jsonb, default: {}
      remove_column :starting_positions, :position_variants, :jsonb, default: []
    end
  end
end
