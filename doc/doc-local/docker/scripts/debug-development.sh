#!/bin/bash

# Carambus Development Debug Script
# Optimiert für Docker-Development auf dem Mac

set -euo pipefail

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_debug() {
    echo -e "${CYAN}[DEBUG]${NC} $1"
}

show_usage() {
    cat << EOF
Verwendung: $0 [COMMAND] [OPTIONS]

Befehle:
  start           - Development-Container starten
  stop            - Development-Container stoppen
  restart         - Development-Container neu starten
  console         - Rails Console öffnen
  server          - Rails Server starten
  rake TASK       - Rake Task ausführen
  logs            - Container-Logs anzeigen
  shell           - Bash-Shell im Web-Container öffnen
  db:console      - PostgreSQL Console öffnen
  db:reset        - Datenbank zurücksetzen
  db:migrate      - Datenbank-Migrationen ausführen
  db:seed         - Datenbank mit Seed-Daten füllen
  debug           - Debug-Server für RubyMine starten
  status          - Container-Status anzeigen
  clean           - Alle Development-Container und Volumes löschen

Optionen:
  -f, --follow    - Logs kontinuierlich anzeigen (bei logs)
  -h, --help      - Diese Hilfe anzeigen

Beispiele:
  $0 start                    # Development-Container starten
  $0 console                  # Rails Console öffnen
  $0 rake db:migrate          # Datenbank-Migrationen ausführen
  $0 rake -T                  # Alle verfügbaren Rake Tasks anzeigen
  $0 logs -f                  # Logs kontinuierlich anzeigen
  $0 debug                    # Debug-Server für RubyMine starten

EOF
}

# Verzeichnis prüfen
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.development-debug.yml"
ENV_FILE="$PROJECT_ROOT/env.development-debug"

# Prüfen ob wir im richtigen Verzeichnis sind
if [[ ! -f "$COMPOSE_FILE" ]]; then
    print_error "docker-compose.development-debug.yml nicht gefunden"
    print_info "Bitte führen Sie dieses Skript aus dem Projektverzeichnis aus"
    exit 1
fi

# Docker prüfen
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker ist nicht installiert"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose ist nicht installiert"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker Service läuft nicht. Bitte starten Sie Docker."
        exit 1
    fi
}

# Container-Status prüfen
check_container_status() {
    if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        print_warning "Development-Container laufen nicht. Starten Sie sie mit: $0 start"
        return 1
    fi
    return 0
}

# Development-Container starten
start_containers() {
    print_info "Starte Development-Container..."
    
    # Environment-Datei laden
    if [[ -f "$ENV_FILE" ]]; then
        print_info "Lade Environment-Konfiguration: $ENV_FILE"
        export $(grep -v '^#' "$ENV_FILE" | xargs)
    fi
    
    docker-compose -f "$COMPOSE_FILE" up -d
    
    print_success "Development-Container gestartet!"
    print_info ""
    print_info "Verfügbare Befehle:"
    print_info "  - Rails Console: $0 console"
    print_info "  - Rails Server: $0 server"
    print_info "  - Rake Tasks: $0 rake -T"
    print_info "  - Debug: $0 debug"
    print_info "  - Logs: $0 logs"
    print_info ""
    print_info "Container-Status: $0 status"
}

# Development-Container stoppen
stop_containers() {
    print_info "Stoppe Development-Container..."
    docker-compose -f "$COMPOSE_FILE" down
    print_success "Development-Container gestoppt!"
}

# Rails Console öffnen
open_console() {
    if ! check_container_status; then
        return 1
    fi
    
    print_info "Öffne Rails Console..."
    docker-compose -f "$COMPOSE_FILE" exec web bundle exec rails console
}

# Rails Server starten
start_server() {
    if ! check_container_status; then
        return 1
    fi
    
    print_info "Starte Rails Server..."
    print_info "Server läuft auf: http://localhost:3000"
    print_info "Drücken Sie Ctrl+C zum Stoppen"
    
    docker-compose -f "$COMPOSE_FILE" exec web bundle exec rails server -b 0.0.0.0
}

