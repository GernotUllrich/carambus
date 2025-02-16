class AddSomeIndexes < ActiveRecord::Migration[6.0]
  def change
    disable_ddl_transaction

    add_index :clubs, :ba_id, unique: true
    add_index :disciplines, ["name", "table_kind_id"], unique: true
    add_index :games, ["template_game_id", "tournament_id"], unique: true
    add_index :innings, ["game_id", "sequence_number"], unique: true
    add_index :locations, ["club_id"]

    add_foreign_key :settings, :regions
    add_foreign_key :settings, :clubs
    add_foreign_key :settings, :tournaments
    add_foreign_key :table_monitors, :tournament_monitors
    add_foreign_key :table_monitors, :games
    add_foreign_key :tables, :locations
    add_foreign_key :tables, :table_kinds
    add_foreign_key :tournament_monitors, :tournaments
    add_foreign_key :users, :players
  end
end
