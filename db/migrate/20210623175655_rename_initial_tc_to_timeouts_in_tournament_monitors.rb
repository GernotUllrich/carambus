class RenameInitialTcToTimeoutsInTournamentMonitors < ActiveRecord::Migration[6.0]
  def change
    rename_column :tournament_monitors, :initial_tc, :timeouts
    add_column :tournament_monitors, :timeout, :integer, default: 0, null: false
  end
end
