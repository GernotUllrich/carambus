#!/bin/bash
# Raspberry Pi 4 Setup Script für Carambus
# Bereitet einen Raspberry Pi 4 für Carambus vor

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
UPDATE_SYSTEM=true
INSTALL_DOCKER=true
CONFIGURE_DOCKER=true
SETUP_SSH=true
OPTIMIZE_SYSTEM=true

# Hilfe anzeigen
show_help() {
    cat << EOF
Raspberry Pi 4 Setup Script für Carambus

Verwendung:
  $0 [OPTIONS]

Optionen:
  --no-update              System-Update überspringen
  --no-docker              Docker-Installation überspringen
  --no-docker-config       Docker-Konfiguration überspringen
  --no-ssh                 SSH-Setup überspringen
  --no-optimize            System-Optimierung überspringen
  -h, --help               Diese Hilfe anzeigen

Beispiele:
  $0                                    # Vollständiges Setup
  $0 --no-update                        # Ohne System-Update
  $0 --no-docker --no-optimize          # Minimales Setup
EOF
}

# Argumente parsen
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-update)
            UPDATE_SYSTEM=false
            shift
            ;;
        --no-docker)
            INSTALL_DOCKER=false
            shift
            ;;
        --no-docker-config)
            CONFIGURE_DOCKER=false
            shift
            ;;
        --no-ssh)
            SETUP_SSH=false
            shift
            ;;
        --no-optimize)
            OPTIMIZE_SYSTEM=false
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

# Architektur prüfen
check_architecture() {
    log "Prüfe System-Architektur..."
    
    ARCH=$(uname -m)
    if [[ "$ARCH" != "armv7l" && "$ARCH" != "aarch64" ]]; then
        warning "Nicht auf ARM-Architektur: $ARCH"
        warning "Dieses Script ist für Raspberry Pi optimiert"
    else
        log "✅ ARM-Architektur erkannt: $ARCH"
    fi
    
    # Raspberry Pi spezifische Prüfungen
    if [[ -f "/proc/cpuinfo" ]]; then
        if grep -q "Raspberry Pi" /proc/cpuinfo; then
            log "✅ Raspberry Pi erkannt"
        else
            warning "Raspberry Pi nicht erkannt"
        fi
    fi
}

# System-Update
update_system() {
    if [[ "$UPDATE_SYSTEM" == false ]]; then
        log "System-Update übersprungen"
        return
    fi
    
    log "Führe System-Update durch..."
    
    # Package-Liste aktualisieren
    sudo apt-get update
    
    # System-Upgrade
    sudo apt-get upgrade -y
    
    # Abhängigkeiten installieren
    sudo apt-get install -y \
        curl \
        wget \
        git \
        build-essential \
        python3 \
        python3-pip \
        htop \
        vim \
        tree \
        unzip \
        zip
    
    log "✅ System-Update abgeschlossen"
}

# Docker installieren
install_docker() {
    if [[ "$INSTALL_DOCKER" == false ]]; then
        log "Docker-Installation übersprungen"
        return
    fi
    
    log "Installiere Docker..."
    
    # Alte Docker-Versionen entfernen
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Docker-Repository hinzufügen
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Package-Liste aktualisieren
    sudo apt-get update
    
    # Docker installieren
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Benutzer zur Docker-Gruppe hinzufügen
    sudo usermod -aG docker $USER
    
    # Docker-Service starten
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log "✅ Docker installiert: $(docker --version)"
}

# Docker konfigurieren
configure_docker() {
    if [[ "$CONFIGURE_DOCKER" == false ]]; then
        log "Docker-Konfiguration übersprungen"
        return
    fi
    
    log "Konfiguriere Docker..."
    
    # Docker-Daemon-Konfiguration
    sudo mkdir -p /etc/docker
    cat > /tmp/daemon.json << EOF
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
EOF
    
    sudo mv /tmp/daemon.json /etc/docker/daemon.json
    
    # Docker-Service neu starten
    sudo systemctl restart docker
    
    log "✅ Docker konfiguriert"
}

# SSH konfigurieren
setup_ssh() {
    if [[ "$SETUP_SSH" == false ]]; then
        log "SSH-Setup übersprungen"
        return
    fi
    
    log "Konfiguriere SSH..."
    
    # SSH-Service aktivieren
    sudo systemctl enable ssh
    sudo systemctl start ssh
    
    # SSH-Konfiguration optimieren
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # SSH-Konfiguration anpassen
    sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    # SSH-Service neu starten
    sudo systemctl restart ssh
    
    log "✅ SSH konfiguriert"
}

