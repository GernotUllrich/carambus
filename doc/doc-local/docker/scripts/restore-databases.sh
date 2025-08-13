#!/bin/bash

# Carambus Database Restore Script
# Stellt Datenbankvarianten aus strukturierten Backups wieder her
#
# Verwendung:
#   ./restore-databases.sh api-server carambus_api_production
#   ./restore-databases.sh local-server carambus_production
#   ./restore-databases.sh location berlin carambus_production_berlin
#   ./restore-databases.sh development carambus_development

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

# Funktion: Datenbank wiederherstellen
restore_database() {
    local db_type=$1
    local db_name=$2
    local backup_file=$3
    local location_code=$4
    
    print_header "Wiederherstellung: $db_name"
    
    # Backup-Datei finden
    local backup_path
    if [ -n "$location_code" ]; then
        backup_path="$DATABASES_DIR/locations/$location_code/$backup_file"
    else
        backup_path="$DATABASES_DIR/$db_type/$backup_file"
    fi
    
    if [ ! -f "$backup_path" ]; then
        print_error "Backup-Datei nicht gefunden: $backup_path"
        return 1
    fi
    
    print_status "Verwende Backup: $backup_file"
    print_status "Größe: $(du -h "$backup_path" | cut -f1)"
    
    # Bestehende Verbindungen beenden
    print_status "Beende bestehende Verbindungen zur Datenbank..."
    psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$db_name' AND pid <> pg_backend_pid();" postgres 2>/dev/null || true
    
    # Datenbank löschen falls vorhanden
    if psql -lqt | cut -d \| -f 1 | grep -qw "$db_name"; then
        print_warning "Lösche bestehende Datenbank: $db_name"
        dropdb "$db_name"
    fi
    
    # Neue Datenbank erstellen
    print_status "Erstelle neue Datenbank: $db_name"
    createdb "$db_name"
    
    # Daten wiederherstellen
    print_status "Stelle Daten wieder her..."
    if gunzip -c "$backup_path" | psql "$db_name"; then
        print_status "Datenbank erfolgreich wiederhergestellt: $db_name"
        
        # Statistiken anzeigen
        print_status "Datenbank-Statistiken:"
        psql "$db_name" -c "SELECT schemaname, tablename, n_tup_ins as inserts, n_tup_upd as updates, n_tup_del as deletes FROM pg_stat_user_tables ORDER BY n_tup_ins + n_tup_upd + n_tup_del DESC LIMIT 10;"
        
        # Lokale Erweiterungen prüfen (für location-spezifische Server)
        if [ -n "$location_code" ]; then
            print_status "Prüfe lokale Erweiterungen (id > 50000000)..."
            local local_records
            local_records=$(psql "$db_name" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
            if [ "$local_records" -gt 0 ]; then
                local local_extensions
                local_extensions=$(psql "$db_name" -t -c "SELECT COUNT(*) FROM (SELECT unnest(ARRAY(SELECT table_name FROM information_schema.tables WHERE table_schema = 'public')) AS table_name) t WHERE EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = t.table_name AND column_name = 'id' AND data_type = 'bigint') AND EXISTS (SELECT 1 FROM (SELECT table_name, MAX(id) as max_id FROM (SELECT table_name, id FROM (SELECT unnest(ARRAY(SELECT table_name FROM information_schema.tables WHERE table_schema = 'public')) AS table_name) t2, (SELECT table_name, id FROM (SELECT unnest(ARRAY(SELECT table_name FROM information_schema.tables WHERE table_schema = 'public')) AS table_name) t3 WHERE t2.table_name = t3.table_name AND t3.id > 50000000) t4 GROUP BY table_name) t5 WHERE t5.table_name = t.table_name AND t5.max_id > 50000000;" | xargs)
                print_status "Lokale Erweiterungen gefunden: $local_extensions Tabellen mit id > 50000000"
            fi
        fi
        
    else
        print_error "Wiederherstellung fehlgeschlagen für: $db_name"
        return 1
    fi
}

# Funktion: Verfügbare Backups auflisten
list_available_backups() {
    local db_type=$1
    local location_code=$2
    
    print_header "Verfügbare Backups für $db_type"
    
    local backup_dir
    if [ -n "$location_code" ]; then
        backup_dir="$DATABASES_DIR/locations/$location_code"
    else
        backup_dir="$DATABASES_DIR/$db_type"
    fi
    
    if [ ! -d "$backup_dir" ]; then
        print_warning "Kein Backup-Verzeichnis gefunden: $backup_dir"
        return
    fi
    
    echo "Verzeichnis: $backup_dir"
    echo ""
    
    # Alle Backups auflisten
    local backups
    backups=$(find "$backup_dir" -name "*.sql.gz" -type f | sort -r)
    
    if [ -z "$backups" ]; then
        print_warning "Keine Backups gefunden"
        return
    fi
    
    echo "Verfügbare Backups:"
    echo "$backups" | while read -r backup; do
        local filename=$(basename "$backup")
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -c %y "$backup" | cut -d' ' -f1)
        echo "  $filename ($size, $date)"
    done
}

