#!/bin/bash

# Deployment-Skript für API Server (newapi.carambus.de)
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

print_info "Deployment für API Server (newapi.carambus.de) wird gestartet..."

# 1. Assets für Production bauen
print_info "Baue Production-Assets..."
yarn build
yarn build:css
rails assets:precompile

# 2. Capistrano-Deployment starten
print_info "Starte Capistrano-Deployment..."
bundle exec cap api deploy

print_success "API Server Deployment abgeschlossen!"
print_info "Die Anwendung läuft jetzt auf newapi.carambus.de"
print_info "Nginx neu laden: sudo systemctl reload nginx"
print_info "Puma-Status prüfen: sudo systemctl status puma_carambus_api"
