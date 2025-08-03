#!/bin/bash
# SSL-Zertifikat Generator für Carambus
# Erstellt selbst-signierte Zertifikate für Entwicklung und Testing

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
SSL_DIR="./ssl"
CERT_FILE="$SSL_DIR/cert.pem"
KEY_FILE="$SSL_DIR/key.pem"
DAYS=365
COUNTRY="DE"
STATE="Schleswig-Holstein"
CITY="Wedel"
ORGANIZATION="Carambus"
COMMON_NAME="localhost"

# Hilfe anzeigen
show_help() {
    cat << EOF
SSL-Zertifikat Generator für Carambus

Verwendung:
  $0 [OPTIONS]

Optionen:
  -d, --days DAYS           Gültigkeit in Tagen (Standard: 365)
  -c, --country COUNTRY     Land (Standard: DE)
  -s, --state STATE         Bundesland (Standard: Schleswig-Holstein)
  -t, --city CITY           Stadt (Standard: Wedel)
  -o, --org ORGANIZATION    Organisation (Standard: Carambus)
  -n, --name COMMON_NAME    Common Name (Standard: localhost)
  -h, --help               Diese Hilfe anzeigen

Beispiele:
  $0                                    # Standard-Zertifikat erstellen
  $0 -d 730 -n carambus.de             # 2 Jahre gültig für carambus.de
  $0 -c US -s California -t San Francisco  # US-Zertifikat
EOF
}

# Argumente parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--days)
            DAYS="$2"
            shift 2
            ;;
        -c|--country)
            COUNTRY="$2"
            shift 2
            ;;
        -s|--state)
            STATE="$2"
            shift 2
            ;;
        -t|--city)
            CITY="$2"
            shift 2
            ;;
        -o|--org)
            ORGANIZATION="$2"
            shift 2
            ;;
        -n|--name)
            COMMON_NAME="$2"
            shift 2
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
    log "Prüfe Voraussetzungen..."
    
    # OpenSSL prüfen
    if ! command -v openssl > /dev/null 2>&1; then
        error "OpenSSL ist nicht installiert"
    fi
    
    log "Voraussetzungen erfüllt"
}

# SSL-Verzeichnis erstellen
create_ssl_directory() {
    log "Erstelle SSL-Verzeichnis..."
    
    mkdir -p "$SSL_DIR"
    
    log "SSL-Verzeichnis erstellt: $SSL_DIR"
}

# OpenSSL-Konfiguration erstellen
create_openssl_config() {
    log "Erstelle OpenSSL-Konfiguration..."
    
    cat > "$SSL_DIR/openssl.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = $COUNTRY
ST = $STATE
L = $CITY
O = $ORGANIZATION
OU = Development
CN = $COMMON_NAME

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $COMMON_NAME
DNS.2 = localhost
DNS.3 = *.localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF
    
    log "OpenSSL-Konfiguration erstellt"
}

# Private Key erstellen
create_private_key() {
    log "Erstelle Private Key..."
    
    openssl genrsa -out "$KEY_FILE" 2048
    
    log "Private Key erstellt: $KEY_FILE"
}

# Zertifikat erstellen
create_certificate() {
    log "Erstelle Zertifikat..."
    
    openssl req -new -x509 -key "$KEY_FILE" -out "$CERT_FILE" -days "$DAYS" -config "$SSL_DIR/openssl.conf"
    
    log "Zertifikat erstellt: $CERT_FILE"
}

# Zertifikat validieren
validate_certificate() {
    log "Validiere Zertifikat..."
    
    # Zertifikat-Informationen anzeigen
    openssl x509 -in "$CERT_FILE" -text -noout | head -20
    
    # Gültigkeit prüfen
    if openssl x509 -checkend 0 -noout -in "$CERT_FILE"; then
        log "Zertifikat ist gültig"
    else
        error "Zertifikat ist nicht gültig"
    fi
}

# Berechtigungen setzen
set_permissions() {
    log "Setze Berechtigungen..."
    
    chmod 600 "$KEY_FILE"
    chmod 644 "$CERT_FILE"
    
    log "Berechtigungen gesetzt"
}

# Zertifikat-Informationen anzeigen
show_certificate_info() {
    log "Zertifikat-Informationen:"
    echo "========================"
    echo "Land: $COUNTRY"
    echo "Bundesland: $STATE"
    echo "Stadt: $CITY"
    echo "Organisation: $ORGANIZATION"
    echo "Common Name: $COMMON_NAME"
    echo "Gültigkeit: $DAYS Tage"
    echo ""
    echo "Dateien:"
    echo "  Zertifikat: $CERT_FILE"
    echo "  Private Key: $KEY_FILE"
    echo ""
    echo "Verwendung in Nginx:"
    echo "  ssl_certificate $CERT_FILE;"
    echo "  ssl_certificate_key $KEY_FILE;"
    echo ""
    echo "Verwendung in Docker:"
    echo "  - ./ssl:/etc/nginx/ssl:ro"
}

# Cleanup
cleanup() {
    log "Führe Cleanup durch..."
    
    # Temporäre OpenSSL-Konfiguration löschen
    rm -f "$SSL_DIR/openssl.conf"
    
    log "Cleanup abgeschlossen"
}

# Hauptfunktion
main() {
    log "Starte SSL-Zertifikat Generierung..."
    
    check_prerequisites
    create_ssl_directory
    create_openssl_config
    create_private_key
    create_certificate
    validate_certificate
    set_permissions
    show_certificate_info
    cleanup
    
    log "SSL-Zertifikat erfolgreich erstellt!"
}

# Script ausführen
main "$@" 