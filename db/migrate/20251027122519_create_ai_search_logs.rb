class CreateAiSearchLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_search_logs do |t|
      t.text :query
      t.string :entity
      t.text :filters
      t.integer :confidence
      t.text :explanation
      t.boolean :success
      t.text :error_message
      t.integer :user_id
      t.json :raw_response
      t.string :locale

      t.timestamps
    end
    
    add_index :ai_search_logs, :user_id
    add_index :ai_search_logs, :created_at
    add_index :ai_search_logs, :success
  end
end
