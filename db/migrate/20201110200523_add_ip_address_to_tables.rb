class AddIpAddressToTables < ActiveRecord::Migration[5.2]
  def change
    add_column :tables, :ip_address, :string
  end
end
