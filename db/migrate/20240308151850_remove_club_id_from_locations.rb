class RemoveClubIdFromLocations < ActiveRecord::Migration[7.0]
  def change
    safety_assured { remove_column :locations, :club_id }
  end
end
