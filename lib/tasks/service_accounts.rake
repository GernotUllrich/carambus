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
  desc "Create or rotate carambus-app-bridge service-account for External-Tournament-Bridge. Usage: rake service_accounts:create_carambus_app[NBV]"
  task :create_carambus_app, [:region_shortname] => :environment do |_, args|
    shortname = args[:region_shortname].to_s.upcase
    if shortname.blank?
      puts "Usage: rake service_accounts:create_carambus_app[REGION_SHORTNAME]"
      puts "Example: rake service_accounts:create_carambus_app[NBV]"
      exit 1
    end

    email = "carambus-app-#{shortname.downcase}-bridge@carambus.de"
    password = SecureRandom.urlsafe_base64(32)

    user = User.find_or_initialize_by(email: email)
    if user.new_record?
      user.password = password
      user.password_confirmation = password
      user.role = :player
      # Plan 29-05: User ist :confirmable — ohne confirmed_at lehnt devise JEDEN Login
      # mit 401 ab, unabhaengig vom Passwort. Ein Service-Account hat kein Postfach,
      # das eine Bestaetigungsmail empfangen koennte.
      # ⚠️ `skip_confirmation!` NICHT verwenden: die Methode existiert (respond_to? == true),
      # laesst confirmed_at hier aber nachweislich nil (auf Dev gemessen, 2026-07-22).
      # Das Attribut wird deshalb explizit gesetzt.
      user.confirmed_at = Time.current
      user.save!
      puts "✓ Created carambus-app-bridge service-account: #{email}"
      puts ""
      puts "One-time password (store in 3BandMannschaftsTurnier-App configuration):"
      puts "  #{password}"
      puts ""
      puts "Next steps (in 3BandMannschaftsTurnier-App):"
      puts "  1. POST https://#{shortname.downcase}.carambus.de/login"
      puts "     Headers: Content-Type: application/json"
      puts "              Accept: application/json     <-- PFLICHT, sonst HTTP 422:"
      puts "              der SessionsController skippt CSRF nur bei request.format.json?,"
      puts "              und das Format kommt vom Accept-Header, nicht vom Content-Type."
      puts "     Body:    {\"user\":{\"email\":\"#{email}\",\"password\":\"<password>\"}}"
      puts "  2. Capture Authorization: Bearer ... header from response"
      puts "  3. Use this JWT in 'Authorization: Bearer ...' header for all"
      puts "     GET /api/external_tournament/* calls (Long-Lived 90d via D-14-G7)."
    elsif ENV["ROTATE"].present?
      # Plan 29-05: Rotation als TASK statt als Copy-Paste-Anleitung. Die alte Anleitung
      # liess `user.update!(password: SecureRandom...)` ausfuehren, ohne das Passwort
      # auszugeben — es war danach unwiederbringlich weg (live passiert am 2026-07-22).
      user.confirm if user.confirmed_at.nil?
      user.update!(password: password, password_confirmation: password)
      user.update_column(:jti, SecureRandom.uuid) # revoked alle bestehenden JWTs (D-13-06.2-C)

      puts "✓ Passwort rotiert: #{email}"
      puts "  confirmed_at: #{user.reload.confirmed_at.inspect}"
      puts "  Alle bisherigen JWTs sind ungueltig."
      puts ""
      puts "Neues Passwort (wird NUR JETZT angezeigt):"
      puts "  #{password}"
      puts ""
      puts "Eintragen in carambus_data/secrets.yml unter"
      puts "  shared.region_server.#{shortname.downcase}.password"
      puts "dann `rake scenario:generate_credentials[<szenario>,production]` + `scenario:push_credentials`."
      puts ""
      puts "(Ein fehlgeschlagener 'DeviseMailJob' im Log ist folgenlos — der Service-Account"
      puts " hat kein Postfach; das Passwort ist trotzdem gesetzt.)"
    else
      puts "carambus-app-bridge service-account exists: #{email}"
      puts "  confirmed_at: #{user.confirmed_at.inspect}#{"   ⚠️  UNBESTAETIGT — jeder Login endet mit 401" if user.confirmed_at.nil?}"
      puts ""
      puts "Passwort neu setzen und ausgeben (revoked bestehende JWTs, bestaetigt den Account):"
      puts "  ROTATE=1 rake \"service_accounts:create_carambus_app[#{shortname}]\""
      puts ""
      puts "⚠️  NICHT von Hand `user.update!(password: SecureRandom.urlsafe_base64(32))` —"
      puts "    das setzt ein Passwort, das nie ausgegeben wird und danach niemand kennt."
    end
  end
end
