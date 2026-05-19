# frozen_string_literal: true

# Plan 14-G.14: Service-Account-Anlage für Regional→API-Sync
#
# Jede Region bekommt einen technischen User (z.B. nbv-syncer@carambus.de),
# der von ihrem Regional-Server (carambus_nbv) per POST /login zu einem
# Bearer-JWT (D-14-G7 Long-Lived 90 Tage) authentifiziert wird.
# Der JWT wird dann für PATCH /api/tournament_ccs/:id/registration_list_link
# verwendet (siehe Api::TournamentCcsController).
namespace :service_accounts do
  desc "Create or rotate regional sync service-account user. Usage: rake service_accounts:create[NBV]"
  task :create, [:region_shortname] => :environment do |_, args|
    shortname = args[:region_shortname].to_s.upcase
    if shortname.blank?
      puts "Usage: rake service_accounts:create[REGION_SHORTNAME]"
      puts "Example: rake service_accounts:create[NBV]"
      exit 1
    end

    email = "#{shortname.downcase}-syncer@carambus.de"
    password = SecureRandom.urlsafe_base64(32)

    user = User.find_or_initialize_by(email: email)
    if user.new_record?
      user.password = password
      user.password_confirmation = password
      user.role = :player
      user.save!
      puts "✓ Created service-account: #{email}"
      puts ""
      puts "One-time password (store securely on regional server in Rails-Credentials):"
      puts "  #{password}"
      puts ""
      puts "Next steps (on regional server):"
      puts "  1. EDITOR='code --wait' bin/rails credentials:edit --environment development"
      puts "  2. Add: api_syncer_email: #{email}"
      puts "  3. Add: api_syncer_password: #{password}"
      puts "  4. Run rake task to fetch JWT and store as api_jwt_token (TBD in Task 4)"
    else
      puts "Service-account exists: #{email}"
      puts ""
      puts "To rotate password (revokes all existing JWTs via JTIMatcher):"
      puts "  user = User.find_by(email: '#{email}')"
      puts "  user.update!(password: SecureRandom.urlsafe_base64(32))"
      puts "  user.update_column(:jti, SecureRandom.uuid)  # force-logout (D-13-06.2-C)"
    end
  end

  # Plan 15-02: External-Tournament-Bridge — Per-Region Service-Account
  # für externe Turnier-Apps (z.B. 3BandMannschaftsTurnier-App in /Users/gullrich/2BandTurnier).
  # Wird zur devise-jwt-Auth gegen GET /api/external_tournament/* Endpoints genutzt.
  # D-15-01-A: Service-Account-Pattern analog G.14 (nbv-syncer).
  desc "Create or rotate 2band-bridge service-account for External-Tournament-Bridge. Usage: rake service_accounts:create_2band[NBV]"
  task :create_2band, [:region_shortname] => :environment do |_, args|
    shortname = args[:region_shortname].to_s.upcase
    if shortname.blank?
      puts "Usage: rake service_accounts:create_2band[REGION_SHORTNAME]"
      puts "Example: rake service_accounts:create_2band[NBV]"
      exit 1
    end

    email = "2band-#{shortname.downcase}-bridge@carambus.de"
    password = SecureRandom.urlsafe_base64(32)

    user = User.find_or_initialize_by(email: email)
    if user.new_record?
      user.password = password
      user.password_confirmation = password
      user.role = :player
      user.save!
      puts "✓ Created 2band-bridge service-account: #{email}"
      puts ""
      puts "One-time password (store in 3BandMannschaftsTurnier-App configuration):"
      puts "  #{password}"
      puts ""
      puts "Next steps (in 3BandMannschaftsTurnier-App):"
      puts "  1. POST https://#{shortname.downcase}.carambus.de/login"
      puts "     Headers: Content-Type: application/json"
      puts "     Body:    {\"user\":{\"email\":\"#{email}\",\"password\":\"<password>\"}}"
      puts "  2. Capture Authorization: Bearer ... header from response"
      puts "  3. Use this JWT in 'Authorization: Bearer ...' header for all"
      puts "     GET /api/external_tournament/* calls (Long-Lived 90d via D-14-G7)."
    else
      puts "2band-bridge service-account exists: #{email}"
      puts ""
      puts "To rotate password (revokes existing JWTs via JTIMatcher D-13-06.2-C):"
      puts "  user = User.find_by(email: '#{email}')"
      puts "  user.update!(password: SecureRandom.urlsafe_base64(32))"
      puts "  user.update_column(:jti, SecureRandom.uuid)"
    end
  end
end
