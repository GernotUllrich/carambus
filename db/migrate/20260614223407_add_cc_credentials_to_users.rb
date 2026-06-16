class AddCcCredentialsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :cc_username, :string
    add_column :users, :cc_password, :string
  end
end
