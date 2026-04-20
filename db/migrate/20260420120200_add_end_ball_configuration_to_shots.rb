class AddEndBallConfigurationToShots < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :shots, :end_ball_configuration,
      index: { algorithm: :concurrently }

    # JSONB bzw. String-Felder durch typisierte FK-Beziehung ersetzt.
    # Tabelle ist leer, App-Layer kennt die Spalten nicht mehr.
    safety_assured do
      remove_column :shots, :end_position_data, :jsonb, default: {}
      remove_column :shots, :end_position_type, :string
    end
  end
end
