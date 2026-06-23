# frozen_string_literal: true

# Sysadmin-Werkzeug: einen User von einem Scenario-Deployment in ein anderes uebertragen.
#
# Scenarios sind getrennte Deployments mit je eigener Datenbank (i.d.R. auf getrennten
# Servern). User sind immer LOKALE Records (id >= MIN_ID = 50_000_000) und werden nie ueber
# die API gesynct. Diese Tasks transportieren einen User dateibasiert (Prod -> Prod):
#
#   1. QUELL-Server:  RAILS_ENV=production bundle exec rake "user:export[email@example.de]"
#   2. JSON-Datei per scp auf den Ziel-Server kopieren.
#   3. ZIEL-Server:   RAILS_ENV=production bundle exec rake "user:import[/pfad/datei.json]"
#
# Uebertragen werden: Identitaet (Login, Passwort-Hash, Name, role, confirmed_at),
# persona_grants, preferences, CC-Admin-Credentials (cc_username + verschluesseltes
# cc_password) sowie der Sportwart-Wirkbereich (sportwart_locations/-disciplines, per
# natuerlichem Schluessel im Ziel neu aufgeloest) und der Player-Link (per ba_id/dbu_nr).
# NICHT uebertragen: user_tournaments (turnier-spezifische, ephemere TL-Grants).
#
# Die lokale id des Users aendert sich beim Import: die Ziel-Sequence (sequence_reset)
# vergibt eine neue id >= MIN_ID. Kollision per E-Mail steuert ENV ON_CONFLICT
# (abort [default] | update | skip).

USER_TRANSFER_FORMAT = "carambus.user_transfer"
USER_TRANSFER_FORMAT_VERSION = 1

def user_transfer_parse_time(value)
  value.present? ? Time.zone.parse(value.to_s) : nil
end

def user_transfer_player_key(player)
  return nil if player.nil?

  {
    "ba_id" => player.ba_id,
    "dbu_nr" => player.dbu_nr,
    "label" => player.try(:fullname).presence || "Player##{player.id}"
  }
end

