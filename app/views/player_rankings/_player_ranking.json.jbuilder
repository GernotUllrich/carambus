json.extract! player_ranking, :id, :player_id, :region_id, :club_id, :season_id, :org_level, :discipline_id, :status, :points, :innings, :gd, :hs, :bed, :btg, :player_class_id, :p_player_class_id, :pp_player_class_id, :p_gd, :pp_gd, :tournament_player_class_id, :rank, :created_at, :updated_at
json.url player_ranking_url(player_ranking, format: :json)
