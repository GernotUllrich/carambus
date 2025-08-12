#!/bin/bash
# Remote Deployment Script für Raspberry Pi
# Deployt Carambus auf einen Raspberry Pi über SSH

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
RASPBERRY_PI_HOST=""
RASPBERRY_PI_USER="www-data"
RASPBERRY_PI_PORT="8910"
DEPLOY_DIR="/var/www/carambus"
BACKUP_EXISTING=true
SKIP_TESTS=false

# Hilfe anzeigen
show_help() {
    cat << EOF
Remote Deployment Script für Raspberry Pi

Verwendung:
  $0 [OPTIONS] HOST

Optionen:
  -h, --host HOST              Raspberry Pi Hostname/IP
  -u, --user USER              SSH-User (Standard: www-data)
  -p, --port PORT              SSH-Port (Standard: 8910)
  -d, --dir DIR                Deploy-Verzeichnis (Standard: /var/www/carambus)
  --no-backup                  Kein Backup der bestehenden Installation
  --skip-tests                 Tests überspringen
  -h, --help                   Diese Hilfe anzeigen

Beispiele:
  $0 192.168.1.100                    # Standard-Deployment
  $0 -h carambus-pi.local -u www-data # Standard User
  $0 -h 192.168.1.100 --no-backup     # Ohne Backup
  $0 -h 192.168.1.100 --skip-tests    # Ohne Tests
EOF
}

# Argumente parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            RASPBERRY_PI_HOST="$2"
            shift 2
            ;;
        -u|--user)
            RASPBERRY_PI_USER="$2"
            shift 2
            ;;
        -p|--port)
            RASPBERRY_PI_PORT="$2"
            shift 2
            ;;
        -d|--dir)
            DEPLOY_DIR="$2"
            shift 2
            ;;
        --no-backup)
            BACKUP_EXISTING=false
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$RASPBERRY_PI_HOST" ]]; then
                RASPBERRY_PI_HOST="$1"
            else
                error "Unbekannte Option: $1"
            fi
            shift
            ;;
    esac
done

# Host validieren
if [[ -z "$RASPBERRY_PI_HOST" ]]; then
    error "Host muss angegeben werden"
fi

# SSH-Verbindung testen
test_ssh_connection() {
    log "Teste SSH-Verbindung zu $RASPBERRY_PI_USER@$RASPBERRY_PI_HOST:$RASPBERRY_PI_PORT..."
    
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "echo 'SSH-Verbindung erfolgreich'" > /dev/null 2>&1; then
        error "SSH-Verbindung zu $RASPBERRY_PI_HOST fehlgeschlagen"
    fi
    
    log "✅ SSH-Verbindung erfolgreich"
}

# Raspberry Pi Voraussetzungen prüfen
check_raspberry_pi_prerequisites() {
    log "Prüfe Raspberry Pi Voraussetzungen..."
    
    # Architektur prüfen
    ARCH=$(ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "uname -m")
    if [[ "$ARCH" != "armv7l" && "$ARCH" != "aarch64" ]]; then
        warning "Nicht auf ARM-Architektur: $ARCH"
    else
        log "✅ ARM-Architektur erkannt: $ARCH"
    fi
    
    # Docker prüfen
    if ! ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "command -v docker > /dev/null 2>&1"; then
        error "Docker ist nicht auf Raspberry Pi installiert"
    fi
    DOCKER_VERSION=$(ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "docker --version")
    log "✅ Docker installiert: $DOCKER_VERSION"
    
    # Docker Compose prüfen
    if ! ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "command -v docker-compose > /dev/null 2>&1"; then
        error "Docker Compose ist nicht auf Raspberry Pi installiert"
    fi
    COMPOSE_VERSION=$(ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "docker-compose --version")
    log "✅ Docker Compose installiert: $COMPOSE_VERSION"
    
    # Speicherplatz prüfen
    AVAILABLE_SPACE=$(ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "df / | awk 'NR==2 {print \$4}'")
    if [[ $AVAILABLE_SPACE -lt 5000000 ]]; then
        warning "Wenig Speicherplatz verfügbar: ${AVAILABLE_SPACE}KB"
    else
        log "✅ Ausreichend Speicherplatz: ${AVAILABLE_SPACE}KB"
    fi
    
    log "Raspberry Pi Voraussetzungen erfüllt"
}

