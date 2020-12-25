class AddStartAndEndTimesForCurrentTimerInTableMonitors < ActiveRecord::Migration[6.0]
  def change
    add_column :table_monitors, :timer_start_at, :datetime
    add_column :table_monitors, :timer_finish_at, :datetime
  end
end
