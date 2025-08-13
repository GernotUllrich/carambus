#!/bin/bash

# Carambus Database Migration Script
# Migriert bestehende Datenbank-Backups in die neue strukturierte Organisation
#
# Verwendung:
#   ./migrate-existing-databases.sh

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
OLD_BACKUP_DIR="$SCRIPT_ROOT"
NEW_DATABASES_DIR="$SCRIPT_ROOT/databases"

# Funktion: Bestehende Backups finden und kategorisieren
find_existing_backups() {
    print_status "Suche bestehende Datenbank-Backups..."
    
    local existing_backups=()
    
    # Alle .sql.gz Dateien im alten Verzeichnis finden
    while IFS= read -r -d '' file; do
        existing_backups+=("$file")
    done < <(find "$OLD_BACKUP_DIR" -maxdepth 1 -name "*.sql.gz" -print0)
    
    if [ ${#existing_backups[@]} -eq 0 ]; then
        print_warning "Keine bestehenden Backups gefunden"
        return
    fi
    
    print_status "Gefundene Backups:"
    for backup in "${existing_backups[@]}"; do
        local filename=$(basename "$backup")
        local size=$(du -h "$backup" | cut -f1)
        echo "  $filename ($size)"
    done
    echo ""
    
    return "${existing_backups[@]}"
}

# Funktion: Backup kategorisieren
categorize_backup() {
    local backup_file=$1
    local filename=$(basename "$backup_file")
    
    # API Server Backups
    if [[ "$filename" == *"api"* ]]; then
        if [[ "$filename" == *"development"* ]]; then
            echo "api-server"
        else
            echo "api-server"
        fi
    # Local Server Backups
    elif [[ "$filename" == *"production"* ]]; then
        # Location-spezifische Server prüfen
        for location in "berlin" "muenchen" "hamburg" "koeln" "frankfurt" "stuttgart" "dortmund" "essen" "leipzig" "bremen"; do
            if [[ "$filename" == *"$location"* ]]; then
                echo "locations/$location"
                return
            fi
        done
        echo "local-server"
    # Development Backups
    elif [[ "$filename" == *"development"* ]]; then
        echo "development"
    else
        echo "unknown"
    fi
}

# Funktion: Backup migrieren
migrate_backup() {
    local backup_file=$1
    local filename=$(basename "$backup_file")
    local category=$(categorize_backup "$backup_file")
    
    if [ "$category" = "unknown" ]; then
        print_warning "Unbekannte Kategorie für: $filename"
        return
    fi
    
    print_status "Migriere: $filename → $category"
    
    # Zielverzeichnis erstellen
    local target_dir="$NEW_DATABASES_DIR/$category"
    mkdir -p "$target_dir"
    
    # Backup kopieren
    if cp "$backup_file" "$target_dir/"; then
        print_status "  ✅ Erfolgreich migriert"
        
        # Symlink für neuestes Backup erstellen
        local base_name=$(echo "$filename" | sed 's/_[0-9]\{8\}_[0-9]\{6\}.*\.sql\.gz$/.sql.gz/')
        if [ "$base_name" != "$filename" ]; then
            cd "$target_dir"
            ln -sf "$filename" "$base_name"
            cd - > /dev/null
            print_status "  ✅ Symlink erstellt: $base_name"
        fi
    else
        print_error "  ❌ Migration fehlgeschlagen"
        return 1
    fi
}

# Funktion: Migration zusammenfassen
summarize_migration() {
    print_header "Migration abgeschlossen"
    
    echo ""
    print_status "Neue Verzeichnisstruktur:"
    tree "$NEW_DATABASES_DIR" 2>/dev/null || find "$NEW_DATABASES_DIR" -type f | sort
    
    echo ""
    print_status "Nächste Schritte:"
    echo "  1. Überprüfen Sie die neue Struktur: ./manage-databases.sh status"
    echo "  2. Testen Sie ein Backup: ./manage-databases.sh list"
    echo "  3. Erstellen Sie ein neues Backup: ./manage-databases.sh backup"
    echo "  4. Löschen Sie die alten Backups nach erfolgreicher Migration"
}

# Hauptfunktion
main() {
    print_header "Carambus Database Migration"
    print_status "Migriert bestehende Backups in die neue strukturierte Organisation"
    echo ""
    
    # Bestehende Backups finden
    local existing_backups
    mapfile -t existing_backups < <(find_existing_backups)
    
    if [ ${#existing_backups[@]} -eq 0 ]; then
        print_status "Keine Migration erforderlich"
        exit 0
    fi
    
    # Bestätigung anfordern
    print_warning "ACHTUNG: Dies wird die bestehenden Backups in die neue Struktur kopieren!"
    print_status "Alte Backups bleiben erhalten und können nach der Migration gelöscht werden."
    echo ""
    read -p "Möchten Sie mit der Migration fortfahren? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Migration abgebrochen"
        exit 0
    fi
    
    # Neue Verzeichnisstruktur erstellen
    print_status "Erstelle neue Verzeichnisstruktur..."
    mkdir -p "$NEW_DATABASES_DIR"/{api-server,local-server,development,locations}
    
    # Bekannte Locations erstellen
    for location in "berlin" "muenchen" "hamburg" "koeln" "frankfurt" "stuttgart" "dortmund" "essen" "leipzig" "bremen"; do
        mkdir -p "$NEW_DATABASES_DIR/locations/$location"
    done
    
    # Alle Backups migrieren
    print_header "Starte Migration..."
    local success_count=0
    local total_count=${#existing_backups[@]}
    
    for backup in "${existing_backups[@]}"; do
        if migrate_backup "$backup"; then
            ((success_count++))
        fi
    done
    
    echo ""
    print_status "Migration abgeschlossen: $success_count/$total_count erfolgreich"
    
    # Zusammenfassung anzeigen
    summarize_migration
}

# Script ausführen
main "$@" 