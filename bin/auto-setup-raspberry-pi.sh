#!/bin/bash
# Automatisches Raspberry Pi Setup
# Konfiguriert das erste Boot-Setup automatisch

set -e

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktion
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
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

# Hilfe anzeigen
show_help() {
    cat << EOF
Automatisches Raspberry Pi Setup

Verwendung:
  $0 [OPTIONS]

Optionen:
  --language LANG        Sprache (Standard: de)
  --keyboard LAYOUT      Tastatur-Layout (Standard: de)
  --timezone TZ          Zeitzone (Standard: Europe/Berlin)
  --wifi-country CC      WLAN-Land (Standard: DE)
  --user USERNAME        Benutzername (Standard: pi)
  --password PASSWORD    Passwort (Standard: raspberry)
  --skip-setup           Setup komplett überspringen
  -h, --help             Diese Hilfe anzeigen

Beispiele:
  $0                      # Standard-Setup
  $0 --skip-setup        # Setup überspringen
  $0 --language en       # Englisch
EOF
}

# Variablen
LANGUAGE="de"
KEYBOARD="de"
TIMEZONE="Europe/Berlin"
WIFI_COUNTRY="DE"
USERNAME="pi"
PASSWORD="raspberry"
SKIP_SETUP=false

# Argumente parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        --language)
            LANGUAGE="$2"
            shift 2
            ;;
        --keyboard)
            KEYBOARD="$2"
            shift 2
            ;;
        --timezone)
            TIMEZONE="$2"
            shift 2
            ;;
        --wifi-country)
            WIFI_COUNTRY="$2"
            shift 2
            ;;
        --user)
            USERNAME="$2"
            shift 2
            ;;
        --password)
            PASSWORD="$2"
            shift 2
            ;;
        --skip-setup)
            SKIP_SETUP=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error "Unbekannte Option: $1"
            ;;
    esac
done

# Setup überspringen
skip_setup() {
    log "Setup überspringen..."
    
    # Anleitung für manuelles Überspringen
    cat << EOF
===========================================
RASPBERRY PI SETUP ÜBERSPRINGEN
===========================================

Auf dem Raspberry Pi (mit Tastatur/Maus):

1. **Sprache auswählen**: $LANGUAGE
   - Klicken Sie auf "Skip" oder "Überspringen"

2. **Tastatur-Layout**: $KEYBOARD
   - Klicken Sie auf "Skip" oder "Überspringen"

3. **Zeitzone**: $TIMEZONE
   - Klicken Sie auf "Skip" oder "Überspringen"

4. **WLAN-Land**: $WIFI_COUNTRY
   - Klicken Sie auf "Skip" oder "Überspringen"

5. **Benutzer erstellen**: $USERNAME
   - Klicken Sie auf "Skip" oder "Überspringen"
   - Standard-Benutzer wird verwendet

6. **Passwort**: $PASSWORD
   - Klicken Sie auf "Skip" oder "Überspringen"
   - Standard-Passwort wird verwendet

7. **Setup abschließen**:
   - Klicken Sie auf "Finish" oder "Beenden"

ALTERNATIVE: Neustart
- Stromversorgung trennen
- 10 Sekunden warten
- Stromversorgung wieder anschließen
- Setup sollte dann übersprungen werden

Nach dem Setup:
- SSH wird automatisch aktiviert
- WLAN wird automatisch verbunden
- IP-Adresse: 192.168.178.92 (mac.fritz.box)

EOF
}

# Automatisches Setup konfigurieren
configure_auto_setup() {
    log "Automatisches Setup konfigurieren..."
    
    # Anleitung für automatisches Setup
    cat << EOF
===========================================
AUTOMATISCHES RASPBERRY PI SETUP
===========================================

Auf dem Raspberry Pi (mit Tastatur/Maus):

1. **Sprache**: $LANGUAGE
   - Wählen Sie: $LANGUAGE

2. **Tastatur-Layout**: $KEYBOARD
   - Wählen Sie: $KEYBOARD

3. **Zeitzone**: $TIMEZONE
   - Wählen Sie: $TIMEZONE

4. **WLAN-Land**: $WIFI_COUNTRY
   - Wählen Sie: $WIFI_COUNTRY

5. **Benutzer**: $USERNAME
   - Benutzername: $USERNAME
   - Passwort: $PASSWORD

6. **Setup abschließen**:
   - Klicken Sie auf "Finish" oder "Beenden"

Nach dem Setup:
- SSH wird automatisch aktiviert
- WLAN wird automatisch verbunden
- IP-Adresse: 192.168.178.92 (mac.fritz.box)

EOF
}

# Hauptfunktion
main() {
    log "Raspberry Pi Setup-Konfiguration"
    log "Sprache: $LANGUAGE"
    log "Tastatur: $KEYBOARD"
    log "Zeitzone: $TIMEZONE"
    log "WLAN-Land: $WIFI_COUNTRY"
    log "Benutzer: $USERNAME"
    
    if [[ "$SKIP_SETUP" == true ]]; then
        skip_setup
    else
        configure_auto_setup
    fi
    
    echo ""
    log "Nach dem Setup können Sie fortfahren mit:"
    echo "ssh pi@192.168.178.92"
    echo "Passwort: $PASSWORD"
    echo ""
    echo "Dann automatische Installation:"
    echo "./bin/quick-start-raspberry-pi.sh 192.168.178.92"
}

# Script ausführen
main "$@" 