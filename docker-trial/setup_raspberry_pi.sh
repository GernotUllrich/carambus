#!/bin/bash

# Carambus Raspberry Pi Setup Script
# Führt die komplette Installation auf einer frischen SD-Karte durch

set -e

echo "🚀 Carambus Raspberry Pi Setup gestartet..."
echo "=============================================="

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktionen
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Prüfe ob wir als root laufen
if [ "$EUID" -ne 0 ]; then
    log_error "Dieses Skript muss als root ausgeführt werden!"
    log_info "Verwendung: sudo ./setup_raspberry_pi.sh"
    exit 1
fi

# System Update
log_info "Aktualisiere System..."
apt update && apt upgrade -y
log_success "System aktualisiert"

# Installiere notwendige Pakete
log_info "Installiere notwendige Pakete..."
apt install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw
log_success "Pakete installiert"

# Docker installieren
log_info "Installiere Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh
log_success "Docker installiert"

# Docker Compose installieren
log_info "Installiere Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
log_success "Docker Compose installiert"

# User zur docker Gruppe hinzufügen
log_info "Konfiguriere Docker-Berechtigungen..."
usermod -aG docker $SUDO_USER
log_success "Docker-Berechtigungen konfiguriert"

# SSH-Konfiguration verbessern
log_info "Konfiguriere SSH..."
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
# PasswordAuthentication bleibt aktiv für initiales Setup
# sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh
log_success "SSH konfiguriert"

# Firewall konfigurieren
log_info "Konfiguriere Firewall..."
ufw allow 22/tcp   # SSH
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS
ufw allow 3000/tcp # Rails App
ufw --force enable
log_success "Firewall konfiguriert"

# Carambus Repository klonen
log_info "Klone Carambus Repository..."
cd /home/$SUDO_USER
if [ -d "carambus" ]; then
    log_warning "Verzeichnis carambus existiert bereits. Überspringe..."
else
    # Verwende SSH-URL für dein Repository (als pi User)
    sudo -u $SUDO_USER git clone git@github.com:GernotUllrich/carambus.git || {
        log_warning "SSH-Klon fehlgeschlagen!"
        log_error "Bitte konfiguriere SSH-Key für GitHub:"
        log_info "1. ssh-keygen -t ed25519 -C 'pi@raspberrypi'"
        log_info "2. cat ~/.ssh/id_ed25519.pub"
        log_info "3. Füge Key zu GitHub hinzu: Settings → SSH and GPG keys"
        log_info "4. Führe dann manuell aus: git clone git@github.com:GernotUllrich/carambus.git"
        exit 1
    }
    chown -R $SUDO_USER:$SUDO_USER carambus
fi
log_success "Repository geklont"

# Umgebungsvariablen konfigurieren
log_info "Konfiguriere Umgebungsvariablen..."
cd carambus
if [ ! -f ".env" ]; then
    cp env.example .env
    log_warning "Bitte bearbeite .env mit deinen Werten!"
    log_info "Wichtige Werte:"
    log_info "  - POSTGRES_PASSWORD: Sicheres Passwort für PostgreSQL"
    log_info "  - RAILS_MASTER_KEY: Dein Rails Master Key"
else
    log_info ".env Datei existiert bereits"
fi
chown $SUDO_USER:$SUDO_USER .env
log_success "Umgebungsvariablen konfiguriert"

# Datenbank-Initialisierung vorbereiten
log_info "Bereite Datenbank-Initialisierung vor..."
mkdir -p db/init
chown -R $SUDO_USER:$SUDO_USER db/
log_success "Datenbank-Initialisierung vorbereitet"

# Docker Service starten
log_info "Starte Docker Service..."
systemctl enable docker
systemctl start docker
log_success "Docker Service gestartet"

# Container bauen und starten
log_info "Baue und starte Docker Container..."
sudo -u $SUDO_USER docker-compose build
sudo -u $SUDO_USER docker-compose up -d
log_success "Container gestartet"

# Status prüfen
log_info "Prüfe Container-Status..."
sleep 10
sudo -u $SUDO_USER docker-compose ps

# Finale Konfiguration
log_info "Finale Konfiguration..."
echo "export PATH=\$PATH:/usr/local/bin" >> /home/$SUDO_USER/.bashrc
chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.bashrc

# Nützliche Aliase
cat >> /home/$SUDO_USER/.bashrc << 'EOF'

# Carambus Aliase
alias carambus-status='docker-compose ps'
alias carambus-logs='docker-compose logs'
alias carambus-restart='docker-compose restart'
alias carambus-stop='docker-compose down'
alias carambus-start='docker-compose up -d'
alias carambus-shell='docker-compose exec web bash'
alias carambus-db='docker-compose exec postgres psql -U carambus -d carambus_production'
EOF

chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.bashrc

# Erfolgsmeldung
echo ""
echo "🎉 CARAMBUS SETUP ABGESCHLOSSEN!"
echo "=================================="
echo ""
echo "✅ Docker installiert und konfiguriert"
echo "✅ Carambus Repository geklont"
echo "✅ Container gestartet"
echo "✅ Firewall konfiguriert"
echo "✅ SSH gesichert"
echo ""
echo "📋 Nächste Schritte:"
echo "1. Bearbeite .env Datei mit deinen Werten"
echo "2. Kopiere deine SQL-Datei nach db/init/ (falls vorhanden)"
echo "3. Führe Datenbank-Migrationen aus:"
echo "   docker-compose exec web bundle exec rails db:migrate"
echo ""
echo "🔧 Nützliche Befehle:"
echo "  carambus-status    - Container-Status anzeigen"
echo "  carambus-logs      - Logs anzeigen"
echo "  carambus-restart   - Container neu starten"
echo "  carambus-shell     - Rails-Shell öffnen"
echo "  carambus-db        - PostgreSQL-Shell öffnen"
echo ""
echo "🌐 Anwendung erreichbar unter:"
echo "  HTTP:  http://$(hostname -I | awk '{print $1}'):80"
echo "  HTTPS: https://$(hostname -I | awk '{print $1}'):443"
echo "  Rails: http://$(hostname -I | awk '{print $1}'):3000"
echo ""
echo "⚠️  WICHTIG: Bearbeite .env Datei bevor du die Anwendung verwendest!"
echo ""
log_success "Setup abgeschlossen!" 