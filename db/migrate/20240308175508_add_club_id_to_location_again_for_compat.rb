class AddClubIdToLocationAgainForCompat < ActiveRecord::Migration[7.0]
  def change
    add_column :locations, :club_id, :integer
  end
end
