# 🍓 Raspberry Pi 4 Setup für Carambus

## 📋 Übersicht

Diese Anleitung beschreibt das vollständige Setup eines Carambus-Systems auf einem Raspberry Pi 4. Es werden zwei Varianten unterstützt:
- **Scoreboard-Modus**: Für Turnier-Displays mit Desktop-Interface
- **Server-Modus**: Für lokale Server ohne Display

## 🚀 Schnellstart

### Option 1: Automatisches Deployment (Empfohlen)
```bash
# Einfaches Deployment auf Raspberry Pi
./deploy-docker.sh carambus_raspberry www-data@192.168.178.53:8910 /var/www/carambus
```

### Option 2: Manuelles Setup
```bash
# Setup-Skript herunterladen und ausführen
wget https://raw.githubusercontent.com/your-repo/carambus_api/main/setup_raspberry_pi.sh
chmod +x setup_raspberry_pi.sh
sudo ./setup_raspberry_pi.sh
```

## 📋 Voraussetzungen

### Hardware
- **Raspberry Pi 4** (2GB RAM minimum, 4GB empfohlen)
- **SD-Karte** (32GB minimum, Class 10 empfohlen)
- **Netzwerkverbindung** (Ethernet oder WiFi)
- **Monitor/Display** (für Scoreboard-Modus)
- **SSH-Zugang** zum Raspberry Pi

### Software
- Raspberry Pi OS (Desktop für Scoreboard, Lite für Server)
- Docker & Docker Compose (wird automatisch installiert)
- Git mit SSH-Zugang

## 🚀 Schritt-für-Schritt Anleitung

### Phase 1: SD-Karte vorbereiten

#### 1.1 Raspberry Pi OS installieren
1. **Raspberry Pi Imager** herunterladen: https://www.raspberrypi.com/software/
2. **Raspberry Pi OS Desktop** (für Scoreboard) oder **Lite** (für Server) auswählen
3. **SD-Karte** einlegen und **Schreiben** starten
4. **SSH aktivieren** (Advanced Options → Enable SSH)
5. **VNC aktivieren** (für Scoreboard-Modus, optional)
6. **SD-Karte** in Raspberry Pi einlegen und starten

#### 1.2 Erstes Login und Updates
```bash
# Mit www-data verbinden
ssh -p 8910 www-data@192.168.178.XX  # Ersetze XX mit der IP deines Pi

# SSH-Schlüssel-Authentifizierung erforderlich

# System aktualisieren
sudo apt update && sudo apt upgrade -y

# Notwendige Pakete installieren
sudo apt install -y curl wget git vim htop
```

### Phase 2: Docker Installation

#### 2.1 Docker installieren
```bash
# Docker installieren
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh

# User zur docker Gruppe hinzufügen
sudo usermod -aG docker $USER

# Neustart für Gruppen-Änderungen
sudo reboot
```

#### 2.2 Docker Compose installieren
```bash
# Docker Compose herunterladen
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Ausführbar machen
sudo chmod +x /usr/local/bin/docker-compose

# Oder über apt (neuere Versionen)
sudo apt install docker-compose-plugin -y
```

### Phase 3: Carambus Installation

#### 3.1 Repository klonen
```bash
# Repository klonen
git clone https://github.com/your-repo/carambus_api.git
cd carambus_api

# Umgebungsvariablen konfigurieren
cp env.example .env
nano .env  # Bearbeite die Werte
```

#### 3.2 Container starten
```bash
# Container bauen und starten
docker-compose up -d

# Status prüfen
docker-compose ps
```

## ⚙️ Konfiguration

### .env Datei bearbeiten
```bash
nano .env
```

**Wichtige Werte:**
```bash
POSTGRES_PASSWORD=dein_sicheres_passwort
RAILS_MASTER_KEY=dein_rails_master_key
DEPLOYMENT_TYPE=LOCAL_SERVER  # oder WEB_CLIENT für Scoreboard
```

### Datenbank einrichten

**Option A: Mit SQL-Datei**
```bash
# SQL-Datei kopieren
cp carambus_api_development_20250803_084807.sql.gz db/init/

# Container neu starten
docker-compose restart postgres
```

**Option B: Mit Rails Migrations**
```bash
# Migrationen ausführen
docker-compose exec web bundle exec rails db:migrate
```

## 🎯 Scoreboard-spezifische Konfiguration

### Desktop Auto-Login konfigurieren
```bash
sudo raspi-config
# -> System Options -> Boot / Auto Login -> Desktop Autologin
```

