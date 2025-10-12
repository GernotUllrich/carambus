#!/bin/bash
# Quick-Start Script für Raspberry Pi 4
# Führt die komplette Installation und den ersten Test durch

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
RASPBERRY_PI_IP=""
SKIP_SETUP=false
SKIP_TEST=false
CLEANUP_AFTER_TEST=false

# Hilfe anzeigen
show_help() {
    cat << EOF
Quick-Start Script für Raspberry Pi 4

Verwendung:
  $0 [OPTIONS] IP_ADDRESS

Optionen:
  IP_ADDRESS              Raspberry Pi IP-Adresse
  --skip-setup            Setup überspringen
  --skip-test             Test überspringen
  --cleanup               Cleanup nach Test
  -h, --help              Diese Hilfe anzeigen

Beispiele:
  $0 192.168.1.100                    # Vollständige Installation
  $0 --skip-setup 192.168.1.100       # Nur Test
  $0 --skip-test 192.168.1.100        # Nur Setup
  $0 --cleanup 192.168.1.100          # Mit Cleanup
EOF
}

# Argumente parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-setup)
            SKIP_SETUP=true
            shift
            ;;
        --skip-test)
            SKIP_TEST=true
            shift
            ;;
        --cleanup)
            CLEANUP_AFTER_TEST=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$RASPBERRY_PI_IP" ]]; then
                RASPBERRY_PI_IP="$1"
            else
                error "Unbekannte Option: $1"
            fi
            shift
            ;;
    esac
done

# IP-Adresse validieren
if [[ -z "$RASPBERRY_PI_IP" ]]; then
    error "IP-Adresse muss angegeben werden"
fi

# SSH-Verbindung testen
test_ssh_connection() {
    log "Teste SSH-Verbindung zu pi@$RASPBERRY_PI_IP..."
    
    # Erste Verbindung ohne BatchMode (erlaubt Passwort-Eingabe)
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no pi@$RASPBERRY_PI_IP "echo 'SSH-Verbindung erfolgreich'" 2>/dev/null; then
        log "✅ SSH-Verbindung erfolgreich"
        return 0
    else
        log "SSH-Verbindung fehlgeschlagen - möglicherweise Passwort erforderlich"
        log "Versuche manuelle SSH-Verbindung..."
        log "Bitte geben Sie das Passwort ein (Standard: raspberry)"
        log "Nach der Verbindung können Sie 'exit' eingeben"
        
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no pi@$RASPBERRY_PI_IP; then
            log "✅ Manuelle SSH-Verbindung erfolgreich"
            return 0
        else
            error "SSH-Verbindung zu $RASPBERRY_PI_IP fehlgeschlagen"
            error "Bitte prüfen Sie:"
            error "1. Raspberry Pi ist gestartet"
            error "2. IP-Adresse ist korrekt"
            error "3. SSH ist aktiviert"
            error "4. Netzwerk-Verbindung funktioniert"
            return 1
        fi
    fi
}

# Repository klonen
clone_repository() {
    log "Klone Repository auf Raspberry Pi..."
    
    ssh pi@$RASPBERRY_PI_IP "
        if [ ! -d ~/carambus ]; then
            cd ~
            git clone https://github.com/GernotUllrich/carambus.git
            cd carambus
            echo 'Repository geklont'
        else
            cd ~/carambus
            git pull origin master
            echo 'Repository aktualisiert'
        fi
    "
    
    log "✅ Repository bereit"
}

# Setup ausführen
run_setup() {
    if [[ "$SKIP_SETUP" == true ]]; then
        log "Setup übersprungen"
        return
    fi
    
    log "Führe Setup auf Raspberry Pi aus..."
    
    ssh pi@$RASPBERRY_PI_IP "
        cd ~/carambus
        chmod +x bin/setup-raspberry-pi.sh
        ./bin/setup-raspberry-pi.sh
    "
    
    log "✅ Setup abgeschlossen"
    log "Neustart empfohlen..."
    
    # Neustart fragen
    read -p "Raspberry Pi neustarten? (j/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Jj]$ ]]; then
        log "Starte Raspberry Pi neu..."
        ssh pi@$RASPBERRY_PI_IP "sudo reboot"
        
        # Warten bis Raspberry Pi wieder online ist
        log "Warte auf Neustart..."
        sleep 60
        
        # SSH-Verbindung testen
        for i in {1..30}; do
            if ssh -o ConnectTimeout=5 pi@$RASPBERRY_PI_IP "echo 'Online'" > /dev/null 2>&1; then
                log "✅ Raspberry Pi wieder online"
                break
            fi
            sleep 10
        done
    fi
}

