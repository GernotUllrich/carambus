class CreateScrapingLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :scraping_logs do |t|
      t.string :operation, null: false
      t.string :context
      t.float :duration
      t.integer :created_count, default: 0
      t.integer :updated_count, default: 0
      t.integer :deleted_count, default: 0
      t.integer :error_count, default: 0
      t.text :errors_json
      t.datetime :executed_at, null: false

      t.timestamps
    end
    
    add_index :scraping_logs, :operation
    add_index :scraping_logs, :executed_at
    add_index :scraping_logs, [:operation, :executed_at]
  end
end
