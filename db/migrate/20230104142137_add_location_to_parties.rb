class AddLocationToParties < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :location_id, :integer
  end
end
