class AddTimerHaltAtToTableMonitors < ActiveRecord::Migration[6.0]
  def change
    add_column :table_monitors, :timer_halt_at, :datetime
  end
end
