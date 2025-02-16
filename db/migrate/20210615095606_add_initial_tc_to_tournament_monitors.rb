class AddInitialTcToTournamentMonitors < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_monitors, :initial_tc, :integer
  end
end
