# frozen_string_literal: true

# Hilfsskript zu bin/restore-www-data-password.sh — erzeugt das ALTER-ROLE-Statement
# aus carambus_data/secrets.yml und schreibt es nach stdout (zum Pipen an psql).
#
# Separates File statt `ruby -e`, weil das noetige Quoting (Bash + Ruby + SQL-Literal)
# in einem Einzeiler nicht mehr lesbar — und damit nicht mehr pruefbar — waere.
#
# Usage: ruby build_role_password_sql.rb <secrets.yml> <rolle>

require "yaml"

secrets_path = ARGV[0] or abort("Usage: build_role_password_sql.rb <secrets.yml> <rolle>")
role = ARGV[1] or abort("Usage: build_role_password_sql.rb <secrets.yml> <rolle>")

abort("ABBRUCH: #{secrets_path} nicht gefunden.") unless File.exist?(secrets_path)

password = (YAML.load_file(secrets_path)["shared"] || {})["database_password"].to_s

# Ein leeres Passwort ist genau der Fehler, den dieses Skript repariert — niemals setzen.
abort("ABBRUCH: shared.database_password ist leer. Nichts geaendert.") if password.empty?

warn "Passwort gelesen (#{password.length} Zeichen) — Rolle #{role} wird zurueckgesetzt."

# PostgreSQL-String-Literal: einfache Quotes werden verdoppelt.
escaped = password.gsub("'", "''")
puts "ALTER ROLE #{role} WITH PASSWORD '#{escaped}';"
