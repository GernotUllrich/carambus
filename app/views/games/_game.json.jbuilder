json.extract! game, :id, :template_game_id, :tournament_id, :roles, :remarks, :created_at, :updated_at
json.url game_url(game, format: :json)
