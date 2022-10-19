class AddPublicCcUrlBaseToRegions < ActiveRecord::Migration[6.1]
  def change
    add_column :regions, :public_cc_url_base, :string
  end
end
