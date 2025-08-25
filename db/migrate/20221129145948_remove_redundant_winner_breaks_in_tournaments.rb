class RemoveRedundantWinnerBreaksInTournaments < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_column :tournaments, :winner_breaks
    end
  end
end
