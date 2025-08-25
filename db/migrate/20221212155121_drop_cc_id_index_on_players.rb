class DropCcIdIndexOnPlayers < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_index :players, :cc_id
    end
  end
end
