class AddClubCloudIdToClubs < ActiveRecord::Migration[6.0]
  def change
    add_column :clubs, :cc_id, :integer
  end
end
