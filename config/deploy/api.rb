# Capistrano-Konfiguration für API Server (newapi.carambus.de)
# Ersetzt später api.carambus.de

server 'carambus.de', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"}

# API-spezifische Konfiguration
set :basename, "carambus_api"
set :deploy_to, "/var/www/#{fetch(:basename)}"
set :nginx_server_name, "newapi.carambus.de"

# SSL aktivieren
set :nginx_use_ssl, true

# Puma auf Port 3000
set :puma_port, 3000

# Environment-spezifische Einstellungen
set :rails_env, 'production'
set :branch, 'master'

# Verknüpfte Dateien (aus der Hauptkonfiguration)
append :linked_files, "config/database.yml", "config/carambus.yml", "config/scoreboard_url", "config/credentials/production.key", "config/environments/production.rb", "config/credentials/production.yml.enc", "config/puma.rb"

# Verknüpfte Verzeichnisse
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "node_modules", "public/packs", "public/assets", ".bundle"
