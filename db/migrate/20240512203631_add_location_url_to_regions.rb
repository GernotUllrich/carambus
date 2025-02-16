class AddLocationUrlToRegions < ActiveRecord::Migration[7.1]
  def change
    add_column :regions, :location_url, :string
  end
end
