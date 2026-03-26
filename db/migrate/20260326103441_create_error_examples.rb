class CreateErrorExamples < ActiveRecord::Migration[7.2]
  def change
    create_table :error_examples do |t|
      t.references :training_example, null: false, foreign_key: true
      t.string :title
      t.integer :sequence_number, null: false, default: 1
      t.text :stroke_parameters_text
      t.jsonb :stroke_parameters_data, default: {}
      t.text :end_position_description

      t.timestamps
    end
    
    add_index :error_examples, [:training_example_id, :sequence_number], 
              unique: true, 
              name: 'index_error_examples_on_example_and_sequence'
  end
end
