class AddRegionIdAndClubIdToLocations < ActiveRecord::Migration[6.1]
  def change
    add_column :locations, :club_id, :integer
    add_column :locations, :region_id, :integer
  end
end
