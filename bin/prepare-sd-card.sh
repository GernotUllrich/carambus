#!/bin/bash
# SD-Karten-Vorbereitung für Raspberry Pi 4
# Erstellt das Image und konfiguriert SSH/WLAN

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
SD_CARD_PATH=""
WIFI_SSID=""
WIFI_PASSWORD=""
COUNTRY="DE"
ENABLE_SSH=true
ENABLE_WIFI=false

# Hilfe anzeigen
show_help() {
    cat << EOF
SD-Karten-Vorbereitung für Raspberry Pi 4

Verwendung:
  $0 [OPTIONS] SD_CARD_PATH

Optionen:
  SD_CARD_PATH            Pfad zur SD-Karte (z.B. /dev/disk2)
  --wifi-ssid SSID        WLAN-Name
  --wifi-password PASS    WLAN-Passwort
  --country CODE          Ländercode (Standard: DE)
  --no-ssh                SSH nicht aktivieren
  -h, --help              Diese Hilfe anzeigen

Beispiele:
  $0 /dev/disk2                                    # Nur SSH aktivieren
  $0 --wifi-ssid "MeinWLAN" --wifi-password "pass" /dev/disk2  # Mit WLAN
  $0 --no-ssh /dev/disk2                          # Ohne SSH
EOF
}

# Argumente parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        --wifi-ssid)
            WIFI_SSID="$2"
            ENABLE_WIFI=true
            shift 2
            ;;
        --wifi-password)
            WIFI_PASSWORD="$2"
            shift 2
            ;;
        --country)
            COUNTRY="$2"
            shift 2
            ;;
        --no-ssh)
            ENABLE_SSH=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$SD_CARD_PATH" ]]; then
                SD_CARD_PATH="$1"
            else
                error "Unbekannte Option: $1"
            fi
            shift
            ;;
    esac
done

# SD-Karten-Pfad validieren
if [[ -z "$SD_CARD_PATH" ]]; then
    error "SD-Karten-Pfad muss angegeben werden"
fi

# WLAN-Konfiguration validieren
if [[ "$ENABLE_WIFI" == true ]]; then
    if [[ -z "$WIFI_SSID" || -z "$WIFI_PASSWORD" ]]; then
        error "WLAN-SSID und Passwort müssen angegeben werden"
    fi
fi

# SD-Karte prüfen
check_sd_card() {
    log "Prüfe SD-Karte..."
    
    if [[ ! -b "$SD_CARD_PATH" ]]; then
        error "SD-Karte nicht gefunden: $SD_CARD_PATH"
    fi
    
    # SD-Karten-Größe prüfen
    SIZE=$(df -h "$SD_CARD_PATH" | awk 'NR==2 {print $2}' | sed 's/G//')
    if [[ $SIZE -lt 16 ]]; then
        warning "SD-Karte ist kleiner als 16GB: ${SIZE}GB"
    else
        log "✅ SD-Karte gefunden: ${SIZE}GB"
    fi
}

# SD-Karte mounten
mount_sd_card() {
    log "Mounte SD-Karte..."
    
    # Boot-Partition finden
    BOOT_PARTITION=""
    for partition in ${SD_CARD_PATH}*; do
        if [[ -d "$partition" && -f "$partition/cmdline.txt" ]]; then
            BOOT_PARTITION="$partition"
            break
        fi
    done
    
    if [[ -z "$BOOT_PARTITION" ]]; then
        error "Boot-Partition nicht gefunden"
    fi
    
    log "✅ Boot-Partition gefunden: $BOOT_PARTITION"
}

# SSH aktivieren
enable_ssh() {
    if [[ "$ENABLE_SSH" == false ]]; then
        log "SSH-Aktivierung übersprungen"
        return
    fi
    
    log "Aktiviere SSH..."
    
    # SSH-Datei erstellen
    touch "$BOOT_PARTITION/ssh"
    
    log "✅ SSH aktiviert"
}

# WLAN konfigurieren
configure_wifi() {
    if [[ "$ENABLE_WIFI" == false ]]; then
        log "WLAN-Konfiguration übersprungen"
        return
    fi
    
    log "Konfiguriere WLAN..."
    
    # wpa_supplicant.conf erstellen
    cat > "$BOOT_PARTITION/wpa_supplicant.conf" << EOF
country=$COUNTRY
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASSWORD"
    key_mgmt=WPA-PSK
}
EOF
    
    log "✅ WLAN konfiguriert: $WIFI_SSID"
}

# SD-Karte unmounten
unmount_sd_card() {
    log "Unmounte SD-Karte..."
    
    # Sicher unmounten
    if [[ -n "$BOOT_PARTITION" ]]; then
        sudo umount "$BOOT_PARTITION" 2>/dev/null || true
    fi
    
    log "✅ SD-Karte unmounted"
}

# SD-Karten-Informationen anzeigen
show_sd_card_info() {
    log "SD-Karten-Informationen:"
    echo "======================="
    echo "Pfad: $SD_CARD_PATH"
    echo "Boot-Partition: $BOOT_PARTITION"
    echo "SSH aktiviert: $ENABLE_SSH"
    echo "WLAN konfiguriert: $ENABLE_WIFI"
    
    if [[ "$ENABLE_WIFI" == true ]]; then
        echo "WLAN-SSID: $WIFI_SSID"
        echo "Ländercode: $COUNTRY"
    fi
    
    echo ""
    echo "Nächste Schritte:"
    echo "1. SD-Karte aus Computer entfernen"
    echo "2. SD-Karte in Raspberry Pi einlegen"
    echo "3. Stromversorgung anschließen"
    echo "4. Warten bis Boot abgeschlossen"
    echo "5. IP-Adresse finden"
    echo "6. SSH-Verbindung testen: ssh pi@IP_ADRESSE"
}

# Hauptfunktion
main() {
    log "Starte SD-Karten-Vorbereitung..."
    log "SD-Karte: $SD_CARD_PATH"
    log "SSH aktiviert: $ENABLE_SSH"
    log "WLAN konfiguriert: $ENABLE_WIFI"
    
    check_sd_card
    mount_sd_card
    enable_ssh
    configure_wifi
    show_sd_card_info
    unmount_sd_card
    
    log "SD-Karten-Vorbereitung erfolgreich abgeschlossen!"
}

# Script ausführen
main "$@" 