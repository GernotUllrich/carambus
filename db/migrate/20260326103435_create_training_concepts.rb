class CreateTrainingConcepts < ActiveRecord::Migration[7.2]
  def change
    create_table :training_concepts do |t|
      t.string :title, null: false
      t.text :short_description
      t.text :full_description
      t.string :source_language, null: false, default: 'de'
      t.jsonb :translations, default: {}

      t.timestamps
    end
    
    add_index :training_concepts, :source_language
    add_index :training_concepts, :translations, using: :gin
  end
end
