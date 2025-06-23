class AddRegionIdsToGamePlans < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  def change
    unless column_exists?(:game_plans, :region_ids)
      add_column :game_plans, :region_ids, :integer, array: true, default: []
      add_index :game_plans, :region_ids, using: 'gin', algorithm: :concurrently
    end
  end
end
