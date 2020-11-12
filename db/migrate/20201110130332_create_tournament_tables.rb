class CreateTournamentTables < ActiveRecord::Migration[5.2]
  def change
    create_table :tournament_tables do |t|
      t.integer :tournament_id
      t.integer :table_id
      t.integer :table_no

      t.timestamps

      t.index [:table_no, :tournament_id, :table_id], name: "index_tournament_tables", unique: true
    end
  end
end
