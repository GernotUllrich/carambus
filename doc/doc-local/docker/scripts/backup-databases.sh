#!/bin/bash

# Carambus Database Backup Script
# Erstellt Backups aller Datenbankvarianten mit strukturierter Organisation
#
# Verwendung:
#   ./backup-databases.sh                    # Backup aller Datenbanken
#   ./backup-databases.sh api-server         # Nur API Server
#   ./backup-databases.sh local-server       # Nur Local Server
#   ./backup-databases.sh location berlin    # Nur Location Berlin

set -e

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funktionen
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Konfiguration
BACKUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATABASES_DIR="$BACKUP_ROOT/databases"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Datenbank-Konfigurationen
declare -A DB_CONFIGS

# API Server Datenbanken
DB_CONFIGS["api_production"]="carambus_api_production"
DB_CONFIGS["api_development"]="carambus_api_development"

# Local Server Datenbanken
DB_CONFIGS["local_production"]="carambus_production"
DB_CONFIGS["local_development"]="carambus_development"

# Bekannte Locations (kann erweitert werden)
LOCATIONS=("berlin" "muenchen" "hamburg" "koeln" "frankfurt" "stuttgart" "dortmund" "essen" "leipzig" "bremen")

# Funktion: Backup einer einzelnen Datenbank
backup_database() {
    local db_name=$1
    local db_type=$2
    local location_code=$3
    
    print_status "Backup von Datenbank: $db_name"
    
    # Verzeichnis erstellen
    local backup_dir="$DATABASES_DIR/$db_type"
    if [ -n "$location_code" ]; then
        backup_dir="$DATABASES_DIR/locations/$location_code"
    fi
    
    mkdir -p "$backup_dir"
    
    # Backup-Dateiname
    local backup_file
    if [ -n "$location_code" ]; then
        backup_file="${db_name}_${location_code}_${TIMESTAMP}.sql.gz"
    else
        backup_file="${db_name}_${TIMESTAMP}.sql.gz"
    fi
    
    # Symlink für neuestes Backup
    local latest_link
    if [ -n "$location_code" ]; then
        latest_link="${db_name}_${location_code}.sql.gz"
    else
        latest_link="${db_name}.sql.gz"
    fi
    
    # PostgreSQL Backup erstellen
    print_status "Erstelle PostgreSQL Backup..."
    if pg_dump "$db_name" | gzip > "$backup_dir/$backup_file"; then
        print_status "Backup erfolgreich: $backup_file"
        
        # Symlink aktualisieren
        cd "$backup_dir"
        ln -sf "$backup_file" "$latest_link"
        cd - > /dev/null
        
        # Alte Backups aufräumen (behalte nur die letzten 5)
        cleanup_old_backups "$backup_dir" "$db_name" "$location_code"
    else
        print_error "Backup fehlgeschlagen für: $db_name"
        return 1
    fi
}

# Funktion: Alte Backups aufräumen
cleanup_old_backups() {
    local backup_dir=$1
    local db_name=$2
    local location_code=$3
    
    local pattern
    if [ -n "$location_code" ]; then
        pattern="${db_name}_${location_code}_*.sql.gz"
    else
        pattern="${db_name}_*.sql.gz"
    fi
    
    # Alle Backups außer dem neuesten Symlink auflisten und sortieren
    local old_backups
    old_backups=$(find "$backup_dir" -name "$pattern" -type f | grep -v "$(basename "$(readlink "$backup_dir/${db_name}${location_code:+.${location_code}}.sql.gz")")" | sort)
    
    # Anzahl der Backups zählen
    local backup_count=$(echo "$old_backups" | wc -l)
    
    if [ "$backup_count" -gt 5 ]; then
        print_status "Räume alte Backups auf (behalte nur die letzten 5)..."
        local to_delete
        to_delete=$(echo "$old_backups" | head -n $((backup_count - 5)))
        
        echo "$to_delete" | while read -r backup; do
            print_status "Lösche altes Backup: $(basename "$backup")"
            rm "$backup"
        done
    fi
}

# Funktion: Alle Datenbanken sichern
backup_all_databases() {
    print_header "Backup aller Datenbanken"
    
    # API Server
    print_header "API Server Datenbanken"
    for db_type in "api_production" "api_development"; do
        if [ -n "${DB_CONFIGS[$db_type]}" ]; then
            backup_database "${DB_CONFIGS[$db_type]}" "api-server"
        fi
    done
    
    # Local Server
    print_header "Local Server Datenbanken"
    for db_type in "local_production" "local_development"; do
        if [ -n "${DB_CONFIGS[$db_type]}" ]; then
            backup_database "${DB_CONFIGS[$db_type]}" "local-server"
        fi
    done
    
    # Location-spezifische Datenbanken
    print_header "Location-spezifische Datenbanken"
    for location in "${LOCATIONS[@]}"; do
        local db_name="carambus_production_${location}"
        # Prüfen ob Datenbank existiert
        if psql -lqt | cut -d \| -f 1 | grep -qw "$db_name"; then
            backup_database "$db_name" "locations" "$location"
        fi
    done
}

# Hauptfunktion
main() {
    local backup_type=${1:-all}
    local location_code=${2:-}
    
    print_header "Carambus Database Backup"
    print_status "Backup-Typ: $backup_type"
    if [ -n "$location_code" ]; then
        print_status "Location: $location_code"
    fi
    echo ""
    
    case $backup_type in
        "all")
            backup_all_databases
            ;;
        "api-server")
            print_header "API Server Datenbanken"
            for db_type in "api_production" "api_development"; do
                if [ -n "${DB_CONFIGS[$db_type]}" ]; then
                    backup_database "${DB_CONFIGS[$db_type]}" "api-server"
                fi
            done
            ;;
        "local-server")
            print_header "Local Server Datenbanken"
            for db_type in "local_production" "local_development"; do
                if [ -n "${DB_CONFIGS[$db_type]}" ]; then
                    backup_database "${DB_CONFIGS[$db_type]}" "local-server"
                fi
            done
            ;;
        "location")
            if [ -z "$location_code" ]; then
                print_error "Location-Code erforderlich für location-Backup"
                print_status "Verwendung: $0 location LOCATION_CODE"
                exit 1
            fi
            
            local db_name="carambus_production_${location_code}"
            if psql -lqt | cut -d \| -f 1 | grep -qw "$db_name"; then
                backup_database "$db_name" "locations" "$location_code"
            else
                print_error "Datenbank $db_name existiert nicht"
                exit 1
            fi
            ;;
        *)
            print_error "Unbekannter Backup-Typ: $backup_type"
            print_status "Verfügbare Typen: all, api-server, local-server, location"
            exit 1
            ;;
    esac
    
    print_header "Backup abgeschlossen"
    print_status "Alle Backups gespeichert in: $DATABASES_DIR"
}

# Script ausführen
main "$@" 