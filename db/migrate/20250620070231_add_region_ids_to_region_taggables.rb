class AddRegionIdsToRegionTaggables < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    unless column_exists?(:clubs, :region_ids)
      add_column :clubs, :region_ids, :integer, array: true, default: []
      add_index :clubs, :region_ids, using: 'gin', algorithm: :concurrently
    end
    unless column_exists?(:club_locations, :region_ids)
      add_column :club_locations, :region_ids, :integer, array: true, default: []
      add_index :club_locations, :region_ids, using: 'gin', algorithm: :concurrently
    end
    unless column_exists?(:games, :region_ids)
      add_column :games, :region_ids, :integer, array: true, default: []
      add_index :games, :region_ids, using: 'gin', algorithm: :concurrently
    end
    unless column_exists?(:game_participations, :region_ids)
      add_column :game_participations, :region_ids, :integer, array: true, default: []
      add_index :game_participations, :region_ids, using: 'gin', algorithm: :concurrently
    end
    unless column_exists?(:leagues, :region_ids)
      add_column :leagues, :region_ids, :integer, array: true, default: []
      add_index :leagues, :region_ids, using: 'gin', algorithm: :concurrently
    end
    unless column_exists?(:league_teams, :region_ids)
      add_column :league_teams, :region_ids, :integer, array: true, default: []
      add_index :league_teams, :region_ids, using: 'gin', algorithm: :concurrently
    end
    unless column_exists?(:locations, :region_ids)
      add_column :locations, :region_ids, :integer, array: true, default: []
      add_index :locations, :region_ids, using: 'gin', algorithm: :concurrently
    end
    unless column_exists?(:parties, :region_ids)
      add_column :parties, :region_ids, :integer, array: true, default: []
      add_index :parties, :region_ids, using: 'gin', algorithm: :concurrently
    end
    unless column_exists?(:party_games, :region_ids)
      add_column :party_games, :region_ids, :integer, array: true, default: []
      add_index :party_games, :region_ids, using: 'gin', algorithm: :concurrently
    end
    unless column_exists?(:players, :region_ids)
      add_column :players, :region_ids, :integer, array: true, default: []
      add_index :players, :region_ids, using: 'gin', algorithm: :concurrently
    end
    unless column_exists?(:regions, :region_ids)
      add_column :regions, :region_ids, :integer, array: true, default: []
      add_index :regions, :region_ids, using: 'gin', algorithm: :concurrently
    end
    unless column_exists?(:season_participations, :region_ids)
      add_column :season_participations, :region_ids, :integer, array: true, default: []
      add_index :season_participations, :region_ids, using: 'gin', algorithm: :concurrently
    end
    unless column_exists?(:seedings, :region_ids)
      add_column :seedings, :region_ids, :integer, array: true, default: []
      add_index :seedings, :region_ids, using: 'gin', algorithm: :concurrently
    end
    unless column_exists?(:tables, :region_ids)
      add_column :tables, :region_ids, :integer, array: true, default: []
      add_index :tables, :region_ids, using: 'gin', algorithm: :concurrently
    end
    unless column_exists?(:tournaments, :region_ids)
      add_column :tournaments, :region_ids, :integer, array: true, default: []
      add_index :tournaments, :region_ids, using: 'gin', algorithm: :concurrently
    end
  end
end
