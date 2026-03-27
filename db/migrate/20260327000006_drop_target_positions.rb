class DropTargetPositions < ActiveRecord::Migration[7.2]
  def up
    drop_table :target_positions
  end
  
  def down
    create_table :target_positions do |t|
      t.references :training_example, null: false, foreign_key: true
      t.text :description_text_de
      t.text :description_text_en
      t.text :description_text_fr
      t.text :description_text_nl
      t.jsonb :ball_measurements
      t.timestamps
    end
    
    add_index :target_positions, :training_example_id, unique: true
  end
end
