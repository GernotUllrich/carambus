class CreateTrainingExamples < ActiveRecord::Migration[7.2]
  def change
    create_table :training_examples do |t|
      t.references :training_concept, null: false, foreign_key: true
      t.string :title
      t.integer :sequence_number, null: false, default: 1
      t.text :ideal_stroke_parameters_text
      t.jsonb :ideal_stroke_parameters_data, default: {}

      t.timestamps
    end
    
    add_index :training_examples, [:training_concept_id, :sequence_number], 
              unique: true, 
              name: 'index_training_examples_on_concept_and_sequence'
  end
end
