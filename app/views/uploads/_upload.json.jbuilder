json.extract! upload, :id, :filename, :user_id, :position, :created_at, :updated_at
json.url upload_url(upload, format: :json)
