class AddSomeFieldsToGames < ActiveRecord::Migration
  def change
    add_column :games, :group_no, :integer
    add_column :games, :table_no, :integer
    add_column  :games, :round_no, :integer
    add_column :games, :started_at, :datetime
    add_column :games, :ended_at, :datetime
    add_column :games, :player1_id, :integer
    add_column :games, :player2_id, :integer
    add_column :games, :player3_id, :integer
    add_column :games, :player4_id, :integer
  end
end
