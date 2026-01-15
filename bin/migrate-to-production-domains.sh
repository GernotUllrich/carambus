#!/bin/bash
# Skript zur Migration von newapi/new.carambus.de zu api/carambus.de
# Muss auf dem Hetzner-Server als www-data ausgeführt werden

set -e

echo "=========================================="
echo "Domain Migration: newapi/new → api/carambus.de"
echo "=========================================="
echo ""

# Farben
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Funktionen
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Prüfen, ob als www-data ausgeführt wird
if [ "$USER" != "www-data" ]; then
    print_warning "Dieses Skript sollte als www-data User ausgeführt werden"
    echo "Führe aus: ssh -p 8910 www-data@carambus.de"
fi

# Phase 1: API-Server (newapi → api)
echo "Phase 1: API-Server Migration (newapi.carambus.de → api.carambus.de)"
echo "----------------------------------------------------------------------"
echo ""

# Prüfen, ob SSL-Zertifikat existiert
if [ ! -d "/etc/letsencrypt/live/api.carambus.de" ]; then
    print_warning "SSL-Zertifikat für api.carambus.de existiert noch nicht"
    echo "Erstelle Zertifikat mit:"
    echo "  sudo certbot certonly --nginx -d api.carambus.de"
    echo ""
    read -p "Zertifikat erstellen? (j/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Jj]$ ]]; then
        sudo certbot certonly --nginx -d api.carambus.de
        print_success "Zertifikat erstellt"
    else
        print_error "Zertifikat wird benötigt. Abbruch."
        exit 1
    fi
fi

# Nginx-Config für api.carambus.de erstellen
echo "Erstelle nginx-Config für api.carambus.de..."
if [ -f "/etc/nginx/sites-available/newapi.carambus.de" ]; then
    # Kopiere und ersetze Domain-Namen
    sudo cp /etc/nginx/sites-available/newapi.carambus.de /tmp/api.carambus.de.tmp
    
    # Ersetze alle Vorkommen von newapi mit api
    sudo sed -i 's/newapi\.carambus\.de/api.carambus.de/g' /tmp/api.carambus.de.tmp
    
    # In sites-available kopieren
    sudo cp /tmp/api.carambus.de.tmp /etc/nginx/sites-available/api.carambus.de
    sudo rm /tmp/api.carambus.de.tmp
    
    print_success "Nginx-Config für api.carambus.de erstellt"
else
    print_error "Vorlage /etc/nginx/sites-available/newapi.carambus.de nicht gefunden"
    exit 1
fi

# Symlink erstellen
echo "Erstelle Symlink..."
sudo ln -sf /etc/nginx/sites-available/api.carambus.de /etc/nginx/sites-enabled/api.carambus.de
print_success "Symlink erstellt"

# Nginx testen
echo ""
echo "Teste nginx-Konfiguration..."
if sudo nginx -t; then
    print_success "Nginx-Konfiguration OK"
else
    print_error "Nginx-Konfiguration fehlerhaft!"
    echo "Behebe Fehler manuell und führe das Skript erneut aus"
    exit 1
fi

# Nginx neu laden
echo ""
echo "Lade nginx neu..."
if sudo systemctl reload nginx; then
    print_success "Nginx neu geladen"
else
    print_error "Nginx reload fehlgeschlagen"
    exit 1
fi

echo ""
print_success "Phase 1 abgeschlossen!"
echo ""
echo "Teste jetzt: curl -I https://api.carambus.de"
echo ""

# Phase 2: Main Server (new → carambus)
read -p "Weiter mit Phase 2 (new.carambus.de → carambus.de)? (j/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Jj]$ ]]; then
    echo "Migration pausiert. Führe das Skript später erneut aus."
    exit 0
fi

echo ""
echo "Phase 2: Main Server Migration (new.carambus.de → carambus.de)"
echo "----------------------------------------------------------------------"
echo ""

# Prüfen, ob SSL-Zertifikat existiert
if [ ! -d "/etc/letsencrypt/live/carambus.de" ]; then
    print_warning "SSL-Zertifikat für carambus.de existiert noch nicht"
    echo "Erstelle Zertifikat mit:"
    echo "  sudo certbot certonly --nginx -d carambus.de"
    echo ""
    read -p "Zertifikat erstellen? (j/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Jj]$ ]]; then
        sudo certbot certonly --nginx -d carambus.de
        print_success "Zertifikat erstellt"
    else
        print_error "Zertifikat wird benötigt. Abbruch."
        exit 1
    fi
fi

# Nginx-Config für carambus.de erstellen
echo "Erstelle nginx-Config für carambus.de..."
if [ -f "/etc/nginx/sites-available/new.carambus.de" ]; then
    # Kopiere und ersetze Domain-Namen
    sudo cp /etc/nginx/sites-available/new.carambus.de /tmp/carambus.de.tmp
    
    # Ersetze alle Vorkommen von new.carambus.de mit carambus.de
    sudo sed -i 's/new\.carambus\.de/carambus.de/g' /tmp/carambus.de.tmp
    
    # In sites-available kopieren
    sudo cp /tmp/carambus.de.tmp /etc/nginx/sites-available/carambus.de
    sudo rm /tmp/carambus.de.tmp
    
    print_success "Nginx-Config für carambus.de erstellt"
else
    print_error "Vorlage /etc/nginx/sites-available/new.carambus.de nicht gefunden"
    exit 1
fi

# Symlink erstellen
echo "Erstelle Symlink..."
sudo ln -sf /etc/nginx/sites-available/carambus.de /etc/nginx/sites-enabled/carambus.de
print_success "Symlink erstellt"

# Nginx testen
echo ""
echo "Teste nginx-Konfiguration..."
if sudo nginx -t; then
    print_success "Nginx-Konfiguration OK"
else
    print_error "Nginx-Konfiguration fehlerhaft!"
    echo "Behebe Fehler manuell"
    exit 1
fi

# Nginx neu laden
echo ""
echo "Lade nginx neu..."
if sudo systemctl reload nginx; then
    print_success "Nginx neu geladen"
else
    print_error "Nginx reload fehlgeschlagen"
    exit 1
fi

echo ""
print_success "Phase 2 abgeschlossen!"
echo ""
echo "=========================================="
echo "✅ Migration abgeschlossen!"
echo "=========================================="
echo ""
echo "Teste die neuen Domains:"
echo "  curl -I https://api.carambus.de"
echo "  curl -I https://carambus.de"
echo ""
echo "Aktive nginx-Configs:"
ls -la /etc/nginx/sites-enabled/ | grep carambus
echo ""
print_warning "Die alten Configs (newapi, new) sind noch aktiv!"
echo "Entferne sie erst, wenn alles funktioniert und alle Clients aktualisiert sind."
echo ""
echo "Alte Configs entfernen mit:"
echo "  sudo rm /etc/nginx/sites-enabled/newapi.carambus.de"
echo "  sudo rm /etc/nginx/sites-enabled/new.carambus.de"
echo "  sudo systemctl reload nginx"
