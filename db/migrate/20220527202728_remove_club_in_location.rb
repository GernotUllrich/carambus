class RemoveClubInLocation < ActiveRecord::Migration[6.1]
  def change
    remove_index :locations, ["club_id"], name: "index_locations_on_club_id"
    remove_column :locations, :club_id
  end
end
