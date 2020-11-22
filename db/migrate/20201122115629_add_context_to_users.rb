class AddContextToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :permissions, :text
  end
end
