class AddTranslationsToTrainingModels < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    # TrainingExample
    add_column :training_examples, :source_language, :string, default: 'de', null: false
    add_column :training_examples, :translations, :jsonb, default: {}
    add_index :training_examples, :source_language, algorithm: :concurrently
    add_index :training_examples, :translations, using: :gin, algorithm: :concurrently
    
    # StartingPosition
    add_column :starting_positions, :source_language, :string, default: 'de', null: false
    add_column :starting_positions, :translations, :jsonb, default: {}
    add_index :starting_positions, :source_language, algorithm: :concurrently
    add_index :starting_positions, :translations, using: :gin, algorithm: :concurrently
    
    # TargetPosition
    add_column :target_positions, :source_language, :string, default: 'de', null: false
    add_column :target_positions, :translations, :jsonb, default: {}
    add_index :target_positions, :source_language, algorithm: :concurrently
    add_index :target_positions, :translations, using: :gin, algorithm: :concurrently
    
    # ErrorExample
    add_column :error_examples, :source_language, :string, default: 'de', null: false
    add_column :error_examples, :translations, :jsonb, default: {}
    add_index :error_examples, :source_language, algorithm: :concurrently
    add_index :error_examples, :translations, using: :gin, algorithm: :concurrently
    
    # Tag
    add_column :tags, :source_language, :string, default: 'de', null: false
    add_column :tags, :translations, :jsonb, default: {}
    add_index :tags, :source_language, algorithm: :concurrently
    add_index :tags, :translations, using: :gin, algorithm: :concurrently
  end
end
