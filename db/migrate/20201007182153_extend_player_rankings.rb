class ExtendPlayerRankings < ActiveRecord::Migration
  def change
    remove_column :player_rankings, :club_id
    add_column :player_rankings, :remarks, :text
  end
end
