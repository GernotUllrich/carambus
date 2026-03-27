class CreateShots < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    create_table :shots do |t|
      t.references :training_example, null: false, foreign_key: true
      t.string :shot_type, null: false # 'ideal', 'alternative', 'error'
      t.integer :sequence_number, null: false
      
      # Translatable text fields (de, en, fr, nl)
      t.text :title_de
      t.text :title_en
      t.text :title_fr
      t.text :title_nl
      
      t.text :notes_de
      t.text :notes_en
      t.text :notes_fr
      t.text :notes_nl
      
      t.text :end_position_description_de
      t.text :end_position_description_en
      t.text :end_position_description_fr
      t.text :end_position_description_nl
      
      t.text :shot_description_de
      t.text :shot_description_en
      t.text :shot_description_fr
      t.text :shot_description_nl
      
      # Structured data (non-translatable)
      t.string :end_position_type # 'exact', 'area', 'concept', 'named_area'
      t.jsonb :end_position_data, default: {}
      t.jsonb :shot_parameters, default: {}
      
      t.datetime :translations_synced_at
      t.timestamps
    end
    
    add_index :shots, :shot_type, algorithm: :concurrently
    add_index :shots, [:training_example_id, :sequence_number], unique: true, algorithm: :concurrently
  end
end
