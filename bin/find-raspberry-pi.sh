#!/bin/bash
# Raspberry Pi Finder Script
# Sucht automatisch nach dem Raspberry Pi im Netzwerk

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
Raspberry Pi Finder Script

Verwendung:
  $0 [OPTIONS]

Optionen:
  --network NETWORK    Netzwerk-Bereich (Standard: 192.168.1.0/24)
  --timeout SECONDS    Timeout für Ping-Tests (Standard: 1)
  --ssh-test          SSH-Verbindung testen
  --quick             Nur schnelle Suche
  -h, --help          Diese Hilfe anzeigen

Beispiele:
  $0                    # Standard-Suche
  $0 --network 192.168.0.0/24  # Anderes Netzwerk
  $0 --ssh-test        # Mit SSH-Test
  $0 --quick           # Schnelle Suche
EOF
}

# Variablen
NETWORK="192.168.1.0/24"
TIMEOUT=1
SSH_TEST=false
QUICK_MODE=false

# Argumente parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --ssh-test)
            SSH_TEST=true
            shift
            ;;
        --quick)
            QUICK_MODE=true
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

# Prüfe nmap
check_nmap() {
    if ! command -v nmap > /dev/null 2>&1; then
        warning "nmap nicht gefunden - verwende ping"
        USE_NMAP=false
    else
        USE_NMAP=true
    fi
}

# Netzwerk-Bereich extrahieren
extract_network() {
    local network="$1"
    local base_ip=$(echo "$network" | cut -d'/' -f1)
    local prefix=$(echo "$network" | cut -d'/' -f2)
    
    # Letzte Oktett entfernen
    local base=$(echo "$base_ip" | sed 's/\.[0-9]*$//')
    
    echo "$base"
}

# Ping-Scan
ping_scan() {
    local base_ip="$1"
    local found_ips=()
    
    log "Scanne Netzwerk: ${base_ip}.0/24"
    log "Suche nach Raspberry Pi..."
    
    # Erste 50 IPs scannen (schneller)
    for i in {1..50}; do
        local ip="${base_ip}.${i}"
        
        if ping -c 1 -W "$TIMEOUT" "$ip" > /dev/null 2>&1; then
            found_ips+=("$ip")
            log "✅ Gerät gefunden: $ip"
        fi
    done
    
    echo "${found_ips[@]}"
}

# Nmap-Scan (falls verfügbar)
nmap_scan() {
    local network="$1"
    local found_ips=()
    
    log "Scanne Netzwerk mit nmap: $network"
    
    # Schneller Ping-Scan
    local scan_result=$(nmap -sn "$network" | grep -E "Nmap scan report for" | awk '{print $5}')
    
    while IFS= read -r ip; do
        if [[ -n "$ip" ]]; then
            found_ips+=("$ip")
            log "✅ Gerät gefunden: $ip"
        fi
    done <<< "$scan_result"
    
    echo "${found_ips[@]}"
}

# SSH-Test
test_ssh() {
    local ip="$1"
    local timeout=5
    
    log "Teste SSH-Verbindung zu $ip..."
    
    if timeout "$timeout" ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no pi@"$ip" "echo 'SSH-Verbindung erfolgreich'" 2>/dev/null; then
        log "✅ SSH-Verbindung erfolgreich: pi@$ip"
        return 0
    else
        log "❌ SSH-Verbindung fehlgeschlagen: pi@$ip"
        return 1
    fi
}

# Raspberry Pi identifizieren
identify_raspberry_pi() {
    local ip="$1"
    
    # SSH-Test mit Hostname
    if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no pi@"$ip" "hostname" 2>/dev/null | grep -q "raspberrypi"; then
        return 0
    fi
    
    # Alternative: MAC-Adresse prüfen (macOS-kompatibel)
    local mac=$(arp -n "$ip" 2>/dev/null | awk '{print $3}' | tr '[:lower:]' '[:upper:]')
    if [[ "$mac" =~ ^(B8:27:EB|DC:A6:32|E4:5F:01) ]]; then
        return 0
    fi
    
    return 1
}

# Hauptfunktion
main() {
    log "Starte Raspberry Pi Suche..."
    log "Netzwerk: $NETWORK"
    log "Timeout: ${TIMEOUT}s"
    
    check_nmap
    
    # Netzwerk-Basis extrahieren
    local base_ip=$(extract_network "$NETWORK")
    
    # Scan durchführen
    local found_ips=()
    if [[ "$USE_NMAP" == true ]]; then
        found_ips=($(nmap_scan "$NETWORK"))
    else
        found_ips=($(ping_scan "$base_ip"))
    fi
    
    if [[ ${#found_ips[@]} -eq 0 ]]; then
        error "Keine Geräte im Netzwerk gefunden"
    fi
    
    log "Gefundene Geräte: ${#found_ips[@]}"
    
    # Raspberry Pi identifizieren
    local raspberry_pi_ip=""
    for ip in "${found_ips[@]}"; do
        log "Prüfe Gerät: $ip"
        
        if identify_raspberry_pi "$ip"; then
            raspberry_pi_ip="$ip"
            log "✅ Raspberry Pi gefunden: $ip"
            break
        fi
    done
    
    if [[ -z "$raspberry_pi_ip" ]]; then
        warning "Raspberry Pi nicht eindeutig identifiziert"
        log "Teste SSH-Verbindung zu allen gefundenen IPs..."
        
        for ip in "${found_ips[@]}"; do
            if test_ssh "$ip"; then
                raspberry_pi_ip="$ip"
                log "✅ SSH-Verbindung erfolgreich: $ip"
                break
            fi
        done
    fi
    
    if [[ -n "$raspberry_pi_ip" ]]; then
        echo ""
        log "🎉 Raspberry Pi gefunden!"
        echo "========================"
        echo "IP-Adresse: $raspberry_pi_ip"
        echo "SSH-Zugriff: ssh pi@$raspberry_pi_ip"
        echo "Passwort: raspberry"
        echo ""
        
        if [[ "$SSH_TEST" == true ]]; then
            if test_ssh "$raspberry_pi_ip"; then
                log "✅ SSH-Verbindung bestätigt"
                echo ""
                echo "Nächste Schritte:"
                echo "1. Quick-Start Script ausführen:"
                echo "   ./bin/quick-start-raspberry-pi.sh $raspberry_pi_ip"
                echo ""
                echo "2. Oder manuell SSH:"
                echo "   ssh pi@$raspberry_pi_ip"
            fi
        fi
    else
        error "Raspberry Pi nicht gefunden"
    fi
}

# Script ausführen
main "$@" 