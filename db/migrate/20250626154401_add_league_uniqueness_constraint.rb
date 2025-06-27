class AddLeagueUniquenessConstraint < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    # Primary constraint: CC IDs are the most important identifiers from scraping
    # This ensures leagues with different cc_id2 (Staffel A, B, etc.) are treated as separate
    add_index :leagues, [:cc_id, :cc_id2, :organizer_id, :organizer_type], 
              unique: true, 
              name: 'index_leagues_on_cc_ids_organizer_unique',
              where: "cc_id IS NOT NULL AND organizer_type = 'Region'",
              algorithm: :concurrently
    
    # Note: Secondary constraint removed to avoid conflicts with legacy Billard-Area data
    # New scraping will always have cc_id values, making the secondary constraint unnecessary
  end
end
