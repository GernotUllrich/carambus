class AddBaseUrlToRegionCc < ActiveRecord::Migration[6.1]
  def change
    add_column :region_ccs, :base_url, :string
  end
end
