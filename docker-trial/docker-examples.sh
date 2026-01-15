#!/bin/bash

# Carambus Docker Deployment Examples
# Zeigt Beispiele für verschiedene Deployment-Typen

set -e

# Farben für Ausgabe
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging-Funktionen
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "=== Carambus Docker Deployment Examples ==="
echo ""

# API Server Examples
log "1. API Server Deployments"
echo "   # Standard API Server (newapi.carambus.de)"
echo "   ./deploy-docker.sh api-server www-data@carambus.de:8910 /var/www/carambus_api"
echo ""

# Local Server Examples
log "2. Local Server Deployments"
echo "   # Standard Local Server (carambus.de)"
echo "   ./deploy-docker.sh local-server pi@192.168.178.53"
echo ""
echo "   # Location-spezifischer Server (carambus.berlin.de)"
echo "   ./deploy-docker.sh local-server-berlin pi@192.168.178.54 berlin"
echo ""
echo "   # Location-spezifischer Server (carambus.muenchen.de)"
echo "   ./deploy-docker.sh local-server-muenchen pi@192.168.178.55 muenchen"
echo ""

# Development Examples
log "3. Development Deployments"
echo "   # Lokale Entwicklungsumgebung (Mac)"
echo "   ./deploy-docker.sh development localhost"
echo ""
echo "   # API Server Entwicklung"
echo "   DEPLOYMENT_TYPE=API_SERVER ./deploy-docker.sh development localhost"
echo ""

# Environment Examples
log "4. Environment-Konfiguration"
echo "   # API Server Environment"
echo "   cp env.api-server .env"
echo "   # Bearbeite .env nach Bedarf"
echo ""
echo "   # Local Server Environment"
echo "   cp env.local-server .env"
echo "   # Bearbeite .env nach Bedarf"
echo ""
echo "   # Development Environment"
echo "   cp env.development .env"
echo "   # Bearbeite .env nach Bedarf"
echo ""

# Docker Compose Examples
log "5. Docker Compose Verwendung"
echo "   # API Server starten"
echo "   docker compose -f docker-compose.api-server.yml up -d"
echo ""
echo "   # Local Server starten"
echo "   docker compose -f docker-compose.local-server.yml up -d"
echo ""
echo "   # Development starten"
echo "   docker compose -f docker-compose.development.yml up -d"
echo ""

# Database Examples
log "6. Datenbank-Beispiele"
echo "   # API Server Datenbank"
echo "   DATABASE_NAME=carambus_api_production"
echo "   DB_DUMP_FILE=carambus_api_production.sql.gz"
echo ""
echo "   # Local Server Datenbank"
echo "   DATABASE_NAME=carambus_production"
echo "   DB_DUMP_FILE=carambus_production.sql.gz"
echo ""
echo "   # Location-spezifische Datenbank"
echo "   DATABASE_NAME=carambus_production_berlin"
echo "   DB_DUMP_FILE=carambus_production_berlin.sql.gz"
echo ""

# Port Examples
log "7. Port-Konfiguration"
echo "   # Standard-Ports (alle Deployment-Typen)"
echo "   WEB_PORT=3000      # Rails App"
echo "   POSTGRES_PORT=5432 # PostgreSQL"
echo "   REDIS_PORT=6379    # Redis"
echo ""

# SSL Examples
log "8. SSL-Konfiguration"
echo "   # API Server (HTTPS erforderlich)"
echo "   DOMAIN=newapi.carambus.de"
echo "   USE_HTTPS=true"
echo ""
echo "   # Local Server (HTTPS empfohlen)"
echo "   DOMAIN=carambus.de"
echo "   USE_HTTPS=true"
echo ""
echo "   # Development (kein HTTPS)"
echo "   DOMAIN="
echo "   USE_HTTPS=false"
echo ""

# Troubleshooting Examples
log "9. Troubleshooting"
echo "   # Container-Status prüfen"
echo "   docker compose ps"
echo ""
echo "   # Logs anzeigen"
echo "   docker compose logs -f web"
echo ""
echo "   # Datenbank-Verbindung testen"
echo "   docker compose exec postgres pg_isready -U www_data"
echo ""
echo "   # Rails-Konsole öffnen"
echo "   docker compose exec web rails console"
echo ""

# Migration Examples
log "10. Migration von bestehenden Deployments"
echo "   # Von alter Struktur migrieren"
echo "   # 1. Backup erstellen"
echo "   docker compose exec postgres pg_dump -U www_data carambus_production > backup.sql"
echo ""
echo "   # 2. Neue Struktur deployen"
echo "   ./deploy-docker.sh local-server pi@192.168.178.53"
echo ""
echo "   # 3. Daten wiederherstellen"
echo "   docker compose exec -T postgres psql -U www_data carambus_production < backup.sql"
echo ""

echo "=== Weitere Informationen ==="
echo "   - Detaillierte Dokumentation: docs/DOCKER_ARCHITECTURE.md"
echo "   - Deployment-Script: deploy-docker.sh"
echo "   - Docker Compose Dateien: docker-compose.*.yml"
echo "   - Environment-Dateien: env.*"
echo ""

log "Beispiele abgeschlossen!"
echo "Verwende './deploy-docker.sh --help' für weitere Informationen." 