#!/bin/bash

# Deployment-Skript für Local Server (carambus.de)
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

print_info "Deployment für Local Server (carambus.de) wird gestartet..."

# Capistrano-Deployment starten (Assets werden automatisch auf dem Server gebaut)
print_info "Starte Capistrano-Deployment..."
bundle exec cap local deploy

print_success "Local Server Deployment abgeschlossen!"
print_info "Die Anwendung läuft jetzt auf carambus.de"
print_info "Nginx neu laden: sudo systemctl reload nginx"
print_info "Puma-Status prüfen: sudo systemctl status puma_carambus"
print_info ""
print_info "Hinweis: Assets werden automatisch auf dem Server im Production-Environment gebaut"
