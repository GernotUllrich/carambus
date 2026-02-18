class AddStiFieldsToTournaments < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    # Add type for STI
    add_column :tournaments, :type, :string unless column_exists?(:tournaments, :type)
    add_index :tournaments, :type, algorithm: :concurrently unless index_exists?(:tournaments, :type)
    
    # Add external_id
    add_column :tournaments, :external_id, :string unless column_exists?(:tournaments, :external_id)
    
    # Add international_source_id reference
    unless column_exists?(:tournaments, :international_source_id)
      add_reference :tournaments, :international_source, index: { algorithm: :concurrently }
    end
    
    # Add unique index for external_id + source
    unless index_exists?(:tournaments, [:external_id, :international_source_id], name: 'idx_tournaments_external_id_source')
      add_index :tournaments, [:external_id, :international_source_id], 
                unique: true, 
                where: "external_id IS NOT NULL AND international_source_id IS NOT NULL",
                name: 'idx_tournaments_external_id_source',
                algorithm: :concurrently
    end
  end
end
