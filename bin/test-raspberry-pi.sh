#!/bin/bash
# Raspberry Pi 4 Test Script für Carambus Docker Deployment
# Testet die komplette Installation und Konfiguration

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
TEST_DIR="/opt/carambus-test"
DOCKER_COMPOSE_FILE="docker-compose.raspberry-pi.yml"

# Hilfe anzeigen
show_help() {
    cat << EOF
Raspberry Pi 4 Test Script für Carambus

Verwendung:
  $0 [OPTIONS]

Optionen:
  -d, --dir DIR              Test-Verzeichnis (Standard: /opt/carambus-test)
  -c, --compose FILE         Docker-Compose-Datei (Standard: docker-compose.raspberry-pi.yml)
  --cleanup                  Cleanup nach Tests
  -h, --help                 Diese Hilfe anzeigen

Beispiele:
  $0                                    # Standard-Test durchführen
  $0 -d /home/pi/carambus-test         # Custom-Verzeichnis
  $0 --cleanup                          # Cleanup nach Tests
EOF
}

# Argumente parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir)
            TEST_DIR="$2"
            shift 2
            ;;
        -c|--compose)
            DOCKER_COMPOSE_FILE="$2"
            shift 2
            ;;
        --cleanup)
            CLEANUP=true
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

# Prüfung der Voraussetzungen
check_prerequisites() {
    log "Prüfe Raspberry Pi Voraussetzungen..."
    
    # Architektur prüfen
    if [[ "$(uname -m)" != "armv7l" && "$(uname -m)" != "aarch64" ]]; then
        warning "Nicht auf ARM-Architektur - Test könnte fehlschlagen"
    else
        log "✅ ARM-Architektur erkannt: $(uname -m)"
    fi
    
    # Docker prüfen
    if ! command -v docker > /dev/null 2>&1; then
        error "Docker ist nicht installiert"
    fi
    log "✅ Docker installiert: $(docker --version)"
    
    # Docker Compose prüfen
    if ! command -v docker-compose > /dev/null 2>&1; then
        error "Docker Compose ist nicht installiert"
    fi
    log "✅ Docker Compose installiert: $(docker-compose --version)"
    
    # Speicherplatz prüfen
    AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
    if [[ $AVAILABLE_SPACE -lt 5000000 ]]; then
        warning "Wenig Speicherplatz verfügbar: ${AVAILABLE_SPACE}KB"
    else
        log "✅ Ausreichend Speicherplatz: ${AVAILABLE_SPACE}KB"
    fi
    
    # RAM prüfen
    TOTAL_RAM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [[ $TOTAL_RAM -lt 2048 ]]; then
        warning "Wenig RAM verfügbar: ${TOTAL_RAM}MB"
    else
        log "✅ Ausreichend RAM: ${TOTAL_RAM}MB"
    fi
    
    log "Voraussetzungen erfüllt"
}

# Test-Verzeichnis erstellen
setup_test_directory() {
    log "Erstelle Test-Verzeichnis..."
    
    sudo mkdir -p "$TEST_DIR"
    sudo chown -R $USER:$USER "$TEST_DIR"
    cd "$TEST_DIR"
    
    log "Test-Verzeichnis erstellt: $TEST_DIR"
}

# Docker-Images herunterladen/bauen
setup_docker_images() {
    log "Setup Docker-Images..."
    
    # SSL-Zertifikat generieren
    if [[ ! -f "ssl/cert.pem" ]]; then
        log "Generiere SSL-Zertifikat..."
        ./bin/generate-ssl-cert.sh
    fi
    
    # Docker-Image bauen
    log "Baue Docker-Image für Raspberry Pi..."
    ./bin/build-docker-image.sh -p raspberry-pi -t test
    
    log "Docker-Images bereit"
}

# Container starten
start_containers() {
    log "Starte Container..."
    
    # Docker-Compose-Datei kopieren
    cp "$DOCKER_COMPOSE_FILE" docker-compose.yml
    
    # Container starten
    docker-compose up -d
    
    # Warten bis alle Container laufen
    log "Warte auf Container-Start..."
    sleep 30
    
    # Container-Status prüfen
    if docker-compose ps | grep -q "Up"; then
        log "✅ Container erfolgreich gestartet"
    else
        error "Container-Start fehlgeschlagen"
    fi
}

# Health-Checks durchführen
run_health_checks() {
    log "Führe Health-Checks durch..."
    
    # Container-Status
    log "Container-Status:"
    docker-compose ps
    
    # Health-Check-Endpunkte
    log "Health-Checks:"
    
    # Rails-App Health-Check
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        log "✅ Rails-App läuft"
    else
        warning "❌ Rails-App nicht erreichbar"
    fi
    
    # Nginx Health-Check
    if curl -f http://localhost/health > /dev/null 2>&1; then
        log "✅ Nginx läuft"
    else
        warning "❌ Nginx nicht erreichbar"
    fi
    
    # PostgreSQL Health-Check
    if docker-compose exec -T db pg_isready -U www_data > /dev/null 2>&1; then
        log "✅ PostgreSQL läuft"
    else
        warning "❌ PostgreSQL nicht erreichbar"
    fi
    
    # Redis Health-Check
    if docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; then
        log "✅ Redis läuft"
    else
        warning "❌ Redis nicht erreichbar"
    fi
}

