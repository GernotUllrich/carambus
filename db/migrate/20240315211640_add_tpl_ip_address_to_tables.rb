class AddTplIpAddressToTables < ActiveRecord::Migration[7.0]
  def change
    add_column :tables, :tpl_ip_address, :integer
  end
end
