class AddGuestToPlayers < ActiveRecord::Migration[6.0]
  def change
    add_column :players, :guest, :boolean, null: false, default: false
  end
end
