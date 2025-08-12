#!/bin/bash

# Carambus Docker Deployment Script
# Läuft auf dem Zielsystem und startet Docker mit dem vorbereiteten Deployment-Paket

set -euo pipefail

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktionen
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Verwendung: $0 [OPTIONS]

Optionen:
  -e, --env ENV_FILE     Environment-Datei verwenden (Standard: env.local-server)
  -d, --detach           Docker im Hintergrund starten
  -h, --help             Diese Hilfe anzeigen

Beispiele:
  $0                          # Standard-Deployment (env.unified)
  $0 --env env.api-server     # API Server Environment
  $0 --env env.local-server   # Lokaler Server Environment
  $0 --env env.development    # Development Environment
  $0 --detach                 # Im Hintergrund starten

Hinweis: Dieses Skript erwartet, dass alle notwendigen Dateien bereits
im aktuellen Verzeichnis vorhanden sind (aus dem Deployment-Paket).

EOF
}

# Standardwerte
ENV_FILE="env.unified"
DETACH_MODE=""

# Argumente parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENV_FILE="$2"
            shift 2
            ;;
        -d|--detach)
            DETACH_MODE="-d"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unbekannter Parameter: $1"
            show_usage
            exit 1
            ;;
    esac
    shift
done

print_info "Carambus Docker Deployment wird gestartet"
print_info "Environment-Datei: $ENV_FILE"

# Prüfen ob wir im richtigen Verzeichnis sind
if [[ ! -f "docker-compose.yml" ]]; then
    print_error "docker-compose.yml nicht gefunden. Bitte stellen Sie sicher, dass Sie im Deployment-Paket-Verzeichnis sind."
    exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
    print_error "Environment-Datei nicht gefunden: $ENV_FILE"
    print_info "Verfügbare Environment-Dateien:"
    ls -la env.* 2>/dev/null || print_warning "Keine Environment-Dateien gefunden"
    exit 1
fi

# Prüfen ob Datenbanken vorhanden sind
if [[ ! -d "databases" ]]; then
    print_warning "Datenbank-Verzeichnis nicht gefunden. Docker wird ohne initiale Datenbanken gestartet."
else
    print_info "Datenbanken gefunden:"
    find databases -name "*.sql.gz" -type f | head -5 | while read -r file; do
        print_info "  - $(basename "$file")"
    done
    if [[ $(find databases -name "*.sql.gz" -type f | wc -l) -gt 5 ]]; then
        print_info "  ... und weitere"
    fi
fi

# Docker Compose Datei basierend auf Environment auswählen
COMPOSE_FILE="docker-compose.unified.yml"
case "$ENV_FILE" in
    "env.api-server")
        print_info "Verwende vereinheitlichte Konfiguration mit API Server Environment"
        ;;
    "env.local-server")
        print_info "Verwende vereinheitlichte Konfiguration mit Lokaler Server Environment"
        ;;
    "env.development")
        print_info "Verwende vereinheitlichte Konfiguration mit Development Environment"
        ;;
esac

if [[ ! -f "$COMPOSE_FILE" ]]; then
    print_error "Docker Compose Datei nicht gefunden: $COMPOSE_FILE"
    exit 1
fi

# Environment-Datei laden
print_info "Lade Environment-Konfiguration: $ENV_FILE"
export $(grep -v '^#' "$ENV_FILE" | xargs)

# Docker prüfen
if ! command -v docker &> /dev/null; then
    print_error "Docker ist nicht installiert"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose ist nicht installiert"
    exit 1
fi

# Docker Service prüfen
if ! docker info &> /dev/null; then
    print_error "Docker Service läuft nicht. Bitte starten Sie Docker."
    exit 1
fi

print_info "Docker Version: $(docker --version)"
print_info "Docker Compose Version: $(docker-compose --version)"

# Bestehende Container stoppen falls vorhanden
print_info "Stoppe bestehende Container..."
docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true

# Container starten
print_info "Starte Docker Container mit $COMPOSE_FILE..."
if [[ -n "$DETACH_MODE" ]]; then
    docker-compose -f "$COMPOSE_FILE" up -d
    print_success "Docker Container im Hintergrund gestartet"
    print_info "Container-Status anzeigen mit: docker-compose -f $COMPOSE_FILE ps"
    print_info "Logs anzeigen mit: docker-compose -f $COMPOSE_FILE logs -f"
else
    print_info "Docker Container werden gestartet. Drücken Sie Ctrl+C zum Stoppen."
    docker-compose -f "$COMPOSE_FILE" up
fi

print_success "Deployment abgeschlossen!"
print_info ""
print_info "Nächste Schritte:"
print_info "1. Überprüfen Sie den Container-Status:"
print_info "   docker-compose -f $COMPOSE_FILE ps"
print_info ""
print_info "2. Logs anzeigen:"
print_info "   docker-compose -f $COMPOSE_FILE logs -f"
print_info ""
print_info "3. Container stoppen:"
print_info "   docker-compose -f $COMPOSE_FILE down"
print_info ""
print_info "4. Datenbank-Status prüfen:"
print_info "   ./scripts/manage-databases.sh status" 