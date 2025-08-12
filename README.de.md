# Carambus - Turnier-Management-System

## Übersicht

Carambus ist ein umfassendes Turnier-Management-System für Billard-Clubs und -Turniere. Es bietet eine moderne Web-Oberfläche für die Verwaltung von Spielern, Turnieren, Spielplänen und Live-Scoreboards.

## 🚀 Features

### Turnier-Management
- **Spieler-Verwaltung**: Vollständige Spielerdatenbank mit Statistiken
- **Turnier-Organisation**: Flexible Turnierformate und Spielpläne
- **Live-Scoreboards**: Echtzeit-Updates für Zuschauer und Spieler
- **Ergebnisverfolgung**: Automatische Berechnung von Ranglisten

### Club-Management
- **Club-Verwaltung**: Mehrere Clubs und Standorte
- **Tisch-Management**: Spieltische mit verschiedenen Disziplinen
- **Benutzer-Rollen**: Admin, Club-Manager, Spieler
- **Berichte**: Detaillierte Statistiken und Auswertungen

### Technische Features
- **Responsive Design**: Funktioniert auf allen Geräten
- **Real-time Updates**: Live-Updates über WebSockets
- **Multi-Sprache**: Deutsch und Englisch
- **API**: RESTful API für Integrationen

## 🏗️ Architektur

### System-Komponenten
- **Web-Anwendung**: Rails 7.2 mit Hotwire/Stimulus
- **Datenbank**: PostgreSQL mit erweiterten Features
- **Cache**: Redis für Session-Management und Caching
- **Web-Server**: Puma mit Nginx
- **Scoreboard**: Vollbild-Browser-Interface

### Deployment
- **Docker**: Containerisierte Bereitstellung
- **Docker Compose**: Multi-Service-Orchestrierung
- **Umgebungsvariablen**: Flexible Konfiguration
- **Health Checks**: Automatische Überwachung

## 📋 Voraussetzungen

### System-Anforderungen
- **Betriebssystem**: Linux (Ubuntu 20.04+), macOS, Windows mit WSL2
- **Docker**: Version 20.10+
- **Docker Compose**: Version 2.0+
- **RAM**: Mindestens 2GB (4GB empfohlen)
- **Speicher**: Mindestens 10GB freier Speicher

### Für Raspberry Pi
- **Modell**: Raspberry Pi 4 (2GB RAM minimum, 4GB empfohlen)
- **SD-Karte**: 32GB minimum, Class 10 empfohlen
- **Betriebssystem**: Raspberry Pi OS (Desktop für Scoreboard, Lite für Server)

## 🚀 Schnellstart

### 1. Repository klonen
```bash
git clone https://github.com/your-repo/carambus_api.git
cd carambus_api
```

### 2. Umgebungsvariablen konfigurieren
```bash
cp env.example .env
# Bearbeite .env mit deinen Werten
nano .env
```

### 3. Container starten
```bash
docker-compose up -d
```

### 4. Datenbank einrichten
```bash
# Migrationen ausführen
docker-compose exec web bundle exec rails db:migrate

# Seed-Daten laden (optional)
docker-compose exec web bundle exec rails db:seed
```

### 5. Anwendung aufrufen
- **Web-Interface**: http://localhost:3000
- **Scoreboard**: http://localhost:3000/scoreboard

## 🔧 Konfiguration

### Umgebungsvariablen

#### Basis-Konfiguration
```bash
# Datenbank
DATABASE_NAME=carambus_development
DATABASE_USER=www_data
DATABASE_PASSWORD=your_password

# Redis
REDIS_DB=0

# Rails
RAILS_ENV=development
RAILS_MASTER_KEY=your_master_key
```

#### Deployment-spezifische Konfiguration
```bash
# Für API-Server
DEPLOYMENT_TYPE=API_SERVER
CARAMBUS_API_URL=https://newapi.carambus.de

# Für Local-Server
DEPLOYMENT_TYPE=LOCAL_SERVER
CARAMBUS_API_URL=https://newapi.carambus.de

# Für Web-Client
DEPLOYMENT_TYPE=WEB_CLIENT
```

### Docker-Compose-Konfiguration

#### Development-Modus
```bash
# Einzelnes System
docker-compose -f docker-compose.development.local-server.yml up

# Alle Systeme parallel (für Inter-System-Tests)
./start-development-parallel.sh
```

#### Production-Modus
```bash
# API-Server
docker-compose -f docker-compose.production.api-server.yml up

# Local-Server
docker-compose -f docker-compose.production.local-server.yml up
```

## 📱 Scoreboard-Setup