namespace :user do
  desc "User in portable JSON-Datei exportieren: rake \"user:export[email,outfile]\""
  task :export, [:email, :outfile] => :environment do |_t, args|
    email = args[:email].to_s.strip
    abort "❌ E-Mail fehlt. Aufruf: rake \"user:export[email@example.de]\"" if email.blank?

    user = User.find_by(email: email)
    abort "❌ Kein User mit E-Mail #{email.inspect} gefunden." if user.nil?

    # cc_password als ROH-Ciphertext lesen (nicht entschluesseln) — bleibt at rest sicher und
    # ist im Ziel nur mit den (fleet-uniformen) Active-Record-Encryption-Keys lesbar.
    cc_cipher = ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.sanitize_sql_array(["SELECT cc_password FROM users WHERE id = ?", user.id])
    )

    payload = {
      "format" => USER_TRANSFER_FORMAT,
      "format_version" => USER_TRANSFER_FORMAT_VERSION,
      "exported_at" => Time.current.utc.iso8601,
      "source" => {
        "context" => Carambus.config.context,
        "database" => ActiveRecord::Base.connection.current_database,
        "user_id" => user.id
      },
      "user" => {
        "email" => user.email,
        "encrypted_password" => user.encrypted_password,
        "username" => user.username,
        "first_name" => user.first_name,
        "last_name" => user.last_name,
        "firstname" => user.firstname,
        "lastname" => user.lastname,
        "role" => user.role,
        "persona_grants" => user.persona_grants,
        "preferences" => user.preferences,
        "time_zone" => user.time_zone,
        "preferred_language" => user.preferred_language,
        "confirmed_at" => user.confirmed_at&.utc&.iso8601,
        "accepted_terms_at" => user.accepted_terms_at&.utc&.iso8601,
        "accepted_privacy_at" => user.accepted_privacy_at&.utc&.iso8601,
        "mcp_consent_at" => user.mcp_consent_at&.utc&.iso8601,
        "cc_username" => user.cc_username,
        "cc_password_ciphertext" => cc_cipher
      },
      "associations" => {
        "player" => user_transfer_player_key(user.player),
        "sportwart_locations" => user.sportwart_locations.map { |l|
          {"md5" => l.md5, "cc_id" => l.cc_id, "name" => l.name}
        },
        "sportwart_disciplines" => user.sportwart_disciplines.map { |d|
          {"name" => d.name, "type" => d.type}
        }
      }
    }

    outfile = args[:outfile].presence ||
      Rails.root.join("tmp", "user_export_#{email.parameterize}_#{Time.current.strftime("%Y%m%d_%H%M%S")}.json").to_s
    File.write(outfile, JSON.pretty_generate(payload))

    puts "✅ User #{email} (id #{user.id}, Kontext #{Carambus.config.context.inspect}) exportiert:"
    puts "   #{outfile}"
    puts "   role: #{user.role}, persona_grants: #{user.persona_grants.inspect}"
    puts "   Sportwart-Locations: #{user.sportwart_locations.size}, -Disziplinen: #{user.sportwart_disciplines.size}"
    puts "   Player-Link: #{user.player ? (user.player.try(:fullname) || "id #{user.player_id}") : "—"}"
    puts "   CC-Creds: #{user.cc_credentials_present? ? "vorhanden" : "—"}"
    puts ""
    puts "⚠️  Die Datei enthaelt den Passwort-Hash und das (verschluesselte) CC-Passwort —"
    puts "    nach dem Import auf dem Ziel-Server loeschen."
  end

  desc "User aus JSON-Datei importieren: rake \"user:import[file]\"  (ENV ON_CONFLICT=abort|update|skip)"
  task :import, [:file] => :environment do |_t, args|
    file = args[:file].to_s.strip
    abort "❌ Datei-Pfad fehlt. Aufruf: rake \"user:import[/pfad/datei.json]\"" if file.blank?
    abort "❌ Datei nicht gefunden: #{file}" unless File.exist?(file)

    payload = JSON.parse(File.read(file))
    unless payload["format"] == USER_TRANSFER_FORMAT
      abort "❌ Unerwartetes Datei-Format (#{payload["format"].inspect}) — keine user:export-Datei."
    end
    if payload["format_version"].to_i > USER_TRANSFER_FORMAT_VERSION
      abort "❌ Datei-Version #{payload["format_version"]} ist neuer als dieser Task (#{USER_TRANSFER_FORMAT_VERSION})."
    end

    u = payload.fetch("user")
    assoc = payload["associations"] || {}
    email = u.fetch("email")
    on_conflict = (ENV["ON_CONFLICT"].presence || "abort").downcase

    existing = User.find_by(email: email)
    if existing
      case on_conflict
      when "skip"
        puts "⏭️  User #{email} existiert bereits (id #{existing.id}) — uebersprungen (ON_CONFLICT=skip)."
        next
      when "update"
        puts "♻️  User #{email} existiert (id #{existing.id}) — wird aktualisiert (ON_CONFLICT=update)."
      else
        abort "❌ User #{email} existiert bereits (id #{existing.id}). " \
          "Mit ON_CONFLICT=update ueberschreiben oder ON_CONFLICT=skip ueberspringen."
      end
    end

    warnings = []
    imported_id = nil

    ActiveRecord::Base.transaction do
      user = existing || User.new
      user.email = email
      user.encrypted_password = u["encrypted_password"].to_s
      user.username = u["username"]
      user.first_name = u["first_name"]
      user.last_name = u["last_name"]
      user.firstname = u["firstname"]
      user.lastname = u["lastname"]
      user.role = u["role"] if u["role"].present?
      user.persona_grants = Array(u["persona_grants"])
      user.preferences = u["preferences"] || {}
      user.time_zone = u["time_zone"]
      user.preferred_language = u["preferred_language"]
      user.confirmed_at = user_transfer_parse_time(u["confirmed_at"])
      user.accepted_terms_at = user_transfer_parse_time(u["accepted_terms_at"])
      user.accepted_privacy_at = user_transfer_parse_time(u["accepted_privacy_at"])
      user.mcp_consent_at = user_transfer_parse_time(u["mcp_consent_at"])
      user.cc_username = u["cc_username"]
      user.jti = SecureRandom.uuid if user.jti.blank?

      # Player-Link per natuerlichem Schluessel neu aufloesen (ba_id bevorzugt, sonst dbu_nr).
      if (p = assoc["player"]).present?
        player = (p["ba_id"].present? ? Player.find_by(ba_id: p["ba_id"]) : nil) ||
          (p["dbu_nr"].present? ? Player.find_by(dbu_nr: p["dbu_nr"]) : nil)
        if player
          user.player_id = player.id
        else
          warnings << "Player #{p["label"] || p["ba_id"]} im Ziel-Scenario nicht gefunden — player_id bleibt leer."
        end
      end

      # Validierungen ueberspringen: ToS-Acceptance + Passwort-Presence gelten nur bei der
      # Original-Registrierung; hier wird ein bereits validierter User transportiert.
      user.save!(validate: false)

      # cc_password (Roh-Ciphertext) verbatim schreiben — NICHT per Attribut-Zuweisung
      # (wuerde erneut verschluesseln). Danach Entschluesselbarkeit pruefen; schlaegt nur bei
      # abweichenden AR-Encryption-Keys fehl.
      cc_cipher = u["cc_password_ciphertext"]
      if cc_cipher.present?
        ActiveRecord::Base.connection.exec_update(
          ActiveRecord::Base.sanitize_sql_array(["UPDATE users SET cc_password = ? WHERE id = ?", cc_cipher, user.id])
        )
        user.reload
        begin
          user.cc_password
        rescue ActiveRecord::Encryption::Errors::Decryption
          ActiveRecord::Base.connection.exec_update(
            ActiveRecord::Base.sanitize_sql_array(["UPDATE users SET cc_password = NULL WHERE id = ?", user.id])
          )
          warnings << "CC-Passwort nicht entschluesselbar (AR-Encryption-Keys unterschiedlich?) — geleert, im UI neu setzen."
        end
      end

      # Sportwart-Wirkbereich. Bei update vorhandene Zuordnungen ersetzen (idempotent).
      if on_conflict == "update"
        user.sportwart_location_assignments.destroy_all
        user.sportwart_discipline_assignments.destroy_all
      end

      Array(assoc["sportwart_locations"]).each do |l|
        loc = (l["md5"].present? ? Location.find_by(md5: l["md5"]) : nil) ||
          (l["cc_id"].present? ? Location.find_by(cc_id: l["cc_id"]) : nil)
        if loc
          SportwartLocation.find_or_create_by!(user_id: user.id, location_id: loc.id)
        else
          warnings << "Location #{l["name"] || l["md5"]} im Ziel nicht synct — Sportwart-Scope unvollstaendig."
        end
      end

      Array(assoc["sportwart_disciplines"]).each do |d|
        disc = Discipline.find_by(name: d["name"], type: d["type"]) || Discipline.find_by(name: d["name"])
        if disc
          SportwartDiscipline.find_or_create_by!(user_id: user.id, discipline_id: disc.id)
        else
          warnings << "Disziplin #{d["name"]} im Ziel nicht gefunden — Sportwart-Scope unvollstaendig."
        end
      end

      imported_id = user.id
    end

    user = User.find(imported_id)
    puts "✅ User #{email} importiert (lokale id #{user.id}, Kontext #{Carambus.config.context.inspect})."
    puts "   role: #{user.role}, persona_grants: #{user.persona_grants.inspect}"
    puts "   Sportwart-Locations: #{user.sportwart_locations.size}, -Disziplinen: #{user.sportwart_disciplines.size}"
    puts "   Player-Link: #{user.player_id ? "id #{user.player_id}" : "—"}"
    puts "   CC-Creds: #{user.cc_credentials_present? ? "uebernommen" : "—"}"
    if warnings.any?
      puts ""
      puts "⚠️  Hinweise:"
      warnings.each { |w| puts "   - #{w}" }
    end
  end
end
