class CreateTableMonitors < ActiveRecord::Migration
  def change
    create_table :table_monitors do |t|
      t.integer :tournament_monitor_id
      t.string :state
      t.string :name
      t.integer :game_id
      t.integer :next_game_id
      t.text :data
      t.integer :ipaddress
    end
  end
end
