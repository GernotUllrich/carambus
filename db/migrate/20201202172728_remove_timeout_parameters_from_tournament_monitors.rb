class RemoveTimeoutParametersFromTournamentMonitors < ActiveRecord::Migration[6.0]
  def change
    safety_assured { remove_column :tournament_monitors, :time_out_stoke_preparation_sec }
    safety_assured { remove_column :tournament_monitors, :time_out_warm_up_first_min }
    safety_assured { remove_column :tournament_monitors, :time_out_warm_up_follow_up_min }
  end
end
