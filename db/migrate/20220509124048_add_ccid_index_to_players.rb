class AddCcidIndexToPlayers < ActiveRecord::Migration[6.1]
  def change
    add_index :players, [:cc_id], unique: true
  end
end