# System optimieren
optimize_system() {
    if [[ "$OPTIMIZE_SYSTEM" == false ]]; then
        log "System-Optimierung übersprungen"
        return
    fi
    
    log "Optimiere System..."
    
    # CPU-Governor optimieren
    echo 'GOVERNOR="performance"' | sudo tee -a /etc/default/cpufrequtils > /dev/null
    
    # I/O-Scheduler optimieren
    echo 'ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/scheduler}="deadline"' | sudo tee /etc/udev/rules.d/60-ioschedulers.rules > /dev/null
    
    # TCP-Optimierung
    cat >> /tmp/sysctl.conf << EOF
# TCP-Optimierung
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
EOF
    
    sudo cat /tmp/sysctl.conf >> /etc/sysctl.conf
    sudo sysctl -p
    
    # Swap optimieren
    sudo dphys-swapfile swapoff 2>/dev/null || true
    sudo dphys-swapfile uninstall 2>/dev/null || true
    sudo dphys-swapfile setup
    sudo dphys-swapfile swapon
    
    # Autostart optimieren
    sudo systemctl disable bluetooth 2>/dev/null || true
    sudo systemctl disable hciuart 2>/dev/null || true
    
    log "✅ System optimiert"
}

# Firewall konfigurieren
setup_firewall() {
    log "Konfiguriere Firewall..."
    
    # UFW installieren
    sudo apt-get install -y ufw
    
    # Standard-Regeln
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # SSH erlauben
    sudo ufw allow ssh
    
    # HTTP/HTTPS erlauben
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # Docker-Ports erlauben
    sudo ufw allow 3000/tcp
    
    # Firewall aktivieren
    sudo ufw --force enable
    
    log "✅ Firewall konfiguriert"
}

# Monitoring-Tools installieren
install_monitoring() {
    log "Installiere Monitoring-Tools..."
    
    # Basis-Monitoring
    sudo apt-get install -y \
        htop \
        iotop \
        nethogs \
        nload \
        iftop
    
    log "✅ Monitoring-Tools installiert"
}

# System-Informationen anzeigen
show_system_info() {
    log "System-Informationen:"
    echo "===================="
    echo "Architektur: $(uname -m)"
    echo "Betriebssystem: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "CPU: $(grep 'Model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo "RAM: $(free -h | awk 'NR==2{printf "%.1f", $2}')"
    echo "Speicherplatz: $(df -h / | awk 'NR==2{printf "%.1f", $4}') verfügbar"
    echo ""
    echo "Docker: $(docker --version 2>/dev/null || echo 'Nicht installiert')"
    echo "Docker Compose: $(docker-compose --version 2>/dev/null || echo 'Nicht installiert')"
    echo ""
    echo "Netzwerk:"
    ip addr show | grep "inet " | grep -v 127.0.0.1
    echo ""
    echo "Services:"
    sudo systemctl is-active docker ssh ufw
}

# Cleanup
cleanup() {
    log "Führe Cleanup durch..."
    
    # Temporäre Dateien löschen
    rm -f /tmp/daemon.json /tmp/sysctl.conf
    
    # Package-Cache bereinigen
    sudo apt-get autoremove -y
    sudo apt-get autoclean
    
    log "Cleanup abgeschlossen"
}

# Hauptfunktion
main() {
    log "Starte Raspberry Pi 4 Setup..."
    
    check_architecture
    update_system
    install_docker
    configure_docker
    setup_ssh
    optimize_system
    setup_firewall
    install_monitoring
    show_system_info
    cleanup
    
    log "Raspberry Pi 4 Setup erfolgreich abgeschlossen!"
    log ""
    log "Nächste Schritte:"
    log "1. Neustart empfohlen: sudo reboot"
    log "2. Repository klonen: git clone https://github.com/GernotUllrich/carambus.git"
    log "3. Test ausführen: ./bin/test-raspberry-pi.sh"
    log ""
    log "Zugriff:"
    log "- SSH: ssh $USER@$(hostname -I | awk '{print $1}')"
    log "- Web: http://$(hostname -I | awk '{print $1}')"
}

# Script ausführen
main "$@" 