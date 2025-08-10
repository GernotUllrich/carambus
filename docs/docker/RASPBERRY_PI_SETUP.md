# Raspberry Pi Docker Setup - Carambus Scoreboard

## Übersicht
Diese Anleitung beschreibt das Setup eines Carambus Scoreboards auf einem Raspberry Pi mit Docker.

## 🏁 Schnellstart

```bash
# Einfaches Deployment auf Raspberry Pi
./deploy-docker.sh carambus_raspberry pi@192.168.178.53 /home/pi/carambus
```

## 📋 Voraussetzungen

### Hardware
- Raspberry Pi 4 (4GB RAM empfohlen)
- 32GB+ SD-Karte
- Monitor/Display für Scoreboard
- Netzwerkverbindung

### Software (wird automatisch installiert)
- Raspberry Pi OS (Desktop für Scoreboard-Anzeige)
- Docker & Docker Compose
- Git

## 🚀 Schritt-für-Schritt Anleitung

### 1. SD-Karte vorbereiten
```bash
# 1. Raspberry Pi OS Desktop (64-bit) flashen
# 2. SSH während Setup aktivieren
# 3. Optionally VNC für Remote-Desktop
```

### 2. Erstes Login und Updates
```bash
# Mit Pi verbinden
ssh pi@192.168.178.53

# System aktualisieren
sudo apt update && sudo apt upgrade -y
```

### 3. Deployment ausführen
```bash
# Auf Ihrem lokalen Computer (mit deploy-docker.sh)
./deploy-docker.sh carambus_raspberry pi@192.168.178.53 /home/pi/carambus
```

Das Skript führt automatisch aus:
- Docker Installation
- Repository klonen
- Datenbank-Setup
- Container-Start
- Scoreboard-Konfiguration

### 4. Scoreboard starten
```bash
# Auf dem Raspberry Pi
cd /home/pi/carambus

# Browser im Fullscreen-Modus starten (automatisch)
# Oder manuell:
chromium-browser --start-fullscreen --app=http://localhost:3000/scoreboard
```

## ⚙️ Konfiguration

### Automatische Konfiguration für Raspberry Pi:
- **Port**: 3000 (Standard HTTP)
- **Datenbank**: carambus_production
- **Domain**: localhost
- **SSL**: Deaktiviert (lokaler Zugriff)

### Display-Einstellungen
```bash
# Desktop Auto-Login konfigurieren
sudo raspi-config
# -> System Options -> Boot / Auto Login -> Desktop Autologin

# Browser Autostart einrichten
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

## 🔧 Wartung

### Container-Status prüfen
```bash
cd /home/pi/carambus
docker compose ps
```

### Logs anschauen
```bash
docker compose logs web
docker compose logs postgres
```

### Updates durchführen
```bash
# Neues Deployment ausführen (überschreibt bestehende Installation)
./deploy-docker.sh carambus_raspberry pi@192.168.178.53 /home/pi/carambus
```

## 🎯 Scoreboard-spezifische Features

### Vollbild-Modus
Das Scoreboard läuft automatisch im echten Vollbild-Modus:
- Keine sichtbaren Browser-Leisten
- Keine Desktop-Panels
- Optimiert für Touch-Displays

### Netzwerk-Zugriff
```bash
# Von anderen Geräten im Netzwerk zugreifen:
http://192.168.178.53:3000/scoreboard
```

## 🆘 Troubleshooting

### Container startet nicht
```bash
# Docker-Status prüfen
sudo systemctl status docker

# Logs anschauen
docker compose logs
```

### Display-Probleme
```bash
# Bildschirmauflösung anpassen
sudo raspi-config
# -> Advanced Options -> Resolution

# Browser-Cache leeren
rm -rf ~/.cache/chromium
```

### Performance-Optimierung
```bash
# GPU-Memory erhöhen (für bessere Browser-Performance)
sudo raspi-config
# -> Advanced Options -> Memory Split -> 128
```

## 📊 Monitoring

### System-Ressourcen
```bash
# CPU/RAM Verbrauch
htop

# Docker Container Ressourcen
docker stats
```

### Automatischer Neustart
```bash
# Crontab für automatischen Neustart bei Problemen
crontab -e

# Alle 5 Minuten prüfen und neu starten wenn nötig
*/5 * * * * cd /home/pi/carambus && docker compose up -d
```

---

**💡 Tipp**: Für ein produktives Scoreboard empfiehlt sich ein Raspberry Pi 4 mit mindestens 4GB RAM und eine schnelle SD-Karte (Class 10 oder besser).