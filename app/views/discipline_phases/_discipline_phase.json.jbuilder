json.extract! discipline_phase, :id, :name, :discipline_id, :parent_discipline_id, :position, :data, :created_at,
              :updated_at
json.url discipline_phase_url(discipline_phase, format: :json)
