class AddContinuousPlacementsToParty < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :continuous_placements, :boolean, default: false, null: false
  end
end
