class DropErrorExamples < ActiveRecord::Migration[7.2]
  def up
    drop_table :error_examples
  end
  
  def down
    create_table :error_examples do |t|
      t.references :training_example, null: false, foreign_key: true
      t.integer :sequence_number, null: false
      t.text :title_de
      t.text :title_en
      t.text :title_fr
      t.text :title_nl
      t.text :stroke_parameters_text_de
      t.text :stroke_parameters_text_en
      t.text :stroke_parameters_text_fr
      t.text :stroke_parameters_text_nl
      t.text :end_position_description_de
      t.text :end_position_description_en
      t.text :end_position_description_fr
      t.text :end_position_description_nl
      t.jsonb :stroke_parameters_data
      t.timestamps
    end
    
    add_index :error_examples, [:training_example_id, :sequence_number], unique: true
  end
end
