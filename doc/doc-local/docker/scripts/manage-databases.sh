#!/bin/bash

# Carambus Database Management Script
# Zentrale Verwaltung aller Datenbankvarianten
#
# Verwendung:
#   ./manage-databases.sh status                    # Status aller Datenbanken
#   ./manage-databases.sh backup [type]            # Backup erstellen
#   ./manage-databases.sh restore [type] [db]      # Datenbank wiederherstellen
#   ./manage-databases.sh list                     # Alle Backups auflisten
#   ./manage-databases.sh cleanup                  # Alte Backups aufräumen
#   ./manage-databases.sh migrate [type] [db]      # Datenbank-Migration

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
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATABASES_DIR="$SCRIPT_ROOT/databases"
BACKUP_SCRIPT="$SCRIPT_ROOT/scripts/backup-databases.sh"
RESTORE_SCRIPT="$SCRIPT_ROOT/scripts/restore-databases.sh"

# Datenbank-Konfigurationen
declare -A DB_CONFIGS

# API Server Datenbanken
DB_CONFIGS["api_production"]="carambus_api_production"
DB_CONFIGS["api_development"]="carambus_api_development"

# Local Server Datenbanken
DB_CONFIGS["local_production"]="carambus_production"
DB_CONFIGS["local_development"]="carambus_development"

# Bekannte Locations
LOCATIONS=("berlin" "muenchen" "hamburg" "koeln" "frankfurt" "stuttgart" "dortmund" "essen" "leipzig" "bremen")

