class AddLastGameToTableMonitor < ActiveRecord::Migration[7.0]
  def change
    add_column :table_monitors, :last_game_id, :integer
  end
end
