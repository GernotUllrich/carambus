# Creates a dummy scoreboard user for public scoreboard access without authentication
# Runs after Rails initialization to ensure User model is loaded. This is idempotent -
# will only create the user if it doesn't already exist in the database.
# Note: In production, consider using db/seeds.rb or migrations instead for critical setup.

Rails.application.config.after_initialize do
  unless Rails.env.test?
    begin
      # Skip if database doesn't exist or tables aren't created yet
      next unless ActiveRecord::Base.connection.data_source_exists?('users')
      
      User.find_or_create_by!(email: "scoreboard@carambus.de") do |user|
        user.password = "scoreboard123"
        user.password_confirmation = "scoreboard123"
        user.username = "scoreboard"
        user.first_name = "Scoreboard"
        user.last_name = "Display"
        user.role = :player
        user.confirmed_at = Time.current
        user.skip_confirmation!
        puts "[Initializer] ✅ Created scoreboard user"
      end
    rescue ActiveRecord::NoDatabaseError
      # Database doesn't exist yet - silently skip
    rescue ActiveRecord::RecordInvalid => e
      puts "[Initializer] ℹ️  Scoreboard user already exists: #{e.message}"
    rescue => e
      # Silently skip other errors during initialization (db might not be ready)
      # This is expected during rake tasks like db:create, db:migrate, etc.
    end
  end
end