### Raspberry Pi Konfiguration
```bash
# Auto-Login aktivieren
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

### Display-Optimierung
```bash
# Bildschirmauflösung anpassen
sudo raspi-config
# -> Advanced Options -> Resolution

# GPU-Memory erhöhen
sudo raspi-config
# -> Advanced Options -> Memory Split -> 128

# Bildschirmschoner deaktivieren
sudo raspi-config
# -> Display Options -> Screen Blanking -> Disable
```

## 🔄 Updates

### Automatische Updates
```bash
# Crontab für automatische Updates
crontab -e

# Täglich um 2:00 Uhr aktualisieren
0 2 * * * cd /home/pi/carambus && git pull && docker compose up -d --build
```

### Manuelle Updates
```bash
# Repository aktualisieren
git pull

# Container neu bauen und starten
docker-compose down
docker-compose up -d --build
```

## 🚨 Troubleshooting

### Häufige Probleme

#### Container startet nicht
```bash
# Docker-Status prüfen
sudo systemctl status docker

# Logs anschauen
docker compose logs

# Container neu starten
docker compose restart
```

#### Scoreboard startet nicht
```bash
# Browser-Cache leeren
rm -rf ~/.cache/chromium

# Browser neu starten
pkill chromium
chromium-browser --start-fullscreen --app=http://localhost:3000/scoreboard
```

#### Netzwerk-Probleme
```bash
# IP-Adresse prüfen
ip addr show

# Netzwerk neu starten
sudo systemctl restart networking
```

### Log-Analyse
```bash
# Alle Logs
docker compose logs -f

# Nur Rails-Logs
docker compose logs -f web

# Nur Datenbank-Logs
docker compose logs -f postgres
```

## 📊 Monitoring

### System-Überwachung
```bash
# Container-Status
docker compose ps

# Ressourcen-Verbrauch
docker stats

# System-Ressourcen
htop
```

### Health Checks
```bash
# Anwendungs-Status
curl http://localhost:3000/health

# Datenbank-Status
docker compose exec postgres pg_isready

# Redis-Status
docker compose exec redis redis-cli ping
```

## 🔒 Sicherheit

### Firewall-Konfiguration
```bash
# Nur notwendige Ports öffnen
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 3000/tcp  # Web-Anwendung
sudo ufw enable
```

### SSL/TLS (für Production)
```bash
# SSL-Zertifikate konfigurieren
# Nginx-Konfiguration anpassen
# HTTPS erzwingen
```

## 📚 Dokumentation

### Installation & Setup
- **[Quickstart Guide](docs/INSTALLATION/QUICKSTART.md)** - Haupt-Installations-Guide
- **[Raspberry Pi Setup](docs/INSTALLATION/RASPBERRY_PI_SETUP.md)** - Detaillierte Pi-Anleitung
- **[Docker Setup](docs/INSTALLATION/DOCKER_SETUP.md)** - Docker-Konfiguration

### Entwicklung
- **[Docker Structure](docs/DEVELOPMENT/DOCKER_STRUCTURE.md)** - Docker-Architektur
- **[API Reference](docs/DEVELOPMENT/API_REFERENCE.md)** - API-Dokumentation

### Wartung
- **[Troubleshooting](docs/MAINTENANCE/TROUBLESHOOTING.md)** - Fehlerbehebung
- **[Backup & Restore](docs/MAINTENANCE/BACKUP_RESTORE.md)** - Backup-Verfahren

## 🤝 Beitragen

### Entwicklung
1. Repository forken
2. Feature-Branch erstellen
3. Änderungen committen
4. Pull Request erstellen

### Bug Reports
- GitHub Issues verwenden
- Reproduzierbare Schritte beschreiben
- Logs und Screenshots beifügen

## 📄 Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert. Siehe [LICENSE](LICENSE) für Details.

## 🆘 Support

### Bei Problemen
1. Prüfen Sie die **[Troubleshooting](docs/MAINTENANCE/TROUBLESHOOTING.md)**-Seite
2. Logs anschauen: `docker compose logs`
3. Container-Status: `docker compose ps`
4. GitHub Issues durchsuchen

### Community
- **GitHub Discussions**: Für Fragen und Diskussionen
- **Wiki**: Für detaillierte Anleitungen
- **Code of Conduct**: Für ein respektvolles Miteinander

---

**🎉 Willkommen bei Carambus!**

**💡 Tipp**: Für die Entwicklung verwenden Sie die parallelen Docker-Systeme, um Inter-System-Kommunikation zu testen!

**🏗️ Architektur**: 2 Production-Modi - API-Server (zentral) und Local-Server (mit Carambus API URL), beide im Development-Modus testbar! 