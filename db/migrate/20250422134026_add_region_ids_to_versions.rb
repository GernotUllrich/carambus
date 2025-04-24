class AddRegionIdsToVersions < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    add_column :versions, :region_ids, :integer, array: true, default: []
    add_index :versions, :region_ids, using: 'gin', algorithm: :concurrently
  end
end