# Backup erstellen
create_backup() {
    if [[ "$BACKUP_EXISTING" == true ]]; then
        log "Erstelle Backup der bestehenden Installation..."
        
        BACKUP_FILE="carambus-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
        
        # Backup erstellen
        ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "
            if [ -d '$DEPLOY_DIR' ]; then
                cd '$DEPLOY_DIR'
                tar -czf /tmp/$BACKUP_FILE .
                echo 'Backup erstellt: /tmp/$BACKUP_FILE'
            else
                echo 'Keine bestehende Installation gefunden'
            fi
        "
        
        log "Backup erstellt: $BACKUP_FILE"
    fi
}

# Dateien übertragen
transfer_files() {
    log "Übertrage Dateien zum Raspberry Pi..."
    
    # Deploy-Verzeichnis erstellen
    ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "sudo mkdir -p '$DEPLOY_DIR' && sudo chown -R $RASPBERRY_PI_USER:$RASPBERRY_PI_USER '$DEPLOY_DIR'"
    
    # Dateien übertragen
    rsync -avz -e "ssh -p $RASPBERRY_PI_PORT" \
        --exclude '.git' \
        --exclude 'node_modules' \
        --exclude 'tmp' \
        --exclude 'log' \
        --exclude 'storage' \
        ./ "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST:$DEPLOY_DIR/"
    
    log "Dateien erfolgreich übertragen"
}

# SSL-Zertifikat generieren
generate_ssl_certificate() {
    log "Generiere SSL-Zertifikat auf Raspberry Pi..."
    
    ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "
        cd '$DEPLOY_DIR'
        chmod +x bin/generate-ssl-cert.sh
        ./bin/generate-ssl-cert.sh
    "
    
    log "SSL-Zertifikat generiert"
}

# Docker-Image bauen
build_docker_image() {
    log "Baue Docker-Image auf Raspberry Pi..."
    
    ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "
        cd '$DEPLOY_DIR'
        chmod +x bin/build-docker-image.sh
        ./bin/build-docker-image.sh -p raspberry-pi -t production
    "
    
    log "Docker-Image erfolgreich gebaut"
}

# Container starten
start_containers() {
    log "Starte Container auf Raspberry Pi..."
    
    ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "
        cd '$DEPLOY_DIR'
        cp docker-compose.raspberry-pi.yml docker-compose.yml
        docker-compose up -d
    "
    
    # Warten bis Container laufen
    log "Warte auf Container-Start..."
    sleep 30
    
    log "Container gestartet"
}

