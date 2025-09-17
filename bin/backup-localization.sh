#!/bin/bash
# Carambus Localization Backup Script
# Erstellt ein vollständiges Backup der lokalen Konfiguration und Daten

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
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="carambus_localization_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

# Prüfung der Voraussetzungen
check_prerequisites() {
    log "Prüfe Voraussetzungen..."
    
    # Prüfe ob Carambus läuft
    if ! curl -s http://localhost:3000/health > /dev/null; then
        error "Carambus ist nicht erreichbar. Bitte starten Sie den Service zuerst."
    fi
    
    # Prüfe Backup-Verzeichnis
    if [ ! -d "$BACKUP_DIR" ]; then
        log "Erstelle Backup-Verzeichnis..."
        sudo mkdir -p "$BACKUP_DIR"
        sudo chown $USER:$USER "$BACKUP_DIR"
    fi
    
    # Prüfe verfügbaren Speicherplatz
    available_space=$(df "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 1000000 ]; then
        error "Nicht genügend Speicherplatz für Backup verfügbar (mindestens 1GB erforderlich)"
    fi
    
    log "Voraussetzungen erfüllt"
}

# Datenbank-Backup erstellen
backup_database() {
    log "Erstelle Datenbank-Backup..."
    
    # PostgreSQL-Backup
    if command -v pg_dump > /dev/null 2>&1; then
        pg_dump -Uwww_data carambus_production > "${BACKUP_PATH}_database.sql"
        log "Datenbank-Backup erstellt: ${BACKUP_PATH}_database.sql"
    else
        # Docker-Container Backup
        docker-compose exec -T db pg_dump -Uwww_data carambus_production > "${BACKUP_PATH}_database.sql"
        log "Datenbank-Backup aus Docker-Container erstellt: ${BACKUP_PATH}_database.sql"
    fi
}

# Konfigurations-Backup erstellen
backup_configuration() {
    log "Erstelle Konfigurations-Backup..."
    
    # Konfigurationsdateien sammeln
    CONFIG_FILES=(
        "config/carambus.yml"
        "config/database.yml"
        "config/scoreboard_url"
        "config/credentials/production.key"
        "config/credentials/production.yml.enc"
        "config/environments/production.rb"
        "config/puma.rb"
    )
    
    # Backup-Verzeichnis erstellen
    mkdir -p "${BACKUP_PATH}_config"
    
    # Dateien kopieren
    for file in "${CONFIG_FILES[@]}"; do
        if [ -f "/opt/carambus/$file" ]; then
            cp "/opt/carambus/$file" "${BACKUP_PATH}_config/"
            log "Konfigurationsdatei gesichert: $file"
        else
            warning "Konfigurationsdatei nicht gefunden: $file"
        fi
    done
    
    # Konfigurations-Backup komprimieren
    tar -czf "${BACKUP_PATH}_config.tar.gz" -C "${BACKUP_PATH}_config" .
    rm -rf "${BACKUP_PATH}_config"
    log "Konfigurations-Backup erstellt: ${BACKUP_PATH}_config.tar.gz"
}

# Lokalisierungs-Daten exportieren
export_localization_data() {
    log "Exportiere Lokalisierungs-Daten..."
    
    # Rails-Runner für Datenexport
    cat > /tmp/export_localization.rb << 'EOF'
# Lokalisierungs-Daten Export Script
require 'json'

localization_data = {
  timestamp: Time.now.iso8601,
  location: {},
  tables: [],
  users: [],
  settings: {}
}

# Location-Daten exportieren
if defined?(Location) && Location.exists?
  location = Location.first
  localization_data[:location] = {
    id: location.id,
    name: location.name,
    club_id: location.club_id,
    region_id: location.region_id,
    address: location.address,
    phone: location.phone,
    email: location.email
  }
end

# Tisch-Daten exportieren
if defined?(Table) && Table.exists?
  Table.all.each do |table|
    localization_data[:tables] << {
      id: table.id,
      name: table.name,
      table_kind_id: table.table_kind_id,
      location_id: table.location_id,
      position: table.position,
      remarks: table.remarks
    }
  end
end

# Benutzer-Daten exportieren (nur lokale Benutzer)
if defined?(User) && User.exists?
  User.where("id > 50000000").each do |user|
    localization_data[:users] << {
      id: user.id,
      name: user.name,
      email: user.email,
      admin: user.admin,
      confirmed_at: user.confirmed_at&.iso8601
    }
  end
end

# Settings exportieren
if defined?(Setting)
  Setting.all.each do |setting|
    localization_data[:settings][setting.key] = setting.value
  end
end

# JSON-Datei schreiben
File.write('/tmp/localization_data.json', JSON.pretty_generate(localization_data))
puts "Lokalisierungs-Daten exportiert: /tmp/localization_data.json"
EOF

    # Rails-Runner ausführen
    if [ -d "/opt/carambus" ]; then
        cd /opt/carambus
        docker-compose exec -T app rails runner /tmp/export_localization.rb
        docker-compose exec -T app cat /tmp/localization_data.json > "${BACKUP_PATH}_localization.json"
    else
        # Fallback für nicht-Docker Installation
        rails runner /tmp/export_localization.rb
        cp /tmp/localization_data.json "${BACKUP_PATH}_localization.json"
    fi
    
    log "Lokalisierungs-Daten exportiert: ${BACKUP_PATH}_localization.json"
}

# System-Informationen sammeln
collect_system_info() {
    log "Sammle System-Informationen..."
    
    cat > "${BACKUP_PATH}_system_info.txt" << EOF
Carambus Backup System-Informationen
====================================
Datum: $(date)
Hostname: $(hostname)
IP-Adresse: $(hostname -I)
Betriebssystem: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)
Speicherplatz: $(df -h / | tail -1)
Docker-Version: $(docker --version 2>/dev/null || echo "Docker nicht installiert")
Docker-Compose-Version: $(docker-compose --version 2>/dev/null || echo "Docker-Compose nicht installiert")

Carambus-Konfiguration:
======================
$(cat /opt/carambus/config/carambus.yml 2>/dev/null || echo "Konfigurationsdatei nicht gefunden")

Datenbank-Status:
=================
$(docker-compose exec -T db psql -Uwww_data -d carambus_production -c "SELECT version();" 2>/dev/null || echo "Datenbank nicht erreichbar")

Container-Status:
================
$(docker-compose ps 2>/dev/null || echo "Docker-Compose nicht verfügbar")
EOF

    log "System-Informationen gesammelt: ${BACKUP_PATH}_system_info.txt"
}

