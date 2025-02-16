json.extract! slot, :id, :dayofweek, :hourofday_start, :minuteofhour_start, :hourofday_end, :minuteofhour_end,
              :next_start, :next_end, :table_id, :recurring, :created_at, :updated_at
json.url slot_url(slot, format: :json)
