class RemoveRedundantWinnerBreaksInTournaments < ActiveRecord::Migration[7.0]
  def change
    remove_column :tournaments, :winner_breaks
  end
end
