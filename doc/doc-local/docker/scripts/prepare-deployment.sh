#!/bin/bash

# Carambus Deployment Preparation Script
# Läuft auf dem Entwicklungssystem (Mac mini) und bereitet Deployment-Pakete vor

set -euo pipefail

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktionen
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Verwendung: $0 [OPTIONS] <target_type> [location_code]

Zieltypen:
  api-server     - API Server (carambus_api_production)
  local-server   - Lokaler Server (carambus_production)
  location       - Location-spezifischer Server (carambus_production_xyz)

Optionen:
  -o, --output DIR     Ausgabeverzeichnis (Standard: ./deployment-packages)
  -f, --force          Überschreiben existierender Pakete
  -h, --help           Diese Hilfe anzeigen

Beispiele:
  $0 api-server
  $0 local-server
  $0 location berlin
  $0 --output /tmp/carambus-deploy api-server

EOF
}

# Standardwerte
OUTPUT_DIR="./deployment-packages"
FORCE_OVERWRITE=false
TARGET_TYPE=""
LOCATION_CODE=""

# Argumente parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_OVERWRITE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        api-server|local-server|location)
            TARGET_TYPE="$1"
            shift
            ;;
        berlin|muenchen|hamburg|koeln|frankfurt|stuttgart|dortmund|essen|leipzig|bremen)
            if [[ "$TARGET_TYPE" == "location" ]]; then
                LOCATION_CODE="$1"
            else
                print_error "Location-Code nur bei 'location' Zieltyp erlaubt"
                exit 1
            fi
            shift
            ;;
        *)
            print_error "Unbekannter Parameter: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validierung
if [[ -z "$TARGET_TYPE" ]]; then
    print_error "Zieltyp muss angegeben werden"
    show_usage
    exit 1
fi

if [[ "$TARGET_TYPE" == "location" && -z "$LOCATION_CODE" ]]; then
    print_error "Location-Code muss bei 'location' Zieltyp angegeben werden"
    show_usage
    exit 1
fi

# Verzeichnisstruktur definieren
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DATABASES_DIR="$PROJECT_ROOT/doc/doc-local/docker/databases"

# Deployment-Paket-Name generieren
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
if [[ "$TARGET_TYPE" == "location" ]]; then
    PACKAGE_NAME="carambus-${TARGET_TYPE}-${LOCATION_CODE}-${TIMESTAMP}"
else
    PACKAGE_NAME="carambus-${TARGET_TYPE}-${TIMESTAMP}"
fi

PACKAGE_DIR="$OUTPUT_DIR/$PACKAGE_NAME"

print_info "Bereite Deployment-Paket vor: $PACKAGE_NAME"
print_info "Zieltyp: $TARGET_TYPE"
if [[ -n "$LOCATION_CODE" ]]; then
    print_info "Location: $LOCATION_CODE"
fi

# Ausgabeverzeichnis erstellen
mkdir -p "$OUTPUT_DIR"

# Prüfen ob Paket bereits existiert
if [[ -d "$PACKAGE_DIR" && "$FORCE_OVERWRITE" == "false" ]]; then
    print_warning "Deployment-Paket existiert bereits: $PACKAGE_DIR"
    read -p "Überschreiben? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Abgebrochen"
        exit 0
    fi
fi

# Altes Paket entfernen falls vorhanden
if [[ -d "$PACKAGE_DIR" ]]; then
    rm -rf "$PACKAGE_DIR"
fi

# Deployment-Paket-Verzeichnis erstellen
mkdir -p "$PACKAGE_DIR"

print_info "Erstelle Deployment-Paket in: $PACKAGE_DIR"

# 1. Docker-Skripte kopieren
print_info "Kopiere Docker-Skripte..."
cp -r "$PROJECT_ROOT/doc/doc-local/docker/scripts" "$PACKAGE_DIR/"

# 2. Docker Compose Dateien kopieren
print_info "Kopiere Docker Compose Konfigurationen..."
cp "$PROJECT_ROOT/docker-compose.yml" "$PACKAGE_DIR/"
cp "$PROJECT_ROOT/docker-compose.unified.yml" "$PACKAGE_DIR/"
# Legacy-Dateien für Kompatibilität
cp "$PROJECT_ROOT/docker-compose.api-server.yml" "$PACKAGE_DIR/"
cp "$PROJECT_ROOT/docker-compose.local-server.yml" "$PACKAGE_DIR/"
cp "$PROJECT_ROOT/docker-compose.development.yml" "$PACKAGE_DIR/"