# Performance-Tests
run_performance_tests() {
    log "Führe Performance-Tests durch..."
    
    # Container-Ressourcen
    log "Container-Ressourcen:"
    docker stats --no-stream
    
    # Disk-Usage
    log "Disk-Usage:"
    docker system df
    
    # Image-Größen
    log "Image-Größen:"
    docker images carambus/carambus --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
    
    # Netzwerk-Tests
    log "Netzwerk-Tests:"
    
    # Response-Zeit testen
    START_TIME=$(date +%s.%N)
    curl -s http://localhost:3000/health > /dev/null
    END_TIME=$(date +%s.%N)
    RESPONSE_TIME=$(echo "$END_TIME - $START_TIME" | bc)
    log "Response-Zeit: ${RESPONSE_TIME}s"
}

# Funktionalitäts-Tests
run_functionality_tests() {
    log "Führe Funktionalitäts-Tests durch..."
    
    # Rails-Konsole testen
    log "Rails-Konsole Test:"
    if docker-compose exec -T app rails runner "puts 'Rails läuft!'" > /dev/null 2>&1; then
        log "✅ Rails-Konsole funktioniert"
    else
        warning "❌ Rails-Konsole nicht verfügbar"
    fi
    
    # Datenbank-Verbindung testen
    log "Datenbank-Verbindung Test:"
    if docker-compose exec -T app rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').first" > /dev/null 2>&1; then
        log "✅ Datenbank-Verbindung funktioniert"
    else
        warning "❌ Datenbank-Verbindung fehlgeschlagen"
    fi
    
    # Redis-Verbindung testen
    log "Redis-Verbindung Test:"
    if docker-compose exec -T app rails runner "puts Redis.new.ping" > /dev/null 2>&1; then
        log "✅ Redis-Verbindung funktioniert"
    else
        warning "❌ Redis-Verbindung fehlgeschlagen"
    fi
}

# Log-Analyse
analyze_logs() {
    log "Analysiere Logs..."
    
    # Rails-Logs
    log "Rails-Logs (letzte 10 Zeilen):"
    docker-compose logs app | tail -10
    
    # Nginx-Logs
    log "Nginx-Logs (letzte 10 Zeilen):"
    docker-compose logs nginx | tail -10
    
    # PostgreSQL-Logs
    log "PostgreSQL-Logs (letzte 10 Zeilen):"
    docker-compose logs db | tail -10
}

# Cleanup
cleanup() {
    if [[ "$CLEANUP" == true ]]; then
        log "Führe Cleanup durch..."
        
        # Container stoppen
        docker-compose down
        
        # Images löschen
        docker rmi carambus/carambus:test-raspberry-pi 2>/dev/null || true
        
        # Test-Verzeichnis löschen
        sudo rm -rf "$TEST_DIR"
        
        log "Cleanup abgeschlossen"
    fi
}

# Test-Report generieren
generate_report() {
    log "Generiere Test-Report..."
    
    REPORT_FILE="$TEST_DIR/test-report-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$REPORT_FILE" << EOF
Carambus Raspberry Pi 4 Test Report
==================================
Datum: $(date)
System: $(uname -a)
Architektur: $(uname -m)
Docker: $(docker --version)
Docker Compose: $(docker-compose --version)

Container-Status:
$(docker-compose ps)

System-Ressourcen:
$(free -h)

Disk-Usage:
$(df -h /)

Docker-Images:
$(docker images carambus/carambus)

Health-Checks:
- Rails-App: $(curl -f http://localhost:3000/health > /dev/null 2>&1 && echo "OK" || echo "FAILED")
- Nginx: $(curl -f http://localhost/health > /dev/null 2>&1 && echo "OK" || echo "FAILED")
- PostgreSQL: $(docker-compose exec -T db pg_isready -U www_data > /dev/null 2>&1 && echo "OK" || echo "FAILED")
- Redis: $(docker-compose exec -T redis redis-cli ping > /dev/null 2>&1 && echo "OK" || echo "FAILED")

Logs:
$(docker-compose logs --tail=20)
EOF
    
    log "Test-Report erstellt: $REPORT_FILE"
}

# Hauptfunktion
main() {
    log "Starte Raspberry Pi 4 Test..."
    
    check_prerequisites
    setup_test_directory
    setup_docker_images
    start_containers
    run_health_checks
    run_performance_tests
    run_functionality_tests
    analyze_logs
    generate_report
    cleanup
    
    log "Raspberry Pi 4 Test erfolgreich abgeschlossen!"
    log "Test-Report: $TEST_DIR/test-report-*.txt"
}

# Script ausführen
main "$@" 