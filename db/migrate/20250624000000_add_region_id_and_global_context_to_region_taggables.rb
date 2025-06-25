class AddRegionIdAndGlobalContextToRegionTaggables < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    # Add region_id and global_context to all models that include RegionTaggable
    models_with_region_taggable = [
      :clubs, :club_locations, :games, :game_participations, :leagues,
      :league_teams, :locations, :parties, :party_games, :players,
      :regions, :season_participations, :seedings, :tables, :tournaments, :versions, :game_plans, :player_rankings
    ]

    models_with_region_taggable.each do |table|
      unless column_exists?(table, :region_id)
        add_column table, :region_id, :integer
        add_index table, :region_id, algorithm: :concurrently
      end

      unless column_exists?(table, :global_context)
        add_column table, :global_context, :boolean, default: false
        add_index table, :global_context, algorithm: :concurrently
      end
    end

    # Add foreign key constraints
    models_with_region_taggable.each do |table|
      add_foreign_key table, :regions, validate: false
    end
  end
end
