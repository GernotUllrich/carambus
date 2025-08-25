class RemoveRegionIdFromLocations < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_column :locations, :region_id
    end
  end
end
