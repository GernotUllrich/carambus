class AddPinToPlayers < ActiveRecord::Migration[7.0]
  def change
    add_column :players, :pin4, :string
  end
end
