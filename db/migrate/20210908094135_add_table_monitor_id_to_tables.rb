class AddTableMonitorIdToTables < ActiveRecord::Migration[6.0]
  def change
    # TableMonitor.destroy_all
    add_column :tables, :table_monitor_id, :integer
    remove_column :table_monitors, :table_id, :integer
  end
end
