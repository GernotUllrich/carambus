class DropInternationalTables < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def up
    # Remove foreign key constraint from games first
    safety_assured { remove_column :games, :international_tournament_id, if_exists: true }
    
    # Drop tables with CASCADE - we'll start fresh with Tournament/Seeding/Game
    safety_assured do
      execute "DROP TABLE IF EXISTS international_participations CASCADE"
      execute "DROP TABLE IF EXISTS international_results CASCADE"
      execute "DROP TABLE IF EXISTS international_videos CASCADE"
      execute "DROP TABLE IF EXISTS international_tournaments CASCADE"
    end
    # Keep international_sources - we need that for data source tracking
  end
  
  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot recreate old international tables - use fresh schema instead"
  end
end
