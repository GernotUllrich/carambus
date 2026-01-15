#!/bin/bash

# Deployment-Skript für API Server (api.carambus.de)
# Verwendet Capistrano - einfach und zuverlässig

set -euo pipefail

# Farben für Ausgabe
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info "Deployment für API Server (api.carambus.de) wird gestartet..."

# Prüfen ob es das erste Deployment ist
print_info "Prüfe Server-Setup..."
if ! ssh -p 8910 www-data@carambus.de "test -f /var/www/carambus_api/shared/config/database.yml"; then
    print_warning "Erstes Deployment - erstelle notwendige Verzeichnisse und Konfigurationsdateien..."
    
    # Verzeichnisse erstellen
    ssh -p 8910 www-data@carambus.de "mkdir -p /var/www/carambus_api/shared/config/credentials"
    
    print_info "Bitte kopiere die folgenden Dateien manuell auf den Server:"
    print_info "  - config/database.yml → /var/www/carambus_api/shared/config/"
    print_info "  - config/carambus.yml → /var/www/carambus_api/shared/config/"
    print_info "  - config/scoreboard_url → /var/www/carambus_api/shared/config/"
    print_info "  - config/credentials/production.key → /var/www/carambus_api/shared/config/credentials/"
    print_info "  - config/environments/production.rb → /var/www/carambus_api/shared/config/"
    print_info "  - config/credentials/production.yml.enc → /var/www/carambus_api/shared/config/credentials/"
    print_info "  - config/puma.rb → /var/www/carambus_api/shared/config/"
    
    print_info ""
    print_info "Nach dem Kopieren der Dateien, führe das Deployment erneut aus."
    exit 1
fi

# Capistrano-Deployment starten (Assets werden automatisch auf dem Server gebaut)
print_info "Starte Capistrano-Deployment..."
bundle exec cap production deploy

print_success "API Server Deployment abgeschlossen!"
print_info "Die Anwendung läuft jetzt auf newapi.carambus.de"
print_info "Nginx neu laden: sudo systemctl reload nginx"
print_info "Puma-Status prüfen: sudo systemctl status puma_carambus_api"
print_info ""
print_info "Hinweis: Assets werden automatisch auf dem Server im Production-Environment gebaut"
