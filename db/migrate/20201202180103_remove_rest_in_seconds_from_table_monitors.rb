class RemoveRestInSecondsFromTableMonitors < ActiveRecord::Migration[6.0]
  def change
    safety_assured { remove_column :table_monitors, :rest_in_seconds }
  end
end
