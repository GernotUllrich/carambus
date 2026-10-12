# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "time"

# ─────────────────────────────────────────────────────────────────────────────
# Regionsdumps der Authority (Plan 18-02).
#
# Die Authority baut je Region einen gefilterten, bereinigten Dump, mit dem ein
# Verein seinen Server erstbefuellt, ohne SSH-Zugang zur Authority. Der
# Versions-Sync schliesst ueber last_version_id an.
#
# Hier stehen die Regeln: was bereinigt wird (SANITIZE), woran das geprueft
# wird (CHECKS, region_checks), Manifest und Aufbewahrung. Datenbanken, Dateien
# und Subprozesse behandelt der Rake-Task region_dump:build.
# ─────────────────────────────────────────────────────────────────────────────
class RegionDump
  KEEP = 2

  # Reihenfolge wegen der Fremdschluessel: user_tournaments hat kein on_delete; sportwart_* (cascade),
  # mcp_audit_trails und tournaments.turnier_leiter_user_id (nullify) erledigen sich beim DELETE FROM users.
  # Laeuft auf der Basis-Kopie VOR dem Regionsfilter — users.player_id verweist auf players.
  SANITIZE = [
    ["Benutzer-Turnier-Zuordnungen", "DELETE FROM user_tournaments"],
    ["Benutzerkonten", "DELETE FROM users"],
    ["ClubCloud-Zugänge der Regionen",
      "UPDATE region_ccs SET username = NULL, userpw = NULL WHERE username IS NOT NULL OR userpw IS NOT NULL"],
    ["API-Zugänge internationaler Quellen",
      "UPDATE international_sources SET api_credentials = NULL WHERE api_credentials IS NOT NULL"],
    ["MCP-Protokoll und KI-Nutzung", "TRUNCATE mcp_audit_trails, ai_usage_events"],
    ["Versionshistorie", "DELETE FROM versions"],
    ["ClubCloud-Sitzung in settings",
      "UPDATE settings SET data = ((data::jsonb) - 'session_id' - 'session_login_time')::text " \
      "WHERE COALESCE(data, '') <> '' AND ((data::jsonb) ? 'session_id' OR (data::jsonb) ? 'session_login_time')"]
  ].freeze

  # Jede Abfrage muss 0 liefern.
  CHECKS = {
    "users" => "SELECT COUNT(*) FROM users",
    "user_tournaments" => "SELECT COUNT(*) FROM user_tournaments",
    "region_ccs-Zugänge" => "SELECT COUNT(*) FROM region_ccs WHERE COALESCE(username, '') <> '' OR COALESCE(userpw, '') <> ''",
    "international_sources-Zugänge" => "SELECT COUNT(*) FROM international_sources WHERE COALESCE(api_credentials, '') <> ''",
    "mcp_audit_trails" => "SELECT COUNT(*) FROM mcp_audit_trails",
    "ai_usage_events" => "SELECT COUNT(*) FROM ai_usage_events",
    "versions" => "SELECT COUNT(*) FROM versions",
    "settings-Sitzung" => "SELECT COUNT(*) FROM settings WHERE COALESCE(data, '') <> '' " \
      "AND ((data::jsonb) ? 'session_id' OR (data::jsonb) ? 'session_login_time')",
    "last_version_id fehlt" => "SELECT CASE WHEN EXISTS (SELECT 1 FROM settings WHERE id = (SELECT MIN(id) FROM settings) " \
      "AND COALESCE(data, '') <> '' AND (data::jsonb) ? 'last_version_id') THEN 0 ELSE 1 END"
  }.freeze

  # Tabellen, die cleanup:remove_non_region_records filtert (dieselbe Liste, dieselbe Bedingung).
  REGION_TABLES = %w[season_participations game_participations games party_games parties league_teams seedings
    players game_plans leagues tournaments tables club_locations locations clubs].freeze

  DUMP_FILE = /\Acarambus_([a-z]+)_(\d{8}_\d{6})\.sql\.gz\z/

  # Der Filter endet bei unbekannter Region mit `exit` (Status 0) — ob er gewirkt hat, zeigt erst das Ergebnis.
  def self.region_checks(region_id)
    id = Integer(region_id)
    REGION_TABLES.to_h do |t|
      ["fremde #{t}", "SELECT COUNT(*) FROM #{t} WHERE NOT (region_id = #{id} OR region_id IS NULL OR global_context = TRUE)"]
    end
  end

  # last_version_id auf der Setting-Instanz (Setting.first = kleinste id) im Format von Setting.key_set_value.
  def self.last_version_sql(version_id)
    id = Integer(version_id)
    "UPDATE settings SET data = (COALESCE(NULLIF(data, ''), '{}')::jsonb || " \
      "jsonb_build_object('last_version_id', jsonb_build_object('Integer', '#{id}')))::text " \
      "WHERE id = (SELECT MIN(id) FROM settings)"
  end

  def self.dump_name(region, time)
    "carambus_#{region.to_s.downcase}_#{time.strftime("%Y%m%d_%H%M%S")}.sql.gz"
  end

  def self.manifest(region:, file:, last_version_id:, schema_version:, created_at:)
    {
      "region" => region.to_s.upcase,
      "file" => File.basename(file),
      "created_at" => created_at.utc.iso8601,
      "last_version_id" => Integer(last_version_id),
      "schema_version" => schema_version.to_s,
      "size" => File.size(file),
      "sha256" => Digest::SHA256.file(file).hexdigest
    }
  end

  # ── Zugang je Region (nginx auth_basic, Datei .htpasswd/<REGION>) ────────────────────────────────
  LOGIN = /\A[a-z0-9][a-z0-9._-]{1,62}\z/i
  REGION = /\A[A-Z]+\z/

  def self.valid_login!(login)
    raise ArgumentError, "Login nur aus Buchstaben, Ziffern, . _ - (2–63 Zeichen): #{login.inspect}" unless LOGIN.match?(login.to_s)

    login.to_s
  end

  def self.htpasswd_logins(text)
    text.to_s.lines.filter_map { |l| l.split(":", 2).first if l.include?(":") }
  end

  # Setzt (ersetzt oder ergaenzt) die Zeile fuer login.
  def self.htpasswd_set(text, login, hash)
    login = valid_login!(login)
    lines = text.to_s.lines.map(&:chomp).reject { |l| l.split(":", 2).first == login || l.strip.empty? }
    (lines << "#{login}:#{hash}").join("\n") + "\n"
  end

  # Liefert [neuer Text, entfernt?].
  def self.htpasswd_remove(text, login)
    lines = text.to_s.lines.map(&:chomp).reject(&:empty?)
    kept = lines.reject { |l| l.split(":", 2).first == login.to_s }
    [kept.empty? ? "" : kept.join("\n") + "\n", kept.size < lines.size]
  end

  # apr1-Hash (nginx-nativ) per openssl; das Passwort geht ueber stdin, nie in die Prozessliste.
  def self.apr1(password, salt: nil)
    cmd = ["openssl", "passwd", "-apr1", "-stdin"]
    cmd += ["-salt", salt] if salt
    out, err, status = Open3.capture3(*cmd, stdin_data: password)
    raise "openssl passwd fehlgeschlagen: #{err.strip}" unless status.success?

    out.strip
  end

  # Welche Dump-Dateien eines Regionsverzeichnisses zu loeschen sind (alle ausser den KEEP juengsten).
  def self.expired(filenames, keep: KEEP)
    dumps = filenames.select { |f| DUMP_FILE.match?(f) }.sort_by { |f| DUMP_FILE.match(f)[2] }
    dumps[0...[dumps.size - keep, 0].max]
  end

  # ── Einspielen beim Verein (Plan 18-03) ──────────────────────────────────────────────────────────
  DEFAULT_URL = "https://api.carambus.de"

  # Zugang aus carambus_data/secrets.yml: per_scenario.<szenario>.region_dump {login, password, url}.
  # nil, wenn der Abschnitt fehlt — dann bleibt prepare_development beim SSH-Weg des Betreibers.
  def self.access_from_secrets(pool, scenario_name)
    access = (pool || {}).dig("per_scenario", scenario_name.to_s, "region_dump")
    return nil unless access.is_a?(Hash)

    login = access["login"].to_s
    password = access["password"].to_s
    raise ArgumentError, "region_dump für #{scenario_name}: login und password nötig" if login.empty? || password.empty?

    {login: login, password: password, url: (access["url"].presence || DEFAULT_URL).to_s.chomp("/")}
  end

  # Prueft das Manifest (latest.json) gegen die Region des Szenarios, bevor etwas geladen wird.
  def self.validate_manifest!(manifest, region:)
    region = region.to_s.upcase
    m = manifest.is_a?(Hash) ? manifest : {}
    problems = []
    problems << "Region #{m["region"].inspect} statt #{region}" unless m["region"].to_s == region
    match = DUMP_FILE.match(m["file"].to_s)
    problems << "Dateiname #{m["file"].inspect} passt nicht" unless match && match[1] == region.downcase
    problems << "sha256 fehlt oder ist ungültig" unless m["sha256"].to_s.match?(/\A\h{64}\z/)
    problems << "Größe fehlt" unless m["size"].is_a?(Integer) && m["size"].positive?
    problems << "last_version_id fehlt" unless m["last_version_id"].is_a?(Integer) && m["last_version_id"].positive?
    raise ArgumentError, "Manifest ungültig: #{problems.join(", ")}" if problems.any?

    m
  end

  # Ab welcher psql-Version \restrict/\unrestrict verstanden wird (CVE-2025-8714). Aeltere psql melden
  # „invalid command“ und brechen mit ON_ERROR_STOP ab — dort werden genau diese Zeilen herausgefiltert.
  RESTRICT_MIN = {14 => 19, 15 => 14, 16 => 10, 17 => 6}.freeze

  def self.restrict_supported?(psql_version_output)
    version = psql_version_output.to_s.match(/(\d+)\.(\d+)/)
    return false unless version

    major, minor = version[1].to_i, version[2].to_i
    return true if major > RESTRICT_MIN.keys.max
    return false unless RESTRICT_MIN.key?(major)

    minor >= RESTRICT_MIN[major]
  end

  def self.restrict_line?(line)
    line.match?(/\A\\(un)?restrict \S+\s*\z/)
  end
end
