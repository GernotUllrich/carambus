class AddRegionIdToVersions < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    add_column :versions, :region_id, :bigint
    add_index :versions, :region_id, algorithm: :concurrently
  end
end
