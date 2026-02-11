class CreateScoreboardMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :scoreboard_messages do |t|
      t.integer :table_monitor_id     # If nil, broadcast to all tables in location
      t.integer :location_id, null: false
      t.text :message, null: false
      t.datetime :acknowledged_at     # When acknowledged (on any table)
      t.datetime :expires_at          # Auto-dismiss after 30 minutes
      t.integer :sender_id, null: false

      t.timestamps
    end
    add_index :scoreboard_messages, :table_monitor_id
    add_index :scoreboard_messages, :location_id
    add_index :scoreboard_messages, :sender_id
    add_index :scoreboard_messages, :acknowledged_at
    add_index :scoreboard_messages, :expires_at
  end
end
