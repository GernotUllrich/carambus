class CreateStartingPositions < ActiveRecord::Migration[7.2]
  def change
    create_table :starting_positions do |t|
      t.references :training_example, null: false, foreign_key: true, index: { unique: true }
      t.text :description_text
      t.jsonb :ball_measurements, default: {}
      t.jsonb :position_variants, default: []

      t.timestamps
    end
  end
end