### Browser Autostart einrichten
```bash
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/carambus-scoreboard.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Carambus Scoreboard
Exec=chromium-browser --start-fullscreen --app=http://localhost:3000/scoreboard
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
```

### Display-Einstellungen optimieren
```bash
# Bildschirmauflösung anpassen
sudo raspi-config
# -> Advanced Options -> Resolution

# GPU-Memory erhöhen (für bessere Browser-Performance)
sudo raspi-config
# -> Advanced Options -> Memory Split -> 128

# Bildschirmschoner deaktivieren
sudo raspi-config
# -> Display Options -> Screen Blanking -> Disable
```

## 🔧 Nützliche Befehle

Das Setup-Skript erstellt automatisch nützliche Aliase:

```bash
carambus-status    # Container-Status anzeigen
carambus-logs      # Logs anzeigen
carambus-restart   # Container neu starten
carambus-stop      # Container stoppen
carambus-start     # Container starten
carambus-shell     # Rails-Shell öffnen
carambus-db        # PostgreSQL-Shell öffnen
```

## 🌐 Zugriff auf die Anwendung

Nach dem Setup ist die Anwendung erreichbar unter:

- **HTTP:** http://PI_IP_ADRESSE:3000
- **Scoreboard:** http://PI_IP_ADRESSE:3000/scoreboard
- **Von anderen Geräten:** http://192.168.178.XX:3000

## 🔒 Sicherheit

Das Setup-Skript konfiguriert automatisch:

- ✅ **SSH-Sicherung** (kein Root-Login, nur Key-Authentifizierung)
- ✅ **Firewall** (nur notwendige Ports offen)
- ✅ **Docker-Isolation** (Container laufen isoliert)

## 🚨 Troubleshooting

### Docker startet nicht
```bash
# Docker Service Status prüfen
sudo systemctl status docker

# Docker Service starten
sudo systemctl start docker
```

### Container starten nicht
```bash
# Logs anzeigen
docker-compose logs

# Container neu starten
docker-compose restart
```

### Ports sind belegt
```bash
# Andere Ports in docker-compose.yml verwenden
nano docker-compose.yml
# Ändere z.B. "3000:3000" zu "3001:3000"
```

### Speicherplatz voll
```bash
# Docker-Images aufräumen
docker system prune -a

# Logs aufräumen
docker-compose logs --tail=100
```

### Display-Probleme (Scoreboard)
```bash
# Browser-Cache leeren
rm -rf ~/.cache/chromium

# Browser neu starten
pkill chromium
chromium-browser --start-fullscreen --app=http://localhost:3000/scoreboard
```

## 📊 Monitoring

### System-Ressourcen prüfen
```bash
htop
```

### Docker-Ressourcen prüfen
```bash
docker stats
```

### Logs überwachen
```bash
# Alle Logs
docker-compose logs -f

# Nur Rails-Logs
docker-compose logs -f web
```

### Automatischer Neustart (Scoreboard)
```bash
# Crontab für automatischen Neustart bei Problemen
crontab -e

# Alle 5 Minuten prüfen und neu starten wenn nötig
*/5 * * * * cd /home/pi/carambus && docker compose up -d
```

## 🔄 Updates

### Carambus aktualisieren
```bash
# Repository aktualisieren
git pull

# Container neu bauen und starten
docker-compose down
docker-compose up -d --build
```

### System aktualisieren
```bash
sudo apt update && sudo apt upgrade -y
```

### Neues Deployment (überschreibt bestehende Installation)
```bash
./deploy-docker.sh carambus_raspberry pi@192.168.178.53 /home/pi/carambus
```

## 📞 Support

Bei Problemen:

1. **Logs prüfen:** `docker-compose logs`
2. **Status prüfen:** `docker-compose ps`
3. **Container neu starten:** `docker-compose restart`
4. **System neu starten:** `sudo reboot`

## 🎯 Scoreboard-spezifische Features

### Vollbild-Modus
Das Scoreboard läuft automatisch im echten Vollbild-Modus:
- Keine sichtbaren Browser-Leisten
- Keine Desktop-Panels
- Optimiert für Touch-Displays

### Performance-Optimierung
- GPU-Memory auf 128MB erhöht
- Bildschirmschoner deaktiviert
- Automatischer Neustart bei Problemen

---

**🎉 Das ist alles! Dein Raspberry Pi läuft jetzt mit Carambus in Docker!**

**💡 Tipp**: Für ein produktives Scoreboard empfiehlt sich ein Raspberry Pi 4 mit mindestens 4GB RAM und eine schnelle SD-Karte (Class 10 oder besser). 