# Health-Checks durchführen
run_health_checks() {
    log "Führe Health-Checks durch..."
    
    # Container-Status
    CONTAINER_STATUS=$(ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "
        cd '$DEPLOY_DIR'
        docker-compose ps
    ")
    log "Container-Status:"
    echo "$CONTAINER_STATUS"
    
    # Health-Checks
    log "Health-Checks:"
    
    # Rails-App Health-Check
    if ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "curl -f http://localhost:3000/health > /dev/null 2>&1"; then
        log "✅ Rails-App läuft"
    else
        warning "❌ Rails-App nicht erreichbar"
    fi
    
    # Nginx Health-Check
    if ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "curl -f http://localhost/health > /dev/null 2>&1"; then
        log "✅ Nginx läuft"
    else
        warning "❌ Nginx nicht erreichbar"
    fi
    
    # PostgreSQL Health-Check
    if ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "
        cd '$DEPLOY_DIR'
        docker-compose exec -T db pg_isready -U www_data > /dev/null 2>&1
    "; then
        log "✅ PostgreSQL läuft"
    else
        warning "❌ PostgreSQL nicht erreichbar"
    fi
    
    # Redis Health-Check
    if ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "
        cd '$DEPLOY_DIR'
        docker-compose exec -T redis redis-cli ping > /dev/null 2>&1
    "; then
        log "✅ Redis läuft"
    else
        warning "❌ Redis nicht erreichbar"
    fi
}

# Tests ausführen
run_tests() {
    if [[ "$SKIP_TESTS" == true ]]; then
        log "Tests übersprungen"
        return
    fi
    
    log "Führe Tests auf Raspberry Pi aus..."
    
    ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "
        cd '$DEPLOY_DIR'
        chmod +x bin/test-raspberry-pi.sh
        ./bin/test-raspberry-pi.sh --cleanup
    "
    
    log "Tests abgeschlossen"
}

# Deployment-Report generieren
generate_deployment_report() {
    log "Generiere Deployment-Report..."
    
    REPORT_FILE="deployment-report-$(date +%Y%m%d_%H%M%S).txt"
    
    # System-Informationen sammeln
    SYSTEM_INFO=$(ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "
        echo '=== System Information ==='
        uname -a
        echo ''
        echo '=== Docker Information ==='
        docker --version
        docker-compose --version
        echo ''
        echo '=== Container Status ==='
        cd '$DEPLOY_DIR'
        docker-compose ps
        echo ''
        echo '=== System Resources ==='
        free -h
        df -h /
        echo ''
        echo '=== Docker Images ==='
        docker images carambus/carambus
    ")
    
    # Report erstellen
    cat > "$REPORT_FILE" << EOF
Carambus Raspberry Pi Deployment Report
======================================
Datum: $(date)
Host: $RASPBERRY_PI_HOST
User: $RASPBERRY_PI_USER
Deploy-Verzeichnis: $DEPLOY_DIR

$SYSTEM_INFO

Health-Checks:
- Rails-App: $(ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "curl -f http://localhost:3000/health > /dev/null 2>&1 && echo 'OK' || echo 'FAILED'")
- Nginx: $(ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "curl -f http://localhost/health > /dev/null 2>&1 && echo 'OK' || echo 'FAILED'")
- PostgreSQL: $(ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "cd '$DEPLOY_DIR' && docker-compose exec -T db pg_isready -U www_data > /dev/null 2>&1 && echo 'OK' || echo 'FAILED'")
- Redis: $(ssh -p "$RASPBERRY_PI_PORT" "$RASPBERRY_PI_USER@$RASPBERRY_PI_HOST" "cd '$DEPLOY_DIR' && docker-compose exec -T redis redis-cli ping > /dev/null 2>&1 && echo 'OK' || echo 'FAILED'")

Zugriff:
- Web-Interface: http://$RASPBERRY_PI_HOST
- HTTPS: https://$RASPBERRY_PI_HOST
- SSH: ssh -p $RASPBERRY_PI_PORT $RASPBERRY_PI_USER@$RASPBERRY_PI_HOST
EOF
    
    log "Deployment-Report erstellt: $REPORT_FILE"
}

# Hauptfunktion
main() {
    log "Starte Remote Deployment auf Raspberry Pi..."
    log "Host: $RASPBERRY_PI_HOST"
    log "User: $RASPBERRY_PI_USER"
    log "Port: $RASPBERRY_PI_PORT"
    log "Deploy-Verzeichnis: $DEPLOY_DIR"
    
    test_ssh_connection
    check_raspberry_pi_prerequisites
    create_backup
    transfer_files
    generate_ssl_certificate
    build_docker_image
    start_containers
    run_health_checks
    run_tests
    generate_deployment_report
    
    log "Remote Deployment erfolgreich abgeschlossen!"
    log "Carambus ist verfügbar unter: http://$RASPBERRY_PI_HOST"
    log "Deployment-Report: $REPORT_FILE"
}

# Script ausführen
main "$@" 