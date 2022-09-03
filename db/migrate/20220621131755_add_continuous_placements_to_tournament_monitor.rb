class AddContinuousPlacementsToTournamentMonitor < ActiveRecord::Migration[6.1]
  def change
    add_column :tournaments, :continuous_placements, :boolean, null: false, default: false
  end
end
