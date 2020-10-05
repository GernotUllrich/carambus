class AddIndexesOnForeignKeys < ActiveRecord::Migration
  def change
    add_index :clubs, [:ba_id], name:"index_clubs_on_foreign_keys", unique: true, using: :btree
    add_index :countries, [:code], name:"index_countries_on_code", unique: true
    add_index :disciplines, [:name, :table_kind_id], name:"index_disciplines_on_foreign_keys", unique: true
    add_index :disciplines, [:short_name], name:"index_disciplines_on_shortname", unique: true
    add_index :game_participations, [:game_id, :player_id, :role], name:"index_game_participations_on_foreign_keys", unique: true
    add_index :games, [:template_game_id, :tournament_id], name:"index_games_on_foreign_keys", unique: true
    add_index :innings, [:game_id, :sequence_number], name:"index_innings_on_foreign_keys", unique: true
    add_index :locations, [:club_id], name:"index_locations_on_foreign_keys"
    add_index :player_count_templates, [:tournament_template_id, :players, :template_id], name:"index_player_count_templates_on_foreign_keys", unique: true
    add_index :players, [:ba_id], name:"index_players_on_ba_id", unique: true
    add_index :players, [:club_id], name:"index_players_on_club_id"
    add_index :regions, [:shortname], name:"index_regions_on_shortname", unique: true
    add_index :regions, [:country_id], name:"index_regions_on_country_id"
    add_index :season_participations, [:player_id, :club_id, :season_id], name:"index_season_participations_on_foreign_keys", unique: true, using: :btree
    add_index :seasons, [:ba_id], name:"index_seasons_on_ba_id", unique: true
    add_index :seasons, [:name], name:"index_seasons_on_name", unique: true
    add_index :seedings, [:player_id, :tournament_id], name:"index_seedings_on_foreign_keys", unique: true
    add_index :tournaments, [:title, :season_id, :region_id], name:"index_tournaments_on_foreign_keys"
    add_index :tournaments, [:ba_id], name:"index_tournaments_on_ba_id", unique: true
  end
end
