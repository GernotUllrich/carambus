#!/bin/bash
# Carambus Installation Script
# Automatische Installation eines Carambus-Servers auf Raspberry Pi

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

# Prüfung der Voraussetzungen
check_prerequisites() {
    log "Prüfe Voraussetzungen..."
    
    # Prüfe ob wir auf einem Raspberry Pi sind
    if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
        warning "Dieses Script ist für Raspberry Pi optimiert"
    fi
    
    # Prüfe verfügbaren Speicherplatz
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 5000000 ]; then
        error "Nicht genügend Speicherplatz verfügbar (mindestens 5GB erforderlich)"
    fi
    
    # Prüfe Internet-Verbindung
    if ! ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        error "Keine Internet-Verbindung verfügbar"
    fi
    
    log "Voraussetzungen erfüllt"
}

# System-Updates
update_system() {
    log "Führe System-Updates durch..."
    
    sudo apt update
    sudo apt upgrade -y
    sudo apt autoremove -y
    
    log "System-Updates abgeschlossen"
}

# Docker installieren
install_docker() {
    log "Installiere Docker..."
    
    if command -v docker > /dev/null 2>&1; then
        log "Docker ist bereits installiert"
        return
    fi
    
    # Docker installieren
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    
    # Docker Compose installieren
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    log "Docker Installation abgeschlossen"
}

# Carambus-Konfiguration erstellen
setup_carambus_config() {
    log "Erstelle Carambus-Konfiguration..."
    
    # Verzeichnisstruktur erstellen
    sudo mkdir -p /opt/carambus/{config,storage,log,backup}
    sudo chown -R $USER:$USER /opt/carambus
    
    # Docker Compose Datei erstellen
    cat > /opt/carambus/docker-compose.yml << 'EOF'
version: '3.8'
services:
  app:
    image: carambus/carambus:latest
    ports:
      - "3000:3000"
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgresql://www_data:carambus_password@db:5432/carambus_production
    depends_on:
      - db
      - redis
    volumes:
      - ./config:/rails/config
      - ./storage:/rails/storage
      - ./log:/rails/log
    restart: unless-stopped

  db:
    image: postgres:13
    environment:
      - POSTGRES_DB=carambus_production
      - POSTGRES_USER=www_data
      - POSTGRES_PASSWORD=carambus_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  redis:
    image: redis:6-alpine
    volumes:
      - redis_data:/data
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - app
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
EOF

    # Nginx-Konfiguration erstellen
    cat > /opt/carambus/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream carambus_app {
        server app:3000;
    }

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://carambus_app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /cable {
            proxy_pass http://carambus_app;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
        }
    }
}
EOF

    log "Carambus-Konfiguration erstellt"
}

# Scoreboard-Autostart konfigurieren
setup_scoreboard_autostart() {
    log "Konfiguriere Scoreboard-Autostart..."
    
    # Scoreboard-URL konfigurieren
    cat > /opt/carambus/config/scoreboard_url << 'EOF'
http://localhost:3000/locations/1/scoreboard_reservations
EOF

    # Autostart-Script erstellen
    cat > /opt/carambus/bin/autostart-scoreboard.sh << 'EOF'
#!/bin/bash
# Autostart wrapper for scoreboard

# Create log file with timestamp
echo "=== Autostart script started at $(date) ===" >> /tmp/scoreboard-autostart.log

# Set proper environment
export DISPLAY=:0
export XAUTHORITY=/home/pi/.Xauthority

# Wait for display system to be ready
sleep 5

# Wait for Rails server (Docker container) to be ready
echo "Waiting for Rails server to start..." >> /tmp/scoreboard-autostart.log
while ! curl -s http://localhost:3000/health > /dev/null; do
    echo "Waiting for Rails server..." >> /tmp/scoreboard-autostart.log
    sleep 5
done

# Check if wmctrl is available
if ! command -v wmctrl &> /dev/null; then
    echo "wmctrl not found, installing..." >> /tmp/scoreboard-autostart.log
    sudo apt update && sudo apt install -y wmctrl
fi

# Hide panel before starting
wmctrl -r "panel" -b add,hidden 2>/dev/null || true
wmctrl -r "lxpanel" -b add,hidden 2>/dev/null || true

# Start browser in true fullscreen
/usr/bin/chromium-browser --start-fullscreen --disable-restore-session-state --disable-web-security --app="$(cat /opt/carambus/config/scoreboard_url)" &

# Wait for browser to start
sleep 3

# Make sure it's fullscreen
wmctrl -r "Chromium" -b add,fullscreen 2>/dev/null || true

echo "Scoreboard started successfully" >> /tmp/scoreboard-autostart.log
EOF

    chmod +x /opt/carambus/bin/autostart-scoreboard.sh

    # LXDE Autostart konfigurieren
    mkdir -p ~/.config/lxsession/LXDE-pi
    cat > ~/.config/lxsession/LXDE-pi/autostart << 'EOF'
@lxpanel --profile LXDE-pi
@pcmanfm --desktop --profile LXDE-pi
@xscreensaver --no-splash
@/opt/carambus/bin/autostart-scoreboard.sh
EOF

    log "Scoreboard-Autostart konfiguriert"
}

# Carambus Container starten
start_carambus() {
    log "Starte Carambus Container..."
    
    cd /opt/carambus
    
    # Container starten
    docker-compose up -d
    
    # Warten bis alle Services verfügbar sind
    log "Warte auf Services..."
    while ! curl -s http://localhost:3000/health > /dev/null; do
        sleep 5
    done
    
    log "Carambus erfolgreich gestartet"
}

# Setup-Webinterface starten
start_setup_interface() {
    log "Starte Setup-Webinterface..."
    
    # Setup-Controller erstellen (falls nicht vorhanden)
    if [ ! -f /opt/carambus/app/controllers/setup_controller.rb ]; then
        cat > /opt/carambus/app/controllers/setup_controller.rb << 'EOF'
class SetupController < ApplicationController
  def index
    # Setup-Wizard anzeigen
  end
  
  def configure_location
    # Location konfigurieren
  end
  
  def configure_tables
    # Tische definieren
  end
  
  def configure_users
    # Benutzer anlegen
  end
end
EOF
    fi
    
    log "Setup-Webinterface verfügbar unter: http://localhost:3000/setup"
}

# Hauptfunktion
main() {
    log "Starte Carambus Installation..."
    
    check_prerequisites
    update_system
    install_docker
    setup_carambus_config
    setup_scoreboard_autostart
    start_carambus
    start_setup_interface
    
    log "Installation abgeschlossen!"
    log "Öffnen Sie http://localhost:3000/setup im Browser um die Lokalisierung zu konfigurieren"
    log "Scoreboard wird automatisch beim nächsten Boot gestartet"
}

# Script ausführen
main "$@" 