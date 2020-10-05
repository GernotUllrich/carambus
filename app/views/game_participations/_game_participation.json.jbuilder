json.extract! game_participation, :id, :game_id, :player_id, :role, :created_at, :updated_at
json.url game_participation_url(game_participation, format: :json)
