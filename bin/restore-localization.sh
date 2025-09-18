#!/bin/bash
# Carambus Localization Restore Script
# Stellt ein Backup der lokalen Konfiguration und Daten wieder her

set -e  # Exit on any error

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktion
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Variablen
BACKUP_DIR="/opt/carambus/backup"
RESTORE_DIR="/tmp/carambus_restore_$$"

# Prüfung der Voraussetzungen
check_prerequisites() {
    log "Prüfe Voraussetzungen..."
    
    # Prüfe Backup-Datei
    if [ $# -eq 0 ]; then
        error "Bitte geben Sie eine Backup-Datei an: $0 <backup_file.tar.gz>"
    fi
    
    BACKUP_FILE="$1"
    if [ ! -f "$BACKUP_FILE" ]; then
        error "Backup-Datei nicht gefunden: $BACKUP_FILE"
    fi
    
    # Prüfe ob es sich um eine gültige Backup-Datei handelt
    if ! tar -tzf "$BACKUP_FILE" | grep -q "localization.json"; then
        error "Ungültige Backup-Datei: $BACKUP_FILE"
    fi
    
    # Prüfe verfügbaren Speicherplatz
    available_space=$(df /tmp | awk 'NR==2 {print $4}')
    backup_size=$(stat -c%s "$BACKUP_FILE")
    if [ "$available_space" -lt "$backup_size" ]; then
        error "Nicht genügend Speicherplatz für Restore verfügbar"
    fi
    
    # Prüfe ob Carambus läuft
    if ! curl -s http://localhost:3000/health > /dev/null; then
        warning "Carambus ist nicht erreichbar. Restore wird trotzdem fortgesetzt."
    fi
    
    log "Voraussetzungen erfüllt"
}

# Backup extrahieren
extract_backup() {
    log "Extrahiere Backup..."
    
    # Restore-Verzeichnis erstellen
    mkdir -p "$RESTORE_DIR"
    
    # Backup extrahieren
    tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"
    
    # Prüfe ob alle erwarteten Dateien vorhanden sind
    expected_files=(
        "*_database.sql"
        "*_config.tar.gz"
        "*_localization.json"
        "*_system_info.txt"
    )
    
    for pattern in "${expected_files[@]}"; do
        if ! ls "$RESTORE_DIR"/$pattern > /dev/null 2>&1; then
            error "Backup-Datei fehlt: $pattern"
        fi
    done
    
    log "Backup erfolgreich extrahiert"
}

# Datenbank wiederherstellen
restore_database() {
    log "Stelle Datenbank wieder her..."
    
    # Datenbank-Datei finden
    DB_FILE=$(ls "$RESTORE_DIR"/*_database.sql | head -1)
    
    if [ ! -f "$DB_FILE" ]; then
        error "Datenbank-Backup-Datei nicht gefunden"
    fi
    
    # Carambus stoppen
    if [ -d "/opt/carambus" ]; then
        cd /opt/carambus
        docker-compose stop app
    fi
    
    # Datenbank wiederherstellen
    if command -v psql > /dev/null 2>&1; then
        # Direkte PostgreSQL-Wiederherstellung
        psql -Uwww_data -d carambus_production -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
        psql -Uwww_data carambus_production < "$DB_FILE"
    else
        # Docker-Container Wiederherstellung
        docker-compose exec -T db psql -Uwww_data -d carambus_production -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
        docker-compose exec -T db psql -Uwww_data carambus_production < "$DB_FILE"
    fi
    
    log "Datenbank erfolgreich wiederhergestellt"
}

# Konfiguration wiederherstellen
restore_configuration() {
    log "Stelle Konfiguration wieder her..."
    
    # Konfigurations-Backup finden
    CONFIG_FILE=$(ls "$RESTORE_DIR"/*_config.tar.gz | head -1)
    
    if [ ! -f "$CONFIG_FILE" ]; then
        error "Konfigurations-Backup-Datei nicht gefunden"
    fi
    
    # Konfigurations-Verzeichnis erstellen
    mkdir -p "$RESTORE_DIR/config"
    
    # Konfiguration extrahieren
    tar -xzf "$CONFIG_FILE" -C "$RESTORE_DIR/config"
    
    # Konfigurationsdateien wiederherstellen
    if [ -d "/opt/carambus" ]; then
        for file in "$RESTORE_DIR/config"/*; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                cp "$file" "/opt/carambus/config/$filename"
                log "Konfigurationsdatei wiederhergestellt: $filename"
            fi
        done
    else
        warning "Carambus-Verzeichnis nicht gefunden, Konfiguration nicht wiederhergestellt"
    fi
    
    log "Konfiguration erfolgreich wiederhergestellt"
}

# Lokalisierungs-Daten importieren
import_localization_data() {
    log "Importiere Lokalisierungs-Daten..."
    
    # Lokalisierungs-JSON finden
    LOCALIZATION_FILE=$(ls "$RESTORE_DIR"/*_localization.json | head -1)
    
    if [ ! -f "$LOCALIZATION_FILE" ]; then
        error "Lokalisierungs-Datei nicht gefunden"
    fi
    
    # Rails-Runner für Datenimport
    cat > /tmp/import_localization.rb << 'EOF'
# Lokalisierungs-Daten Import Script
require 'json'

# Lokalisierungs-Daten lesen
localization_data = JSON.parse(File.read('/tmp/localization_data.json'))

puts "Importiere Lokalisierungs-Daten..."

# Location-Daten importieren
if localization_data['location'] && !localization_data['location'].empty?
  location_data = localization_data['location']
  
  # Location erstellen oder aktualisieren
  location = Location.find_or_initialize_by(id: location_data['id'])
  location.assign_attributes(
    name: location_data['name'],
    club_id: location_data['club_id'],
    region_id: location_data['region_id'],
    address: location_data['address'],
    phone: location_data['phone'],
    email: location_data['email']
  )
  location.save!
  puts "Location importiert: #{location.name}"
end

# Tisch-Daten importieren
if localization_data['tables'] && !localization_data['tables'].empty?
  localization_data['tables'].each do |table_data|
    table = Table.find_or_initialize_by(id: table_data['id'])
    table.assign_attributes(
      name: table_data['name'],
      table_kind_id: table_data['table_kind_id'],
      location_id: table_data['location_id'],
      position: table_data['position'],
      remarks: table_data['remarks']
    )
    table.save!
    puts "Tisch importiert: #{table.name}"
  end
end

# Benutzer-Daten importieren (nur lokale Benutzer)
if localization_data['users'] && !localization_data['users'].empty?
  localization_data['users'].each do |user_data|
    user = User.find_or_initialize_by(id: user_data['id'])
    user.assign_attributes(
      name: user_data['name'],
      email: user_data['email'],
      admin: user_data['admin'],
      confirmed_at: user_data['confirmed_at'] ? Time.parse(user_data['confirmed_at']) : nil
    )
    user.save!
    puts "Benutzer importiert: #{user.name}"
  end
end

# Settings importieren
if localization_data['settings'] && !localization_data['settings'].empty?
  localization_data['settings'].each do |key, value|
    setting = Setting.find_or_initialize_by(key: key)
    setting.value = value
    setting.save!
    puts "Setting importiert: #{key}"
  end
end

puts "Lokalisierungs-Daten erfolgreich importiert"
EOF

    # Lokalisierungs-Daten kopieren
    cp "$LOCALIZATION_FILE" /tmp/localization_data.json
    
    # Rails-Runner ausführen
    if [ -d "/opt/carambus" ]; then
        cd /opt/carambus
        docker-compose exec -T app rails runner /tmp/import_localization.rb
    else
        # Fallback für nicht-Docker Installation
        rails runner /tmp/import_localization.rb
    fi
    
    log "Lokalisierungs-Daten erfolgreich importiert"
}

# System-Informationen anzeigen
show_system_info() {
    log "Zeige System-Informationen aus Backup..."
    
    # System-Info-Datei finden
    SYSTEM_INFO_FILE=$(ls "$RESTORE_DIR"/*_system_info.txt | head -1)
    
    if [ -f "$SYSTEM_INFO_FILE" ]; then
        echo ""
        echo "System-Informationen aus Backup:"
        echo "================================"
        cat "$SYSTEM_INFO_FILE"
        echo ""
    fi
}

# Carambus neu starten
restart_carambus() {
    log "Starte Carambus neu..."
    
    if [ -d "/opt/carambus" ]; then
        cd /opt/carambus
        
        # Container neu starten
        docker-compose up -d
        
        # Warten bis Services verfügbar sind
        log "Warte auf Services..."
        while ! curl -s http://localhost:3000/health > /dev/null; do
            sleep 5
        done
        
        log "Carambus erfolgreich neu gestartet"
    else
        warning "Carambus-Verzeichnis nicht gefunden, Neustart übersprungen"
    fi
}

# Scoreboard neu starten
restart_scoreboard() {
    log "Starte Scoreboard neu..."
    
    # Scoreboard-Service neu starten
    if systemctl is-active --quiet scoreboard; then
        sudo systemctl restart scoreboard
        log "Scoreboard erfolgreich neu gestartet"
    else
        warning "Scoreboard-Service nicht gefunden"
    fi
}

# Restore-Validierung
validate_restore() {
    log "Validiere Restore..."
    
    # Prüfe ob Carambus erreichbar ist
    if ! curl -s http://localhost:3000/health > /dev/null; then
        warning "Carambus ist nach Restore nicht erreichbar"
    else
        log "Carambus ist erreichbar"
    fi
    
    # Prüfe Datenbank-Verbindung
    if [ -d "/opt/carambus" ]; then
        cd /opt/carambus
        if docker-compose exec -T db psql -Uwww_data -d carambus_production -c "SELECT COUNT(*) FROM users;" > /dev/null 2>&1; then
            log "Datenbank-Verbindung erfolgreich"
        else
            warning "Datenbank-Verbindung fehlgeschlagen"
        fi
    fi
    
    log "Restore-Validierung abgeschlossen"
}

# Cleanup
cleanup() {
    log "Führe Cleanup durch..."
    
    # Restore-Verzeichnis löschen
    rm -rf "$RESTORE_DIR"
    
    # Temporäre Dateien löschen
    rm -f /tmp/import_localization.rb
    rm -f /tmp/localization_data.json
    
    log "Cleanup abgeschlossen"
}

# Restore-Informationen anzeigen
show_restore_info() {
    log "Restore-Informationen:"
    echo "====================="
    echo "Backup-Datei: $BACKUP_FILE"
    echo "Restore-Datum: $(date)"
    echo ""
    echo "Wiederhergestellt:"
    echo "- Datenbank"
    echo "- Konfiguration"
    echo "- Lokalisierungs-Daten"
    echo ""
    echo "Nächste Schritte:"
    echo "1. Prüfen Sie http://localhost:3000"
    echo "2. Testen Sie das Scoreboard"
    echo "3. Überprüfen Sie die Benutzer-Anmeldung"
}

# Hauptfunktion
main() {
    log "Starte Carambus Lokalisierungs-Restore..."
    
    check_prerequisites "$@"
    extract_backup
    restore_database
    restore_configuration
    import_localization_data
    show_system_info
    restart_carambus
    restart_scoreboard
    validate_restore
    show_restore_info
    cleanup
    
    log "Restore erfolgreich abgeschlossen!"
}

# Script ausführen
main "$@" 