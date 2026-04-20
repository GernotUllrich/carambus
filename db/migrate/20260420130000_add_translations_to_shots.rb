class AddTranslationsToShots < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :shots, :source_language, :string, default: 'de', null: false
    add_column :shots, :translations, :jsonb, default: {}
    add_index :shots, :source_language, algorithm: :concurrently
    add_index :shots, :translations, using: :gin, algorithm: :concurrently
  end
end
