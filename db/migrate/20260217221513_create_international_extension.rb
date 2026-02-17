# frozen_string_literal: true

# Migration to add international carom billiards support
# This extends Carambus to track international tournaments, videos, and results
# while maintaining compatibility with existing ClubCloud-based German data
class CreateInternationalExtension < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    # International data sources (YouTube, Kozoom, UMB, CEB, etc.)
    create_table :international_sources do |t|
      t.string :name, null: false
      t.string :source_type, null: false # youtube, kozoom, fivesix, umb, ceb, manual
      t.string :base_url
      t.text :api_credentials # Will be encrypted in model
      t.boolean :active, default: true
      t.jsonb :metadata, default: {}
      t.datetime :last_scraped_at
      t.timestamps

      t.index :source_type
      t.index :active
      t.index [:name, :source_type], unique: true
    end

    # International tournaments (World Cups, World Championships, etc.)
    create_table :international_tournaments do |t|
      t.references :discipline, null: false, foreign_key: true
      t.references :international_source, null: true, foreign_key: true
      
      t.string :name, null: false
      t.string :tournament_type # world_cup, world_championship, european_championship, national_championship, invitation
      t.date :start_date
      t.date :end_date
      t.string :location
      t.string :country
      t.string :organizer # UMB, CEB, etc.
      t.decimal :prize_money, precision: 12, scale: 2
      t.string :source_url
      t.string :external_id # ID from external source
      
      # Flexible JSON for future extensions
      # Can include: format, number_of_players, qualification_info, etc.
      t.jsonb :data, default: {}
      
      t.timestamps

      t.index [:start_date, :tournament_type]
      t.index :country
      t.index :organizer
      t.index [:external_id, :international_source_id], unique: true, name: 'index_intl_tournaments_on_external_id_and_source'
    end

    # International tournament results
    create_table :international_results do |t|
      t.references :international_tournament, null: false, foreign_key: true, index: true
      t.references :player, null: true, foreign_key: true, index: false # Will add index separately
      
      t.string :player_name # If player not yet in DB
      t.string :player_country
      t.integer :position # 1, 2, 3, etc.
      t.integer :points
      t.decimal :prize, precision: 10, scale: 2
      
      # Flexible JSON for statistics
      # Can include: games_played, wins, losses, average, high_run, innings, etc.
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    # Add indexes separately to avoid conflicts
    add_index :international_results, [:international_tournament_id, :position], name: 'index_intl_results_on_tournament_and_position' unless index_exists?(:international_results, [:international_tournament_id, :position], name: 'index_intl_results_on_tournament_and_position')
    add_index :international_results, :player_id, name: 'index_intl_results_on_player_id' unless index_exists?(:international_results, :player_id, name: 'index_intl_results_on_player_id')
    add_index :international_results, :player_name unless index_exists?(:international_results, :player_name)

    # Video archive for international content
    create_table :international_videos do |t|
      t.references :international_source, null: false, foreign_key: true, index: true
      t.references :international_tournament, null: true, foreign_key: true, index: false
      t.references :discipline, null: true, foreign_key: true, index: false
      
      # Video identifiers
      t.string :external_id, null: false # YouTube ID, Kozoom ID, etc.
      t.string :title
      t.text :description
      t.datetime :published_at
      t.integer :duration # in seconds
      t.string :language
      t.string :thumbnail_url
      
      # Video statistics (optional)
      t.integer :view_count
      t.integer :like_count
      
      # Processing flags
      t.boolean :metadata_extracted, default: false # AI processing done?
      t.datetime :metadata_extracted_at
      
      # Flexible JSON for extracted metadata
      # Can include: players[], event_name, round, location, commentary_language, etc.
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    # Add indexes separately
    add_index :international_videos, :external_id, unique: true unless index_exists?(:international_videos, :external_id, unique: true)
    add_index :international_videos, :published_at unless index_exists?(:international_videos, :published_at)
    add_index :international_videos, [:international_tournament_id, :published_at], name: 'index_intl_videos_on_tournament_and_published' unless index_exists?(:international_videos, [:international_tournament_id, :published_at], name: 'index_intl_videos_on_tournament_and_published')
    add_index :international_videos, :metadata_extracted unless index_exists?(:international_videos, :metadata_extracted)
    add_index :international_videos, :discipline_id unless index_exists?(:international_videos, :discipline_id)

    # Player participation in international tournaments
    # This links existing Player records to international tournaments
    create_table :international_participations do |t|
      t.references :player, null: false, foreign_key: true
      t.references :international_tournament, null: false, foreign_key: true
      t.references :international_result, null: true, foreign_key: true
      
      t.boolean :confirmed, default: false # Verified participation
      t.string :source # video, result_list, manual
      
      t.timestamps

      t.index [:player_id, :international_tournament_id], unique: true, name: 'index_intl_participations_on_player_and_tournament'
    end

    # Add international context flag to existing tables
    add_column :players, :international_player, :boolean, default: false
    add_index :players, :international_player, algorithm: :concurrently

    add_column :tournaments, :international_tournament_id, :bigint, null: true
    add_index :tournaments, :international_tournament_id, algorithm: :concurrently
    add_foreign_key :tournaments, :international_tournaments, column: :international_tournament_id, validate: false
  end
end