# Hauptfunktion
main() {
    local db_type=${1:-}
    local db_name=${2:-}
    local backup_file=${3:-}
    local location_code=${4:-}
    
    print_header "Carambus Database Restore"
    
    # Parameter validieren
    if [ -z "$db_type" ] || [ -z "$db_name" ]; then
        print_error "Verwendung: $0 <db_type> <db_name> [backup_file] [location_code]"
        echo ""
        echo "Beispiele:"
        echo "  $0 api-server carambus_api_production"
        echo "  $0 local-server carambus_production"
        echo "  $0 location berlin carambus_production_berlin"
        echo "  $0 development carambus_development"
        echo ""
        echo "Verfügbare db_types:"
        echo "  api-server, local-server, development, location"
        exit 1
    fi
    
    # Location-spezifische Server
    if [ "$db_type" = "location" ]; then
        if [ -z "$location_code" ]; then
            print_error "Location-Code erforderlich für location-Restore"
            print_status "Verwendung: $0 location <location_code> <db_name>"
            exit 1
        fi
        location_code=$db_name
        db_name=$backup_file
        backup_file=$3
    fi
    
    print_status "Datenbank-Typ: $db_type"
    print_status "Datenbank-Name: $db_name"
    if [ -n "$location_code" ]; then
        print_status "Location-Code: $location_code"
    fi
    echo ""
    
    # Bestätigung anfordern
    print_warning "ACHTUNG: Dies wird die bestehende Datenbank '$db_name' überschreiben!"
    read -p "Möchten Sie fortfahren? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Restore abgebrochen"
        exit 0
    fi
    
    # Backup-Datei bestimmen
    if [ -z "$backup_file" ]; then
        # Neuestes Backup verwenden
        local backup_dir
        if [ -n "$location_code" ]; then
            backup_dir="$DATABASES_DIR/locations/$location_code"
        else
            backup_dir="$DATABASES_DIR/$db_type"
        fi
        
        if [ -d "$backup_dir" ]; then
            backup_file=$(find "$backup_dir" -name "*.sql.gz" -type f | sort -r | head -n1 | xargs basename)
            if [ -n "$backup_file" ]; then
                print_status "Verwende neuestes Backup: $backup_file"
            else
                print_error "Kein Backup gefunden in: $backup_dir"
                exit 1
            fi
        else
            print_error "Backup-Verzeichnis nicht gefunden: $backup_dir"
            exit 1
        fi
    fi
    
    # Verfügbare Backups anzeigen
    list_available_backups "$db_type" "$location_code"
    echo ""
    
    # Datenbank wiederherstellen
    if restore_database "$db_type" "$db_name" "$backup_file" "$location_code"; then
        print_header "Restore erfolgreich abgeschlossen"
        print_status "Datenbank: $db_name"
        print_status "Backup: $backup_file"
    else
        print_error "Restore fehlgeschlagen"
        exit 1
    fi
}

# Script ausführen
main "$@" 