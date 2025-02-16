class AddNrwNrToPlayers < ActiveRecord::Migration[7.0]
  def change
    add_column :players, :nrw_nr, :integer
  end
end
