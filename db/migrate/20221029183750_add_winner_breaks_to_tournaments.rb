class AddWinnerBreaksToTournaments < ActiveRecord::Migration[6.1]
  def change
    add_column :tournaments, :winner_breaks, :boolean
  end
end
