class CreatePlayerRankings < ActiveRecord::Migration[6.0]
  def change
    create_table :player_rankings do |t|
      t.integer :player_id
      t.integer :region_id
      t.integer :season_id
      t.string :org_level
      t.integer :discipline_id
      t.integer :innings
      t.string :status
      t.integer :points
      t.float :gd
      t.integer :hs
      t.float :bed
      t.float :btg
      t.integer :player_class_id
      t.integer :p_player_class_id
      t.integer :pp_player_class_id
      t.float :p_gd
      t.float :pp_gd
      t.integer :tournament_player_class_id
      t.integer :rank
      t.text :remarks
      t.integer :g
      t.integer :v
      t.float :quote
      t.integer :sp_g
      t.integer :sp_v
      t.float :sp_quote
      t.integer :balls
      t.integer :sets
      t.text :t_ids

      t.timestamps
    end
  end
end
