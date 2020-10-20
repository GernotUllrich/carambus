json.extract! table_monitor, :id, :state, :name, :game_id, :next_game_id, :data, :created_at, :updated_at
json.url table_monitor_url(table_monitor, format: :json)
