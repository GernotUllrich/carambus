class CreatePlayerRankings < ActiveRecord::Migration
  def change
    create_table :player_rankings do |t|
      t.integer :player_id
      t.integer :region_id
      t.integer :club_id
      t.integer :season_id
      t.string :org_level
      t.integer :discipline_id
      t.string :status
      t.integer :points
      t.integer :innings
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

      t.timestamps null: false
    end
  end
end
