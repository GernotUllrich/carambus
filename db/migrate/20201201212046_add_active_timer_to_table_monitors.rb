class AddActiveTimerToTableMonitors < ActiveRecord::Migration[6.0]
  def change
    add_column :table_monitors, :active_timer, :string
    add_column :table_monitors, :rest_in_seconds, :integer
  end
end
