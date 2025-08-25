# frozen_string_literal: true

# type was integer ?!
class ChangeTypeInTableMonitor < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_column :table_monitors, :tournament_monitor_type, :string
    end
  end
end
