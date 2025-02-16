class RemoveLocationUrlInRegions < ActiveRecord::Migration[7.1]
  def change
    safety_assured { remove_column :regions, :location_url }
  end
end
