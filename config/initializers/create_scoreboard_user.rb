# Creates a dummy scoreboard user for public scoreboard access without authentication
# Runs after Rails initialization to ensure User model is loaded. This is idempotent -
# will only create the user if it doesn't already exist in the database.
# Note: In production, consider using db/seeds.rb or migrations instead for critical setup.

Rails.application.config.after_initialize do
  # begin
  #   User.find_or_create_by!(email: "scoreboard@carambus.de") do |user|
  #     user.password = "password"
  #     # Add any other default attributes
  #     puts "[Initializer] Created scoreboard user"
  #   end
  # rescue ActiveRecord::RecordInvalid => e
  #   puts "[Initializer] Scoreboard user already exists: #{e.message}"
  # rescue => e
  #   puts "[Initializer] Error creating scoreboard user: #{e.message}"
  # end
end
