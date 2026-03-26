class RestructureTranslationsSystem < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    # TrainingConcept - add DE/EN columns for all text fields
    add_column :training_concepts, :title_de, :string
    add_column :training_concepts, :title_en, :string
    add_column :training_concepts, :short_description_de, :text
    add_column :training_concepts, :short_description_en, :text
    add_column :training_concepts, :full_description_de, :text
    add_column :training_concepts, :full_description_en, :text
    add_column :training_concepts, :translations_synced_at, :datetime
    
    # TrainingExample
    add_column :training_examples, :title_de, :string
    add_column :training_examples, :title_en, :string
    add_column :training_examples, :ideal_stroke_parameters_text_de, :text
    add_column :training_examples, :ideal_stroke_parameters_text_en, :text
    add_column :training_examples, :translations_synced_at, :datetime
    
    # StartingPosition
    add_column :starting_positions, :description_text_de, :text
    add_column :starting_positions, :description_text_en, :text
    add_column :starting_positions, :translations_synced_at, :datetime
    
    # TargetPosition
    add_column :target_positions, :description_text_de, :text
    add_column :target_positions, :description_text_en, :text
    add_column :target_positions, :translations_synced_at, :datetime
    
    # ErrorExample
    add_column :error_examples, :title_de, :string
    add_column :error_examples, :title_en, :string
    add_column :error_examples, :stroke_parameters_text_de, :text
    add_column :error_examples, :stroke_parameters_text_en, :text
    add_column :error_examples, :end_position_description_de, :text
    add_column :error_examples, :end_position_description_en, :text
    add_column :error_examples, :translations_synced_at, :datetime
    
    # Tag
    add_column :tags, :name_de, :string
    add_column :tags, :name_en, :string
    add_column :tags, :description_de, :text
    add_column :tags, :description_en, :text
    add_column :tags, :translations_synced_at, :datetime
    
    # Add indexes for text search on translated columns
    add_index :training_concepts, :title_de, algorithm: :concurrently
    add_index :training_concepts, :title_en, algorithm: :concurrently
    add_index :tags, :name_de, algorithm: :concurrently
    add_index :tags, :name_en, algorithm: :concurrently
  end
end
