class RemoveRedundantFieldsFromGames < ActiveRecord::Migration
  def change
    remove_column :games, :player1_id
    remove_column :games, :player2_id
    remove_column :games, :player3_id
    remove_column :games, :player4_id
  end
end
