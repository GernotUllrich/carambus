class AddInningsGoalToTournamentMonitors < ActiveRecord::Migration[5.2]
  def change
    add_column :table_monitors, :innings_goal, :integer
    add_column :tournament_monitors, :innings_goal, :integer
    add_column :table_monitors, :balls_goal, :integer
    add_column :tournament_monitors, :balls_goal, :integer
  end
end
