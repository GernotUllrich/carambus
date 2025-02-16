class AddMonitorLinkToTableMonitor < ActiveRecord::Migration[7.0]
  def change
    add_column :table_monitors, :tournament_monitor_type, :integer
  end
end
