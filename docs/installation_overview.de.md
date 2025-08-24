# 🚀 Installation Übersicht

## 📋 Verfügbare Installations-Guides

### 🐳 Docker Installation (Empfohlen)
**[Docker Installation](docker_installation.md)** - Vollständiger Guide für die Docker-basierte Installation von Carambus auf verschiedenen Plattformen.

**Unterstützte Plattformen:**
- **Raspberry Pi** - Für lokale Scoreboards und Turniere
- **Ubuntu Server** - Für professionelle Hosting-Umgebungen (z.B. Hetzner)
- **Kombinierte Installation** - API-Server + Local-Server auf derselben Hardware

**Vorteile der Docker-Installation:**
- ✅ Konsistente Umgebung
- ✅ Einfache Migration
- ✅ Minimaler technischer Aufwand
- ✅ Reproduzierbare Installationen
- ✅ Automatische Updates

### 🔧 Manuelle Installation
Für spezielle Anforderungen oder wenn Docker nicht verfügbar ist:

- **Raspberry Pi Setup** - Detaillierte Anleitung für Pi-spezifische Installation
- **Ubuntu Server Setup** - Server-spezifische Konfiguration
- **API Server Setup** - Produktions-Server Installation

## 🏗️ Architektur-Übersicht

### Production-Modi
1. **API-Server** (`/var/www/carambus_api`)
   - Zentrale API für alle Local-Server
   - Domain: newapi.carambus.de
   - Kann auch als Hosting-Server fungieren

2. **Local-Server** (`/var/www/carambus`)
   - Lokale Server für Turniere/Clubs
   - Verweist auf API-Server
   - Für Scoreboards und lokale Verwaltung

### Development-Modus
- Beide Production-Modi können parallel getestet werden
- Auf macOS-Computer mit Docker
- Inter-System-Kommunikation testbar

## 🔑 Wichtige Konfigurationen

### Standard-Account
- **User**: `www-data` (uid=33, gid=33)
- **Home-Verzeichnis**: `/var/www`
- **SSH-Port**: 8910
- **Sudo**: Über `wheel`-Gruppe

### Installationspfade
- **API-Server**: `/var/www/carambus_api`
- **Local-Server**: `/var/www/carambus`

## 🚀 Schnellstart

### 1. Plattform wählen
```bash
# Raspberry Pi
./deploy-docker.sh carambus_raspberry www-data@192.168.178.53:8910 /var/www/carambus

# Ubuntu Server
./deploy-docker.sh carambus_newapi www-data@carambus.de:8910 /var/www/carambus_api
```

### 2. Automatische Konfiguration
Das Deployment-Skript konfiguriert automatisch:
- Docker-Container
- Datenbank (PostgreSQL)
- Cache (Redis)
- Web-Server (Rails + Puma)
- Nginx-Konfiguration
- SSL-Zertifikate (bei HTTPS)

### 3. Lokalisierung (nur für Local-Server)
- Web-basierte Konfiguration
- Region-spezifische Einstellungen
- Scoreboard-Konfiguration

## 📖 Weitere Dokumentation

- **[Docker Installation](docker_installation.md)** - Vollständiger Docker-Guide
- **[Entwicklerleitfaden](DEVELOPER_GUIDE.md)** - Entwicklerdokumentation
- **[API-Dokumentation](API.md)** - API-Referenz

## 🆘 Support

Bei Problemen:
1. Prüfen Sie die **[Docker Installation](docker_installation.md)**-Seite
2. Logs anschauen: `docker compose logs`
3. Container-Status: `docker compose ps`
4. System neu starten: `sudo reboot`

---

**🎯 Ziel**: Einfache, automatisierte Installation von Carambus auf verschiedenen Plattformen mit konsistenter Konfiguration. 