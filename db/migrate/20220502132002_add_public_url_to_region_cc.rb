class AddPublicUrlToRegionCc < ActiveRecord::Migration[6.1]
  def change
    add_column :region_ccs, :public_url, :string
  end
end
