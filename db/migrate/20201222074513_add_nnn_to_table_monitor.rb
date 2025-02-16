class AddNnnToTableMonitor < ActiveRecord::Migration[6.0]
  def change
    add_column :table_monitors, :nnn, :integer
  end
end
