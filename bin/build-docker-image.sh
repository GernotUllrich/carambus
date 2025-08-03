#!/bin/bash
# Carambus Docker Image Build Script
# Erstellt optimierte Docker-Images für verschiedene Plattformen

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
IMAGE_NAME="carambus/carambus"
TAG="latest"
PLATFORM=""
PUSH=false
BUILD_ARGS=""

# Hilfe anzeigen
show_help() {
    cat << EOF
Carambus Docker Image Build Script

Verwendung:
  $0 [OPTIONS]

Optionen:
  -p, --platform PLATFORM    Plattform (raspberry-pi, x86_64, multi)
  -t, --tag TAG              Image-Tag (Standard: latest)
  --push                      Image zu Registry pushen
  -h, --help                 Diese Hilfe anzeigen

Beispiele:
  $0 -p raspberry-pi                    # Raspberry Pi Image bauen
  $0 -p x86_64 -t v1.0.0               # x86_64 Image mit Tag bauen
  $0 -p multi --push                    # Multi-Platform Image bauen und pushen

Plattformen:
  raspberry-pi    ARM32v7 für Raspberry Pi
  x86_64          AMD64 für Server
  multi           Multi-Platform (ARM32v7 + AMD64)
EOF
}

# Argumente parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        --push)
            PUSH=true
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

# Plattform validieren
if [[ -z "$PLATFORM" ]]; then
    error "Plattform muss angegeben werden (-p oder --platform)"
fi

# Prüfung der Voraussetzungen
check_prerequisites() {
    log "Prüfe Voraussetzungen..."
    
    # Docker prüfen
    if ! command -v docker > /dev/null 2>&1; then
        error "Docker ist nicht installiert"
    fi
    
    # Docker daemon prüfen (optional)
    if ! docker info > /dev/null 2>&1; then
        warning "Docker daemon ist nicht erreichbar - nur Konfigurationsvalidierung"
        DOCKER_AVAILABLE=false
    else
        DOCKER_AVAILABLE=true
    fi
    
    # Buildx prüfen
    if [[ "$DOCKER_AVAILABLE" == true ]] && ! docker buildx version > /dev/null 2>&1; then
        warning "Docker buildx nicht verfügbar, verwende Standard builder"
    fi
    
    log "Voraussetzungen erfüllt"
}

# Docker-Image bauen
build_image() {
    log "Baue Docker-Image für Plattform: $PLATFORM"
    
    if [[ "$DOCKER_AVAILABLE" == false ]]; then
        log "Docker nicht verfügbar - führe nur Konfigurationsvalidierung durch"
        validate_configuration
        return
    fi
    
    case $PLATFORM in
        "raspberry-pi")
            build_raspberry_pi_image
            ;;
        "x86_64")
            build_x86_64_image
            ;;
        "multi")
            build_multi_platform_image
            ;;
        *)
            error "Unbekannte Plattform: $PLATFORM"
            ;;
    esac
}

# Konfigurationsvalidierung
validate_configuration() {
    log "Validiere Docker-Konfiguration..."
    
    # Dockerfile prüfen
    if [[ "$PLATFORM" == "raspberry-pi" ]]; then
        if [[ ! -f "Dockerfile.raspberry-pi" ]]; then
            error "Dockerfile.raspberry-pi nicht gefunden"
        fi
        log "✅ Dockerfile.raspberry-pi gefunden"
    else
        if [[ ! -f "Dockerfile" ]]; then
            error "Dockerfile nicht gefunden"
        fi
        log "✅ Dockerfile gefunden"
    fi
    
    # Docker-Compose prüfen
    if [[ "$PLATFORM" == "raspberry-pi" ]]; then
        if [[ ! -f "docker-compose.raspberry-pi.yml" ]]; then
            error "docker-compose.raspberry-pi.yml nicht gefunden"
        fi
        log "✅ docker-compose.raspberry-pi.yml gefunden"
    fi
    
    # Nginx-Konfiguration prüfen
    if [[ ! -f "nginx.conf" ]]; then
        warning "nginx.conf nicht gefunden"
    else
        log "✅ nginx.conf gefunden"
    fi
    
    log "Konfigurationsvalidierung erfolgreich"
}

