class RemoveRegionIdsColumns < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    # Remove old region_ids array columns from all tables
    models_with_region_ids = [
      :clubs, :club_locations, :games, :game_participations, :leagues, 
      :league_teams, :locations, :parties, :party_games, :players, 
      :regions, :season_participations, :seedings, :tables, :tournaments,
      :game_plans
    ]

    models_with_region_ids.each do |table|
      if column_exists?(table, :region_ids)
        remove_column table, :region_ids
      end
    end
  end
end 