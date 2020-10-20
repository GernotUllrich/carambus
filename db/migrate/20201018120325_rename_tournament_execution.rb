class RenameTournamentMonitor < ActiveRecord::Migration
  def change
    rename_table :tournament_executions, :tournament_monitors
  end
end
