# Capistrano-Konfiguration für Local Server (new.carambus.de)
# Ersetzt später carambus.de

server 'carambus.de', user: 'www-data', roles: %w{app db web}, ssh_options: {port: "8910"}

# Local-spezifische Konfiguration
set :basename, "carambus"
set :deploy_to, "/var/www/#{fetch(:basename)}"
set :nginx_server_name, "new.carambus.de"

# SSL aktivieren
set :nginx_use_ssl, true

# Puma auf Port 3001
set :puma_port, 3001

# Environment-spezifische Einstellungen
set :rails_env, 'production'
set :branch, 'master'

# Verknüpfte Dateien (aus der Hauptkonfiguration)
append :linked_files, "config/database.yml", "config/carambus.yml", "config/scoreboard_url", "config/credentials/production.key", "config/environments/production.rb", "config/credentials/production.yml.enc", "config/puma.rb"

# Verknüpfte Verzeichnisse
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "node_modules", "public/packs", "public/assets", ".bundle"
