json.extract! tournament_template, :id, :name, :discipline_id, :points, :innings, :created_at, :updated_at
json.url tournament_template_url(tournament_template, format: :json)
