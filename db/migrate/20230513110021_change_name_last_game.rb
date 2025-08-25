class ChangeNameLastGame < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
    rename_column :table_monitors, :last_game_id, :prev_game_id
    end
    add_column :table_monitors, :prev_data, :text
    add_column :table_monitors, :prev_tournament_monitor_id, :integer
    add_column :table_monitors, :prev_tournament_monitor_type, :string
  end
end
