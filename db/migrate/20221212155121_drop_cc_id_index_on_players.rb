class DropCcIdIndexOnPlayers < ActiveRecord::Migration[7.0]
  def change
    remove_index :players, ["cc_id"], unique: true
  end
end
