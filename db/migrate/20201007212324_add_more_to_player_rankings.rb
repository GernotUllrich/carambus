class AddMoreToPlayerRankings < ActiveRecord::Migration
  def change
    add_column :player_rankings, :g, :integer
    add_column :player_rankings, :v, :integer
    add_column :player_rankings, :quote, :float
    add_column :player_rankings, :sp_g, :integer
    add_column :player_rankings, :sp_v, :integer
    add_column :player_rankings, :sp_quote, :float
    add_column :player_rankings, :balls, :integer
    add_column :player_rankings, :sets, :integer
    add_column :player_rankings, :t_ids, :text
  end
end


