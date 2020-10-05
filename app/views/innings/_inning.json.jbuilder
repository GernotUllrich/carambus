json.extract! inning, :id, :game_id, :sequence_number, :player_a_count, :player_b_count, :player_c_count, :player_d_count, :remarks, :created_at, :updated_at
json.url inning_url(inning, format: :json)
