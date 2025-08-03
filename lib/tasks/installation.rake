# frozen_string_literal: true

namespace :carambus do
  namespace :installation do
    desc "Prüfe System-Voraussetzungen für Carambus-Installation"
    task check_prerequisites: :environment do
      puts "Prüfe System-Voraussetzungen..."
      
      # Prüfe Ruby-Version
      ruby_version = RUBY_VERSION
      required_version = "3.2.0"
      if Gem::Version.new(ruby_version) < Gem::Version.new(required_version)
        puts "❌ Ruby-Version #{ruby_version} ist zu alt. Mindestens #{required_version} erforderlich."
      else
        puts "✅ Ruby-Version #{ruby_version} ist kompatibel"
      end
      
      # Prüfe Rails-Version
      rails_version = Rails.version
      required_rails = "7.0.0"
      if Gem::Version.new(rails_version) < Gem::Version.new(required_rails)
        puts "❌ Rails-Version #{rails_version} ist zu alt. Mindestens #{required_rails} erforderlich."
      else
        puts "✅ Rails-Version #{rails_version} ist kompatibel"
      end
      
      # Prüfe PostgreSQL
      begin
        ActiveRecord::Base.connection.execute("SELECT 1")
        puts "✅ PostgreSQL-Verbindung erfolgreich"
      rescue => e
        puts "❌ PostgreSQL-Verbindung fehlgeschlagen: #{e.message}"
      end
      
      # Prüfe Redis
      begin
        Redis.new.ping
        puts "✅ Redis-Verbindung erfolgreich"
      rescue => e
        puts "❌ Redis-Verbindung fehlgeschlagen: #{e.message}"
      end
      
      # Prüfe verfügbaren Speicherplatz
      disk_usage = `df / | tail -1 | awk '{print $5}' | sed 's/%//'`.to_i
      if disk_usage > 90
        puts "❌ Speicherplatz kritisch: #{disk_usage}% belegt"
      else
        puts "✅ Speicherplatz ausreichend: #{disk_usage}% belegt"
      end
      
      puts "System-Prüfung abgeschlossen"
    end

    desc "Erstelle Standard-Lokalisierung für neue Installation"
    task setup_localization: :environment do
      puts "Erstelle Standard-Lokalisierung..."
      
      # Standard-Region erstellen (falls nicht vorhanden)
      region = Region.find_or_create_by(name: "Schleswig-Holstein") do |r|
        r.ba_id = 1
        r.cc_id = 1
        puts "Region erstellt: #{r.name}"
      end
      
      # Standard-Club erstellen (falls nicht vorhanden)
      club = Club.find_or_create_by(name: "Billard Club Wedel") do |c|
        c.region_id = region.id
        c.ba_id = 1
        c.cc_id = 1
        puts "Club erstellt: #{c.name}"
      end
      
      # Standard-Location erstellen (falls nicht vorhanden)
      location = Location.find_or_create_by(name: "BC Wedel") do |l|
        l.club_id = club.id
        l.region_id = region.id
        l.address = "Musterstraße 1, 22880 Wedel"
        l.phone = "+49 4103 123456"
        l.email = "info@bc-wedel.de"
        puts "Location erstellt: #{l.name}"
      end
      
      # Standard-Tische erstellen
      table_kinds = {
        "Karambol groß" => 1,
        "Karambol mittel" => 2,
        "Karambol klein" => 3,
        "Pool" => 4,
        "Snooker" => 5
      }
      
      table_kinds.each do |name, kind_id|
        TableKind.find_or_create_by(name: name) do |tk|
          tk.id = kind_id
          puts "Tisch-Art erstellt: #{tk.name}"
        end
      end
      
      # Standard-Tische für Location erstellen
      (1..8).each do |i|
        table = Table.find_or_create_by(name: "T#{i}", location_id: location.id) do |t|
          t.table_kind_id = 1  # Karambol groß
          t.position = i
          puts "Tisch erstellt: #{t.name}"
        end
      end
      
      # Standard-Benutzer erstellen
      admin_user = User.find_or_create_by(email: "admin@carambus.de") do |u|
        u.name = "Administrator"
        u.password = "admin123"
        u.password_confirmation = "admin123"
        u.admin = true
        u.confirmed_at = Time.current
        puts "Admin-Benutzer erstellt: #{u.name}"
      end
      
      scoreboard_user = User.find_or_create_by(email: "scoreboard@carambus.de") do |u|
        u.name = "Scoreboard"
        u.password = "scoreboard"
        u.password_confirmation = "scoreboard"
        u.admin = false
        u.confirmed_at = Time.current
        puts "Scoreboard-Benutzer erstellt: #{u.name}"
      end
      
      # Standard-Settings erstellen
      settings = {
        "carambus_api_url" => "https://api.carambus.de",
        "location_id" => location.id.to_s,
        "club_id" => club.id.to_s,
        "region_id" => region.id.to_s,
        "scoreboard_url" => "http://localhost:3000/locations/#{location.id}/scoreboard_reservations"
      }
      
      settings.each do |key, value|
        Setting.find_or_create_by(key: key) do |s|
          s.value = value
          puts "Setting erstellt: #{s.key} = #{s.value}"
        end
      end
      
      puts "Standard-Lokalisierung erfolgreich erstellt!"
      puts "Admin-Login: admin@carambus.de / admin123"
      puts "Scoreboard-Login: scoreboard@carambus.de / scoreboard"
    end

    desc "Validiere Lokalisierungs-Konfiguration"
    task validate_localization: :environment do
      puts "Validiere Lokalisierungs-Konfiguration..."
      
      # Prüfe Location
      if Location.exists?
        location = Location.first
        puts "✅ Location gefunden: #{location.name}"
        
        # Prüfe Club
        if location.club
          puts "✅ Club gefunden: #{location.club.name}"
          
          # Prüfe Region
          if location.club.region
            puts "✅ Region gefunden: #{location.club.region.name}"
          else
            puts "❌ Keine Region für Club gefunden"
          end
        else
          puts "❌ Kein Club für Location gefunden"
        end
        
        # Prüfe Tische
        tables = location.tables
        if tables.any?
          puts "✅ #{tables.count} Tische gefunden:"
          tables.each do |table|
            puts "  - #{table.name} (#{table.table_kind&.name})"
          end
        else
          puts "❌ Keine Tische für Location gefunden"
        end
      else
        puts "❌ Keine Location gefunden"
      end
      
      # Prüfe Benutzer
      users = User.where("id > 50000000")  # Lokale Benutzer
      if users.any?
        puts "✅ #{users.count} lokale Benutzer gefunden:"
        users.each do |user|
          puts "  - #{user.name} (#{user.email}) - Admin: #{user.admin}"
        end
      else
        puts "❌ Keine lokalen Benutzer gefunden"
      end
      
      # Prüfe Settings
      required_settings = ["carambus_api_url", "location_id", "club_id", "region_id", "scoreboard_url"]
      missing_settings = []
      
      required_settings.each do |key|
        if Setting.exists?(key: key)
          setting = Setting.find_by(key: key)
          puts "✅ Setting gefunden: #{setting.key} = #{setting.value}"
        else
          missing_settings << key
          puts "❌ Setting fehlt: #{key}"
        end
      end
      
      if missing_settings.any?
        puts "⚠️  Fehlende Settings: #{missing_settings.join(', ')}"
      end
      
      puts "Lokalisierungs-Validierung abgeschlossen"
    end

    desc "Exportiere Lokalisierungs-Daten als JSON"
    task export_localization: :environment do
      puts "Exportiere Lokalisierungs-Daten..."
      
      localization_data = {
        timestamp: Time.current.iso8601,
        location: {},
        tables: [],
        users: [],
        settings: {}
      }
      
      # Location-Daten exportieren
      if Location.exists?
        location = Location.first
        localization_data[:location] = {
          id: location.id,
          name: location.name,
          club_id: location.club_id,
          region_id: location.region_id,
          address: location.address,
          phone: location.phone,
          email: location.email
        }
        puts "Location exportiert: #{location.name}"
      end
      
      # Tisch-Daten exportieren
      Table.all.each do |table|
        localization_data[:tables] << {
          id: table.id,
          name: table.name,
          table_kind_id: table.table_kind_id,
          location_id: table.location_id,
          position: table.position,
          remarks: table.remarks
        }
      end
      puts "#{localization_data[:tables].count} Tische exportiert"
      
      # Benutzer-Daten exportieren (nur lokale Benutzer)
      User.where("id > 50000000").each do |user|
        localization_data[:users] << {
          id: user.id,
          name: user.name,
          email: user.email,
          admin: user.admin,
          confirmed_at: user.confirmed_at&.iso8601
        }
      end
      puts "#{localization_data[:users].count} lokale Benutzer exportiert"
      
      # Settings exportieren
      Setting.all.each do |setting|
        localization_data[:settings][setting.key] = setting.value
      end
      puts "#{localization_data[:settings].count} Settings exportiert"
      
      # JSON-Datei schreiben
      output_file = "localization_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"
      File.write(output_file, JSON.pretty_generate(localization_data))
      puts "Lokalisierungs-Daten exportiert: #{output_file}"
    end

    desc "Importiere Lokalisierungs-Daten aus JSON"
    task :import_localization, [:file] => :environment do |task, args|
      if args[:file].blank?
        puts "❌ Bitte geben Sie eine JSON-Datei an: rake carambus:installation:import_localization[file.json]"
        exit 1
      end
      
      file_path = args[:file]
      unless File.exist?(file_path)
        puts "❌ Datei nicht gefunden: #{file_path}"
        exit 1
      end
      
      puts "Importiere Lokalisierungs-Daten aus: #{file_path}"
      
      begin
        localization_data = JSON.parse(File.read(file_path))
      rescue JSON::ParserError => e
        puts "❌ Ungültige JSON-Datei: #{e.message}"
        exit 1
      end
      
      # Location-Daten importieren
      if localization_data['location'] && !localization_data['location'].empty?
        location_data = localization_data['location']
        
        location = Location.find_or_initialize_by(id: location_data['id'])
        location.assign_attributes(
          name: location_data['name'],
          club_id: location_data['club_id'],
          region_id: location_data['region_id'],
          address: location_data['address'],
          phone: location_data['phone'],
          email: location_data['email']
        )
        location.save!
        puts "Location importiert: #{location.name}"
      end
      
      # Tisch-Daten importieren
      if localization_data['tables'] && !localization_data['tables'].empty?
        localization_data['tables'].each do |table_data|
          table = Table.find_or_initialize_by(id: table_data['id'])
          table.assign_attributes(
            name: table_data['name'],
            table_kind_id: table_data['table_kind_id'],
            location_id: table_data['location_id'],
            position: table_data['position'],
            remarks: table_data['remarks']
          )
          table.save!
          puts "Tisch importiert: #{table.name}"
        end
      end
      
      # Benutzer-Daten importieren (nur lokale Benutzer)
      if localization_data['users'] && !localization_data['users'].empty?
        localization_data['users'].each do |user_data|
          user = User.find_or_initialize_by(id: user_data['id'])
          user.assign_attributes(
            name: user_data['name'],
            email: user_data['email'],
            admin: user_data['admin'],
            confirmed_at: user_data['confirmed_at'] ? Time.parse(user_data['confirmed_at']) : nil
          )
          user.save!
          puts "Benutzer importiert: #{user.name}"
        end
      end
      
      # Settings importieren
      if localization_data['settings'] && !localization_data['settings'].empty?
        localization_data['settings'].each do |key, value|
          setting = Setting.find_or_initialize_by(key: key)
          setting.value = value
          setting.save!
          puts "Setting importiert: #{key}"
        end
      end
      
      puts "Lokalisierungs-Daten erfolgreich importiert!"
    end

    desc "Erstelle vollständiges System-Backup"
    task create_backup: :environment do
      puts "Erstelle vollständiges System-Backup..."
      
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      backup_dir = "/opt/carambus/backup"
      backup_name = "carambus_system_#{timestamp}"
      backup_path = "#{backup_dir}/#{backup_name}"
      
      # Backup-Verzeichnis erstellen
      FileUtils.mkdir_p(backup_dir)
      
      # Datenbank-Backup
      db_backup_file = "#{backup_path}_database.sql"
      system("pg_dump -Uwww_data carambus_production > #{db_backup_file}")
      puts "Datenbank-Backup erstellt: #{db_backup_file}"
      
      # Lokalisierungs-Daten exportieren
      localization_file = "#{backup_path}_localization.json"
      Rake::Task['carambus:installation:export_localization'].invoke
      FileUtils.mv("localization_export_*.json", localization_file)
      puts "Lokalisierungs-Daten exportiert: #{localization_file}"
      
      # Konfigurationsdateien sichern
      config_backup_dir = "#{backup_path}_config"
      FileUtils.mkdir_p(config_backup_dir)
      
      config_files = [
        "config/carambus.yml",
        "config/database.yml",
        "config/scoreboard_url",
        "config/credentials/production.key",
        "config/credentials/production.yml.enc",
        "config/environments/production.rb",
        "config/puma.rb"
      ]
      
      config_files.each do |file|
        if File.exist?(file)
          FileUtils.cp(file, config_backup_dir)
          puts "Konfigurationsdatei gesichert: #{file}"
        end
      end
      
      # Konfigurations-Backup komprimieren
      system("tar -czf #{backup_path}_config.tar.gz -C #{config_backup_dir} .")
      FileUtils.rm_rf(config_backup_dir)
      puts "Konfigurations-Backup erstellt: #{backup_path}_config.tar.gz"
      
      # System-Informationen sammeln
      system_info_file = "#{backup_path}_system_info.txt"
      File.write(system_info_file, <<~INFO)
        Carambus System-Backup
        ======================
        Datum: #{Time.current}
        Hostname: #{`hostname`.strip}
        IP-Adresse: #{`hostname -I`.strip}
        Ruby-Version: #{RUBY_VERSION}
        Rails-Version: #{Rails.version}
        Datenbank: #{ActiveRecord::Base.connection_config[:database]}
        
        Lokalisierungs-Daten:
        ====================
        Location: #{Location.first&.name || 'Nicht gefunden'}
        Club: #{Location.first&.club&.name || 'Nicht gefunden'}
        Region: #{Location.first&.club&.region&.name || 'Nicht gefunden'}
        Tische: #{Table.count}
        Lokale Benutzer: #{User.where("id > 50000000").count}
        Settings: #{Setting.count}
      INFO
      puts "System-Informationen gesammelt: #{system_info_file}"
      
      # Alle Backup-Dateien komprimieren
      system("tar -czf #{backup_path}.tar.gz #{backup_path}_*")
      
      # Einzelne Dateien löschen
      FileUtils.rm_f("#{backup_path}_database.sql")
      FileUtils.rm_f("#{backup_path}_localization.json")
      FileUtils.rm_f("#{backup_path}_config.tar.gz")
      FileUtils.rm_f("#{backup_path}_system_info.txt")
      
      puts "Vollständiges System-Backup erstellt: #{backup_path}.tar.gz"
    end

    desc "Zeige Installations-Status"
    task status: :environment do
      puts "Carambus Installations-Status"
      puts "============================"
      puts ""
      
      # System-Status
      puts "System:"
      puts "  Ruby: #{RUBY_VERSION}"
      puts "  Rails: #{Rails.version}"
      puts "  Datenbank: #{ActiveRecord::Base.connection_config[:database]}"
      puts "  Redis: #{Redis.new.ping rescue 'Nicht erreichbar'}"
      puts ""
      
      # Lokalisierungs-Status
      puts "Lokalisierung:"
      if Location.exists?
        location = Location.first
        puts "  Location: #{location.name}"
        puts "  Club: #{location.club&.name || 'Nicht gefunden'}"
        puts "  Region: #{location.club&.region&.name || 'Nicht gefunden'}"
        puts "  Tische: #{location.tables.count}"
      else
        puts "  ❌ Keine Location konfiguriert"
      end
      puts ""
      
      # Benutzer-Status
      puts "Benutzer:"
      admin_users = User.where(admin: true)
      local_users = User.where("id > 50000000")
      puts "  Admin-Benutzer: #{admin_users.count}"
      puts "  Lokale Benutzer: #{local_users.count}"
      puts ""
      
      # Settings-Status
      puts "Settings:"
      required_settings = ["carambus_api_url", "location_id", "club_id", "region_id", "scoreboard_url"]
      required_settings.each do |key|
        setting = Setting.find_by(key: key)
        if setting
          puts "  ✅ #{key}: #{setting.value}"
        else
          puts "  ❌ #{key}: Nicht gesetzt"
        end
      end
      puts ""
      
      # Service-Status
      puts "Services:"
      begin
        response = Net::HTTP.get_response(URI('http://localhost:3000/health'))
        puts "  ✅ Carambus Web: #{response.code}"
      rescue
        puts "  ❌ Carambus Web: Nicht erreichbar"
      end
      
      if system("systemctl is-active --quiet scoreboard")
        puts "  ✅ Scoreboard: Aktiv"
      else
        puts "  ❌ Scoreboard: Nicht aktiv"
      end
      puts ""
      
      puts "Status-Prüfung abgeschlossen"
    end
  end
end 