# Test ausführen
run_test() {
    if [[ "$SKIP_TEST" == true ]]; then
        log "Test übersprungen"
        return
    fi
    
    log "Führe Test auf Raspberry Pi aus..."
    
    # Test-Optionen
    TEST_OPTIONS=""
    if [[ "$CLEANUP_AFTER_TEST" == true ]]; then
        TEST_OPTIONS="--cleanup"
    fi
    
    ssh pi@$RASPBERRY_PI_IP "
        cd ~/carambus
        chmod +x bin/test-raspberry-pi.sh
        ./bin/test-raspberry-pi.sh $TEST_OPTIONS
    "
    
    log "✅ Test abgeschlossen"
}

# Web-Interface testen
test_web_interface() {
    log "Teste Web-Interface..."
    
    # HTTP-Test
    if curl -f http://$RASPBERRY_PI_IP/health > /dev/null 2>&1; then
        log "✅ HTTP-Interface erreichbar"
    else
        warning "❌ HTTP-Interface nicht erreichbar"
    fi
    
    # HTTPS-Test
    if curl -k -f https://$RASPBERRY_PI_IP/health > /dev/null 2>&1; then
        log "✅ HTTPS-Interface erreichbar"
    else
        warning "❌ HTTPS-Interface nicht erreichbar"
    fi
    
    # Scoreboard-Test
    if curl -f http://$RASPBERRY_PI_IP/scoreboard > /dev/null 2>&1; then
        log "✅ Scoreboard erreichbar"
    else
        warning "❌ Scoreboard nicht erreichbar"
    fi
}

# System-Informationen anzeigen
show_system_info() {
    log "System-Informationen:"
    echo "===================="
    
    # System-Info von Raspberry Pi
    SYSTEM_INFO=$(ssh pi@$RASPBERRY_PI_IP "
        echo 'Architektur: ' \$(uname -m)
        echo 'Betriebssystem: ' \$(lsb_release -d | cut -f2)
        echo 'Kernel: ' \$(uname -r)
        echo 'CPU: ' \$(grep 'Model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        echo 'RAM: ' \$(free -h | awk 'NR==2{printf \"%.1f\", \$2}')
        echo 'Speicherplatz: ' \$(df -h / | awk 'NR==2{printf \"%.1f\", \$4}') 'verfügbar'
        echo ''
        echo 'Docker: ' \$(docker --version 2>/dev/null || echo 'Nicht installiert')
        echo 'Docker Compose: ' \$(docker-compose --version 2>/dev/null || echo 'Nicht installiert')
        echo ''
        echo 'Container-Status:'
        cd ~/carambus && docker-compose ps 2>/dev/null || echo 'Docker nicht verfügbar'
    ")
    
    echo "$SYSTEM_INFO"
}

# Zugriff-Informationen anzeigen
show_access_info() {
    log "Zugriff-Informationen:"
    echo "====================="
    echo "SSH: ssh pi@$RASPBERRY_PI_IP"
    echo "Web: http://$RASPBERRY_PI_IP"
    echo "HTTPS: https://$RASPBERRY_PI_IP"
    echo "Scoreboard: http://$RASPBERRY_PI_IP/scoreboard"
    echo ""
    echo "Nächste Schritte:"
    echo "1. Browser öffnen: http://$RASPBERRY_PI_IP"
    echo "2. SSL-Warnung bestätigen (selbst-signiert)"
    echo "3. Carambus-Interface testen"
    echo "4. Scoreboard im Vollbild-Modus testen"
}

# Hauptfunktion
main() {
    log "Starte Quick-Start für Raspberry Pi 4..."
    log "IP-Adresse: $RASPBERRY_PI_IP"
    
    test_ssh_connection
    clone_repository
    run_setup
    run_test
    test_web_interface
    show_system_info
    show_access_info
    
    log "Quick-Start erfolgreich abgeschlossen!"
    log ""
    log "Carambus ist jetzt verfügbar unter:"
    log "- Web: http://$RASPBERRY_PI_IP"
    log "- HTTPS: https://$RASPBERRY_PI_IP"
    log "- Scoreboard: http://$RASPBERRY_PI_IP/scoreboard"
}

# Script ausführen
main "$@" 