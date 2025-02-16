class RemoveRegionIdFromLocations < ActiveRecord::Migration[7.0]
  def change
    remove_column :locations, :region_id
  end
end
