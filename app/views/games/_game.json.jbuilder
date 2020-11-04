json.extract! game, :id, :template_game_id, :tournament_id, :roles, :data, :created_at, :updated_at, :seqno, :gname, :group_no, :table_no, :round_no, :started_at, :ended_at, :created_at, :updated_at
json.url game_url(game, format: :json)
