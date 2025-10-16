namespace :scoreboard do
  desc "Update scoreboard user to use dark mode by default"
  task update_defaults: :environment do
    scoreboard_user = User.find_by(email: "scoreboard@carambus.de")
    
    if scoreboard_user
      puts "Found scoreboard user: #{scoreboard_user.email}"
      
      # Update preferences to ensure dark mode is set
      current_preferences = scoreboard_user.preferences || {}
      current_preferences["theme"] = "dark"
      scoreboard_user.update!(preferences: current_preferences)
      
      puts "Updated scoreboard user preferences:"
      puts "  Theme: #{scoreboard_user.preferences['theme']}"
      puts "  Dark mode enabled: #{scoreboard_user.prefers_dark_mode?}"
    else
      puts "Scoreboard user not found. Creating new user..."
      User.create!(
        email: "scoreboard@carambus.de",
        password: "password",
        preferences: {
          "theme" => "dark",
          "locale" => I18n.default_locale.to_s,
          "timezone" => "Berlin"
        }
      )
      puts "Created scoreboard user with dark mode enabled"
    end
  end
end


