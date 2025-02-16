class AddDeviseParametersToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, "username", :string
    add_column :users, "firstname", :string
    add_column :users, "lastname", :string
    add_column :users, "player_id", :integer
    add_column :users, "sign_in_count", :integer
    add_column :users, "current_sign_in_at", :datetime
    add_column :users, "last_sign_in_at", :datetime
    add_column :users, "current_sign_in_ip", :inet
    add_column :users, "last_sign_in_ip", :inet
  end
end