# Funktion: Status aller Datenbanken anzeigen
show_database_status() {
    print_header "Datenbank-Status"
    
    # PostgreSQL-Verbindung prüfen
    if ! command -v psql >/dev/null 2>&1; then
        print_error "PostgreSQL-Client nicht gefunden"
        return 1
    fi
    
    # Alle Datenbanken auflisten
    print_status "Verfügbare Datenbanken:"
    echo ""
    
    # API Server Datenbanken
    print_header "API Server"
    for db_type in "api_production" "api_development"; do
        local db_name="${DB_CONFIGS[$db_type]}"
        if psql -lqt | cut -d \| -f 1 | grep -qw "$db_name"; then
            local size=$(psql "$db_name" -t -c "SELECT pg_size_pretty(pg_database_size('$db_name'));" | xargs)
            local tables=$(psql "$db_name" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
            echo "  ✅ $db_name ($size, $tables Tabellen)"
        else
            echo "  ❌ $db_name (nicht vorhanden)"
        fi
    done
    
    # Local Server Datenbanken
    print_header "Local Server"
    for db_type in "local_production" "local_development"; do
        local db_name="${DB_CONFIGS[$db_type]}"
        if psql -lqt | cut -d \| -f 1 | grep -qw "$db_name"; then
            local size=$(psql "$db_name" -t -c "SELECT pg_size_pretty(pg_database_size('$db_name'));" | xargs)
            local tables=$(psql "$db_name" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
            echo "  ✅ $db_name ($size, $tables Tabellen)"
        else
            echo "  ❌ $db_name (nicht vorhanden)"
        fi
    done
    
    # Location-spezifische Datenbanken
    print_header "Location-spezifische Server"
    for location in "${LOCATIONS[@]}"; do
        local db_name="carambus_production_${location}"
        if psql -lqt | cut -d \| -f 1 | grep -qw "$db_name"; then
            local size=$(psql "$db_name" -t -c "SELECT pg_size_pretty(pg_database_size('$db_name'));" | xargs)
            local tables=$(psql "$db_name" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
            
            # Lokale Erweiterungen prüfen
            local local_extensions
            local_extensions=$(psql "$db_name" -t -c "SELECT COUNT(*) FROM (SELECT unnest(ARRAY(SELECT table_name FROM information_schema.tables WHERE table_schema = 'public')) AS table_name) t WHERE EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = t.table_name AND column_name = 'id' AND data_type = 'bigint') AND EXISTS (SELECT 1 FROM (SELECT table_name, MAX(id) as max_id FROM (SELECT table_name, id FROM (SELECT unnest(ARRAY(SELECT table_name FROM information_schema.tables WHERE table_schema = 'public')) AS table_name) t2, (SELECT table_name, id FROM (SELECT unnest(ARRAY(SELECT table_name FROM information_schema.tables WHERE table_schema = 'public')) AS table_name) t3 WHERE t2.table_name = t3.table_name AND t3.id > 50000000) t4 GROUP BY table_name) t5 WHERE t5.table_name = t.table_name AND t5.max_id > 50000000;" | xargs)
            
            if [ "$local_extensions" -gt 0 ]; then
                echo "  ✅ $db_name ($size, $tables Tabellen, $local_extensions lokale Erweiterungen)"
            else
                echo "  ✅ $db_name ($size, $tables Tabellen)"
            fi
        else
            echo "  ❌ $db_name (nicht vorhanden)"
        fi
    done
}

# Funktion: Alle Backups auflisten
list_all_backups() {
    print_header "Verfügbare Backups"
    
    if [ ! -d "$DATABASES_DIR" ]; then
        print_warning "Backup-Verzeichnis nicht gefunden: $DATABASES_DIR"
        return
    fi
    
    # API Server Backups
    print_header "API Server Backups"
    for db_type in "api-server" "local-server" "development"; do
        local backup_dir="$DATABASES_DIR/$db_type"
        if [ -d "$backup_dir" ]; then
            echo "  $db_type:"
            local backups
            backups=$(find "$backup_dir" -name "*.sql.gz" -type f | sort -r | head -n 3)
            if [ -n "$backups" ]; then
                echo "$backups" | while read -r backup; do
                    local filename=$(basename "$backup")
                    local size=$(du -h "$backup" | cut -f1)
                    local date=$(stat -c %y "$backup" | cut -d' ' -f1)
                    echo "    $filename ($size, $date)"
                done
            else
                echo "    Keine Backups gefunden"
            fi
        fi
    done
    
    # Location-spezifische Backups
    print_header "Location-spezifische Backups"
    for location in "${LOCATIONS[@]}"; do
        local backup_dir="$DATABASES_DIR/locations/$location"
        if [ -d "$backup_dir" ]; then
            echo "  $location:"
            local backups
            backups=$(find "$backup_dir" -name "*.sql.gz" -type f | sort -r | head -n 3)
            if [ -n "$backups" ]; then
                echo "$backups" | while read -r backup; do
                    local filename=$(basename "$backup")
                    local size=$(du -h "$backup" | cut -f1)
                    local date=$(stat -c %y "$backup" | cut -d' ' -f1)
                    echo "    $filename ($size, $date)"
                done
            else
                echo "    Keine Backups gefunden"
            fi
        fi
    done
}

# Funktion: Alte Backups aufräumen
cleanup_old_backups() {
    print_header "Räume alte Backups auf"
    
    if [ ! -d "$DATABASES_DIR" ]; then
        print_warning "Backup-Verzeichnis nicht gefunden: $DATABASES_DIR"
        return
    fi
    
    # Alle Backup-Verzeichnisse durchgehen
    find "$DATABASES_DIR" -type d -name "*" | while read -r backup_dir; do
        if [ "$backup_dir" = "$DATABASES_DIR" ]; then
            continue
        fi
        
        echo "Prüfe Verzeichnis: $backup_dir"
        
        # Alle .sql.gz Dateien außer den neuesten 5 löschen
        local files
        files=$(find "$backup_dir" -name "*.sql.gz" -type f | sort -r)
        local file_count=$(echo "$files" | wc -l)
        
        if [ "$file_count" -gt 5 ]; then
            local to_delete
            to_delete=$(echo "$files" | tail -n +6)
            
            echo "$to_delete" | while read -r file; do
                if [ -n "$file" ]; then
                    print_status "Lösche altes Backup: $(basename "$file")"
                    rm "$file"
                fi
            done
        fi
    done
    
    print_status "Aufräumen abgeschlossen"
}

# Funktion: Datenbank-Migration
migrate_database() {
    local db_type=$1
    local db_name=$2
    
    if [ -z "$db_type" ] || [ -z "$db_name" ]; then
        print_error "Verwendung: $0 migrate <db_type> <db_name>"
        exit 1
    fi
    
    print_header "Migration: $db_name"
    
    # Prüfen ob Datenbank existiert
    if ! psql -lqt | cut -d \| -f 1 | grep -qw "$db_name"; then
        print_error "Datenbank $db_name existiert nicht"
        exit 1
    fi
    
    # Rails-Umgebung setzen
    export RAILS_ENV=production
    
    # Migration ausführen
    print_status "Führe Rails-Migrationen aus..."
    if bundle exec rails db:migrate; then
        print_status "Migration erfolgreich abgeschlossen"
    else
        print_error "Migration fehlgeschlagen"
        exit 1
    fi
    
    # Datenbank-Status anzeigen
    print_status "Neuer Datenbank-Status:"
    local size=$(psql "$db_name" -t -c "SELECT pg_size_pretty(pg_database_size('$db_name'));" | xargs)
    local tables=$(psql "$db_name" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
    echo "  $db_name ($size, $tables Tabellen)"
}

# Hauptfunktion
main() {
    local action=${1:-status}
    local param1=${2:-}
    local param2=${3:-}
    
    print_header "Carambus Database Management"
    print_status "Aktion: $action"
    echo ""
    
    case $action in
        "status")
            show_database_status
            ;;
        "backup")
            if [ -n "$param1" ]; then
                print_status "Führe Backup aus: $param1"
                "$BACKUP_SCRIPT" "$param1"
            else
                print_status "Führe Backup aller Datenbanken aus"
                "$BACKUP_SCRIPT"
            fi
            ;;
        "restore")
            if [ -n "$param1" ] && [ -n "$param2" ]; then
                print_status "Führe Restore aus: $param1 $param2"
                "$RESTORE_SCRIPT" "$param1" "$param2"
            else
                print_error "Verwendung: $0 restore <db_type> <db_name>"
                exit 1
            fi
            ;;
        "list")
            list_all_backups
            ;;
        "cleanup")
            cleanup_old_backups
            ;;
        "migrate")
            migrate_database "$param1" "$param2"
            ;;
        *)
            print_error "Unbekannte Aktion: $action"
            echo ""
            echo "Verfügbare Aktionen:"
            echo "  status                    - Status aller Datenbanken anzeigen"
            echo "  backup [type]             - Backup erstellen"
            echo "  restore <type> <db>       - Datenbank wiederherstellen"
            echo "  list                      - Alle Backups auflisten"
            echo "  cleanup                   - Alte Backups aufräumen"
            echo "  migrate <type> <db>       - Datenbank-Migration"
            echo ""
            echo "Beispiele:"
            echo "  $0 status"
            echo "  $0 backup api-server"
            echo "  $0 restore local-server carambus_production"
            echo "  $0 restore location berlin carambus_production_berlin"
            echo "  $0 migrate local-server carambus_production"
            exit 1
            ;;
    esac
    
    print_header "Aktion abgeschlossen"
}

# Script ausführen
main "$@" 