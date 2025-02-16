class AddIndexPlayerTournOnSeedings < ActiveRecord::Migration[6.1]
  def change
    add_index :seedings, [:player_id, :tournament_id], unique: true
  end
end
