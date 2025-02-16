# frozen_string_literal: true

# type was integer ?!
class ChangeTypeInTableMonitor < ActiveRecord::Migration[7.0]
  def change
    change_column :table_monitors, :tournament_monitor_type, :string
  end
end
