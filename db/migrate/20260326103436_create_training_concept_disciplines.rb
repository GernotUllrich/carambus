class CreateTrainingConceptDisciplines < ActiveRecord::Migration[7.2]
  def change
    create_table :training_concept_disciplines do |t|
      t.references :training_concept, null: false, foreign_key: true
      t.references :discipline, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :training_concept_disciplines, 
              [:training_concept_id, :discipline_id], 
              unique: true, 
              name: 'index_training_concept_disciplines_unique'
  end
end
