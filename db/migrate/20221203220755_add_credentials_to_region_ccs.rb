class AddCredentialsToRegionCcs < ActiveRecord::Migration[7.0]
  def change
    add_column :region_ccs, :username, :string
    add_column :region_ccs, :userpw, :string
  end
end
