json.extract! tournament, :id, :title, :discipline_id, :modus, :age_restriction, :date, :accredation_end, :location, :hosting_club_id, :created_at, :updated_at
json.url tournament_url(tournament, format: :json)
