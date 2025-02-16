class AddCcIdAndDbuNrToLocations < ActiveRecord::Migration[7.0]
  def change
    add_column :locations, :cc_id, :integer
    add_column :locations, :dbu_nr, :integer
  end
end
