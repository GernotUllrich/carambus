class AddAllowOverflowToTournamentMonitor < ActiveRecord::Migration[6.0]
  def change
    add_column :tournament_monitors, :allow_overflow, :boolean
  end
end