# Rake Task ausführen
run_rake() {
    if ! check_container_status; then
        return 1
    fi
    
    if [[ $# -eq 0 ]]; then
        print_info "Zeige alle verfügbaren Rake Tasks..."
        docker-compose -f "$COMPOSE_FILE" exec web bundle exec rake -T
    else
        print_info "Führe Rake Task aus: $*"
        docker-compose -f "$COMPOSE_FILE" exec web bundle exec rake "$@"
    fi
}

# Container-Logs anzeigen
show_logs() {
    if ! check_container_status; then
        return 1
    fi
    
    if [[ "$*" == *"-f"* ]] || [[ "$*" == *"--follow"* ]]; then
        print_info "Zeige Container-Logs (kontinuierlich)..."
        print_info "Drücken Sie Ctrl+C zum Beenden"
        docker-compose -f "$COMPOSE_FILE" logs -f
    else
        print_info "Zeige Container-Logs..."
        docker-compose -f "$COMPOSE_FILE" logs
    fi
}

# Bash-Shell im Web-Container öffnen
open_shell() {
    if ! check_container_status; then
        return 1
    fi
    
    print_info "Öffne Bash-Shell im Web-Container..."
    docker-compose -f "$COMPOSE_FILE" exec web bash
}

# PostgreSQL Console öffnen
open_db_console() {
    if ! check_container_status; then
        return 1
    fi
    
    print_info "Öffne PostgreSQL Console..."
    docker-compose -f "$COMPOSE_FILE" exec postgres psql -U www_data -d carambus_development
}

# Datenbank zurücksetzen
reset_database() {
    if ! check_container_status; then
        return 1
    fi
    
    print_warning "ACHTUNG: Dies löscht alle Daten in der Development-Datenbank!"
    read -p "Fortfahren? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Abgebrochen"
        return 0
    fi
    
    print_info "Setze Datenbank zurück..."
    docker-compose -f "$COMPOSE_FILE" exec web bundle exec rake db:drop db:create db:migrate
    print_success "Datenbank zurückgesetzt!"
}

# Datenbank-Migrationen ausführen
run_migrations() {
    if ! check_container_status; then
        return 1
    fi
    
    print_info "Führe Datenbank-Migrationen aus..."
    docker-compose -f "$COMPOSE_FILE" exec web bundle exec rake db:migrate
    print_success "Migrationen abgeschlossen!"
}

# Datenbank mit Seed-Daten füllen
seed_database() {
    if ! check_container_status; then
        return 1
    fi
    
    print_info "Fülle Datenbank mit Seed-Daten..."
    docker-compose -f "$COMPOSE_FILE" exec web bundle exec rake db:seed
    print_success "Seed-Daten eingefügt!"
}

# Debug-Server für RubyMine starten
start_debug_server() {
    if ! check_container_status; then
        return 1
    fi
    
    print_info "Starte Debug-Server für RubyMine..."
    print_info "Debug-Port: 12345"
    print_info "RubyMine Debug-Port: 26162"
    print_info ""
    print_info "In RubyMine: Run → Edit Configurations → + → Ruby Remote Debug"
    print_info "Remote Host: localhost, Remote Port: 12345"
    print_info ""
    print_info "Drücken Sie Ctrl+C zum Stoppen"
    
    docker-compose -f "$COMPOSE_FILE" exec web bundle exec rdebug-ide -- bin/rails server -b 0.0.0.0
}

# Container-Status anzeigen
show_status() {
    print_info "Development-Container Status:"
    docker-compose -f "$COMPOSE_FILE" ps
    
    echo ""
    print_info "Verfügbare Ports:"
    print_info "  - Web: http://localhost:3000"
    print_info "  - PostgreSQL: localhost:5432"
    print_info "  - Redis: localhost:6379"
    print_info "  - Debug: localhost:12345"
    print_info "  - RubyMine Debug: localhost:26162"
}

# Alle Development-Container und Volumes löschen
clean_all() {
    print_warning "ACHTUNG: Dies löscht alle Development-Container und -Daten!"
    read -p "Fortfahren? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Abgebrochen"
        return 0
    fi
    
    print_info "Lösche alle Development-Container und -Volumes..."
    docker-compose -f "$COMPOSE_FILE" down -v --remove-orphans
    print_success "Alle Development-Ressourcen gelöscht!"
}

# Hauptlogik
main() {
    check_docker
    
    case "${1:-}" in
        start)
            start_containers
            ;;
        stop)
            stop_containers
            ;;
        restart)
            stop_containers
            start_containers
            ;;
        console)
            open_console
            ;;
        server)
            start_server
            ;;
        rake)
            shift
            run_rake "$@"
            ;;
        logs)
            shift
            show_logs "$@"
            ;;
        shell)
            open_shell
            ;;
        db:console)
            open_db_console
            ;;
        db:reset)
            reset_database
            ;;
        db:migrate)
            run_migrations
            ;;
        db:seed)
            seed_database
            ;;
        debug)
            start_debug_server
            ;;
        status)
            show_status
            ;;
        clean)
            clean_all
            ;;
        -h|--help|help|"")
            show_usage
            ;;
        *)
            print_error "Unbekannter Befehl: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Skript ausführen
main "$@" 