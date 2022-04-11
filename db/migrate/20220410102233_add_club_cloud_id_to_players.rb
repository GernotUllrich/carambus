class AddClubCloudIdToPlayers < ActiveRecord::Migration[6.0]
  def change
    add_column :players, :cc_id, :integer
  end
end
