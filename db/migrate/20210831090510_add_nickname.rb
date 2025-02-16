class AddNickname < ActiveRecord::Migration[6.0]
  def change
    add_column :players, :nickname, :string
  end
end