# Backup-Validierung
validate_backup() {
    log "Validiere Backup..."
    
    # Prüfe ob alle Backup-Dateien existieren
    required_files=(
        "${BACKUP_PATH}_database.sql"
        "${BACKUP_PATH}_config.tar.gz"
        "${BACKUP_PATH}_localization.json"
        "${BACKUP_PATH}_system_info.txt"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            error "Backup-Datei fehlt: $file"
        fi
    done
    
    # Prüfe Datenbank-Backup-Größe
    db_size=$(stat -c%s "${BACKUP_PATH}_database.sql")
    if [ "$db_size" -lt 1000 ]; then
        warning "Datenbank-Backup ist sehr klein ($db_size bytes) - möglicherweise leer"
    fi
    
    # Prüfe JSON-Validität
    if command -v jq > /dev/null 2>&1; then
        if ! jq empty "${BACKUP_PATH}_localization.json" 2>/dev/null; then
            error "Lokalisierungs-JSON ist nicht gültig"
        fi
    fi
    
    log "Backup-Validierung erfolgreich"
}

# Backup komprimieren
compress_backup() {
    log "Komprimiere Backup..."
    
    # Alle Backup-Dateien in ein Archiv packen
    tar -czf "${BACKUP_PATH}.tar.gz" \
        "${BACKUP_PATH}_database.sql" \
        "${BACKUP_PATH}_config.tar.gz" \
        "${BACKUP_PATH}_localization.json" \
        "${BACKUP_PATH}_system_info.txt"
    
    # Einzelne Dateien löschen
    rm "${BACKUP_PATH}_database.sql" \
       "${BACKUP_PATH}_config.tar.gz" \
       "${BACKUP_PATH}_localization.json" \
       "${BACKUP_PATH}_system_info.txt"
    
    log "Backup komprimiert: ${BACKUP_PATH}.tar.gz"
}

# Backup-Informationen anzeigen
show_backup_info() {
    log "Backup-Informationen:"
    echo "===================="
    echo "Backup-Datei: ${BACKUP_PATH}.tar.gz"
    echo "Größe: $(du -h "${BACKUP_PATH}.tar.gz" | cut -f1)"
    echo "Erstellt: $(date)"
    echo ""
    echo "Inhalt:"
    echo "- Datenbank-Backup"
    echo "- Konfigurations-Backup"
    echo "- Lokalisierungs-Daten"
    echo "- System-Informationen"
    echo ""
    echo "Wiederherstellung:"
    echo "./restore-localization.sh ${BACKUP_PATH}.tar.gz"
}

# Cleanup
cleanup() {
    # Temporäre Dateien löschen
    rm -f /tmp/export_localization.rb
    rm -f /tmp/localization_data.json
    
    log "Cleanup abgeschlossen"
}

# Hauptfunktion
main() {
    log "Starte Carambus Lokalisierungs-Backup..."
    
    check_prerequisites
    backup_database
    backup_configuration
    export_localization_data
    collect_system_info
    validate_backup
    compress_backup
    show_backup_info
    cleanup
    
    log "Backup erfolgreich erstellt!"
}

# Script ausführen
main "$@" 