# 3. Environment-Dateien kopieren
print_info "Kopiere Environment-Konfigurationen..."
cp "$PROJECT_ROOT/env.example" "$PACKAGE_DIR/"
cp "$PROJECT_ROOT/env.unified" "$PACKAGE_DIR/"
cp "$PROJECT_ROOT/env.api-server" "$PACKAGE_DIR/"
cp "$PROJECT_ROOT/env.local-server" "$PACKAGE_DIR/"
cp "$PROJECT_ROOT/env.development" "$PACKAGE_DIR/"

# 4. Datenbank-Dumps kopieren
print_info "Kopiere Datenbank-Dumps..."

case "$TARGET_TYPE" in
    "api-server")
        # API Server Datenbanken
        if [[ -d "$DATABASES_DIR/api-server" ]]; then
            cp -r "$DATABASES_DIR/api-server" "$PACKAGE_DIR/databases/"
        else
            print_warning "API Server Datenbanken nicht gefunden: $DATABASES_DIR/api-server"
        fi
        ;;
    "local-server")
        # Lokale Server Datenbanken
        if [[ -d "$DATABASES_DIR/local-server" ]]; then
            cp -r "$DATABASES_DIR/local-server" "$PACKAGE_DIR/databases/"
        else
            print_warning "Lokale Server Datenbanken nicht gefunden: $DATABASES_DIR/local-server"
        fi
        ;;
    "location")
        # Location-spezifische Datenbanken
        if [[ -d "$DATABASES_DIR/locations/$LOCATION_CODE" ]]; then
            mkdir -p "$PACKAGE_DIR/databases/locations"
            cp -r "$DATABASES_DIR/locations/$LOCATION_CODE" "$PACKAGE_DIR/databases/locations/"
        else
            print_warning "Location-spezifische Datenbanken nicht gefunden: $DATABASES_DIR/locations/$LOCATION_CODE"
        fi
        ;;
esac

# 5. README und Dokumentation kopieren
if [[ -f "$PROJECT_ROOT/doc/doc-local/docker/README.md" ]]; then
    cp "$PROJECT_ROOT/doc/doc-local/docker/README.md" "$PACKAGE_DIR/"
fi

# 6. Deployment-Skript kopieren
if [[ -f "$PROJECT_ROOT/deploy-docker.sh" ]]; then
    cp "$PROJECT_ROOT/deploy-docker.sh" "$PACKAGE_DIR/"
fi

# 7. Manifest-Datei erstellen
print_info "Erstelle Manifest-Datei..."
cat > "$PACKAGE_DIR/MANIFEST.txt" << EOF
Carambus Deployment-Paket
=========================

Erstellt: $(date)
Zieltyp: $TARGET_TYPE
EOF

if [[ -n "$LOCATION_CODE" ]]; then
    echo "Location: $LOCATION_CODE" >> "$PACKAGE_DIR/MANIFEST.txt"
fi

cat >> "$PACKAGE_DIR/MANIFEST.txt" << EOF

Inhalt:
- Docker-Skripte: scripts/
- Docker Compose: docker-compose.unified.yml (Standard)
- Environment: env.unified (Standard)
- Datenbanken: databases/
- Deployment: deploy-docker.sh

Verwendung auf dem Zielsystem:
1. Paket auf den Zielserver übertragen
2. In das Paket-Verzeichnis wechseln
3. ./deploy-docker.sh ausführen

EOF

# 8. Paket komprimieren
print_info "Komprimiere Deployment-Paket..."
cd "$OUTPUT_DIR"
tar -czf "${PACKAGE_NAME}.tar.gz" "$PACKAGE_NAME"

# 9. Aufräumen
rm -rf "$PACKAGE_NAME"

print_success "Deployment-Paket erfolgreich erstellt: ${PACKAGE_NAME}.tar.gz"
print_info "Paket-Größe: $(du -h "${PACKAGE_NAME}.tar.gz" | cut -f1)"

# Übertragungshinweise
print_info ""
print_info "Nächste Schritte:"
print_info "1. Paket auf den Zielserver übertragen:"
print_info "   scp ${PACKAGE_NAME}.tar.gz user@target-server:/tmp/"
print_info ""
print_info "2. Auf dem Zielserver entpacken und ausführen:"
print_info "   tar -xzf /tmp/${PACKAGE_NAME}.tar.gz"
print_info "   cd ${PACKAGE_NAME}"
print_info "   ./deploy-docker.sh"
print_info ""

# Symlink zum neuesten Paket erstellen
LATEST_LINK="$OUTPUT_DIR/latest-${TARGET_TYPE}"
if [[ -n "$LOCATION_CODE" ]]; then
    LATEST_LINK="${LATEST_LINK}-${LOCATION_CODE}"
fi

ln -sf "${PACKAGE_NAME}.tar.gz" "$LATEST_LINK"
print_info "Symlink erstellt: $LATEST_LINK -> ${PACKAGE_NAME}.tar.gz" 