# Raspberry Pi Image bauen
build_raspberry_pi_image() {
    log "Baue Raspberry Pi Image..."
    
    # Buildx Builder erstellen (falls nicht vorhanden)
    if ! docker buildx inspect carambus-builder > /dev/null 2>&1; then
        docker buildx create --name carambus-builder --use
    fi
    
    # Image bauen
    docker buildx build \
        --platform linux/arm/v7 \
        --file Dockerfile.raspberry-pi \
        --tag "${IMAGE_NAME}:${TAG}-raspberry-pi" \
        --tag "${IMAGE_NAME}:raspberry-pi" \
        --load \
        .
    
    log "Raspberry Pi Image erfolgreich gebaut"
}

# x86_64 Image bauen
build_x86_64_image() {
    log "Baue x86_64 Image..."
    
    # Standard Dockerfile verwenden
    docker build \
        --file Dockerfile \
        --tag "${IMAGE_NAME}:${TAG}-x86_64" \
        --tag "${IMAGE_NAME}:x86_64" \
        .
    
    log "x86_64 Image erfolgreich gebaut"
}

# Multi-Platform Image bauen
build_multi_platform_image() {
    log "Baue Multi-Platform Image..."
    
    # Buildx Builder erstellen
    if ! docker buildx inspect carambus-builder > /dev/null 2>&1; then
        docker buildx create --name carambus-builder --use
    fi
    
    # Multi-Platform Image bauen
    docker buildx build \
        --platform linux/amd64,linux/arm/v7 \
        --file Dockerfile \
        --tag "${IMAGE_NAME}:${TAG}" \
        --tag "${IMAGE_NAME}:latest" \
        .
    
    log "Multi-Platform Image erfolgreich gebaut"
}

# Image testen
test_image() {
    if [[ "$DOCKER_AVAILABLE" == false ]]; then
        log "Docker nicht verfügbar - überspringe Image-Test"
        return
    fi
    
    log "Teste Docker-Image..."
    
    # Container starten
    docker run -d \
        --name carambus_test \
        --rm \
        -p 3000:3000 \
        "${IMAGE_NAME}:${TAG}-${PLATFORM}"
    
    # Warten bis Container läuft
    sleep 10
    
    # Health-Check
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        log "Image-Test erfolgreich"
    else
        warning "Image-Test fehlgeschlagen"
    fi
    
    # Container stoppen
    docker stop carambus_test
}

# Image pushen
push_image() {
    if [[ "$PUSH" == true ]]; then
        if [[ "$DOCKER_AVAILABLE" == false ]]; then
            warning "Docker nicht verfügbar - überspringe Push"
            return
        fi
        
        log "Pushe Docker-Image..."
        
        # Login prüfen
        if ! docker info | grep -q "Username"; then
            error "Docker-Login erforderlich für Push"
        fi
        
        # Image pushen
        docker push "${IMAGE_NAME}:${TAG}-${PLATFORM}"
        docker push "${IMAGE_NAME}:${PLATFORM}"
        
        log "Image erfolgreich gepusht"
    fi
}

# Image-Informationen anzeigen
show_image_info() {
    log "Image-Informationen:"
    echo "===================="
    echo "Name: ${IMAGE_NAME}"
    echo "Tag: ${TAG}-${PLATFORM}"
    echo "Plattform: $PLATFORM"
    
    if [[ "$DOCKER_AVAILABLE" == true ]]; then
        echo "Größe: $(docker images ${IMAGE_NAME}:${TAG}-${PLATFORM} --format 'table {{.Size}}' | tail -1)"
    else
        echo "Größe: Nicht verfügbar (Docker nicht erreichbar)"
    fi
    
    echo ""
    echo "Verwendung:"
    echo "docker run -d -p 3000:3000 ${IMAGE_NAME}:${TAG}-${PLATFORM}"
    echo ""
    echo "Docker-Compose:"
    if [[ "$PLATFORM" == "raspberry-pi" ]]; then
        echo "docker-compose -f docker-compose.raspberry-pi.yml up -d"
    else
        echo "docker-compose up -d"
    fi
}

# Cleanup
cleanup() {
    log "Führe Cleanup durch..."
    
    # Alte Images löschen (optional)
    if [[ "$1" == "--cleanup" ]]; then
        docker image prune -f
    fi
    
    log "Cleanup abgeschlossen"
}

# Hauptfunktion
main() {
    log "Starte Docker-Image Build..."
    
    check_prerequisites
    build_image
    test_image
    push_image
    show_image_info
    cleanup
    
    log "Docker-Image Build erfolgreich abgeschlossen!"
}

# Script ausführen
main "$@" 