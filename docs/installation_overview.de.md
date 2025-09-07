# 🚀 Installation Übersicht

## 📋 Verfügbare Installations-Guides

### 🎯 Scenario Management (Empfohlen)
**[Scenario Management](scenario_management.md)** - Modernes Deployment-System für verschiedene Carambus-Umgebungen.

**Unterstützte Szenarien:**
- **carambus** - Hauptproduktionsumgebung
- **carambus_location_5101** - Lokale Server-Instanz für Standort 5101
- **carambus_location_2459** - Lokale Server-Instanz für Standort 2459
- **carambus_location_2460** - Lokale Server-Instanz für Standort 2460

**Vorteile des Scenario Management:**
- ✅ Automatisierte Deployments
- ✅ Konsistente Konfiguration
- ✅ Integrierte SSL-Verwaltung
- ✅ Automatische Sequence-Verwaltung
- ✅ Skalierbare Architektur

### 🔧 Manuelle Installation
Für spezielle Anforderungen oder Legacy-Systeme:

- **Raspberry Pi Setup** - Detaillierte Anleitung für Pi-spezifische Installation
- **Ubuntu Server Setup** - Server-spezifische Konfiguration
- **API Server Setup** - Produktions-Server Installation

## 🏗️ Architektur-Übersicht

### Production-Szenarien
1. **API-Server** (`carambus`)
   - Zentrale API für alle Local-Server
   - Domain: newapi.carambus.de
   - Kann auch als Hosting-Server fungieren

2. **Local-Server** (`carambus_location_*`)
   - Lokale Server für Turniere/Clubs
   - Verweist auf API-Server
   - Für Scoreboards und lokale Verwaltung

### Development-Modus
- Alle Szenarien können parallel getestet werden
- Automatische Konfiguration über Scenario Management
- Inter-System-Kommunikation testbar

## 🔑 Wichtige Konfigurationen

### Standard-Account
- **User**: `www-data` (uid=33, gid=33)
- **Home-Verzeichnis**: `/var/www`
- **SSH-Port**: 8910
- **Sudo**: Über `wheel`-Gruppe

### Installationspfade
- **API-Server**: `/var/www/carambus`
- **Local-Server**: `/var/www/carambus_location_*`

## 🚀 Schnellstart

### 1. Scenario erstellen
```bash
# Neues Scenario erstellen
rake "scenario:create[carambus_location_5101]"

# Rails-Root erstellen
rake "scenario:create_rails_root[carambus_location_5101]"
```

### 2. Development-Setup
```bash
# Development-Umgebung einrichten
rake "scenario:setup[carambus_location_5101,development]"
```

### 3. Production-Deployment
```bash
# Vollständiges Production-Deployment
rake "scenario:deploy[carambus_location_5101]"
```

### 4. Automatische Konfiguration
Das Scenario Management konfiguriert automatisch:
- Datenbank (PostgreSQL)
- Cache (Redis)
- Web-Server (Rails + Puma)
- Nginx-Konfiguration
- SSL-Zertifikate (bei HTTPS)
- Sequence-Management

## 📖 Weitere Dokumentation

- **[Scenario Management](scenario_management.md)** - Vollständiger Deployment-Guide
- **[Entwicklerleitfaden](DEVELOPER_GUIDE.md)** - Entwicklerdokumentation
- **[API-Dokumentation](API.md)** - API-Referenz

## 🆘 Support

Bei Problemen:
1. Prüfen Sie die **[Scenario Management](scenario_management.md)**-Seite
2. Logs anschauen: `tail -f log/production.log`
3. Service-Status: `systemctl status puma-carambus`
4. System neu starten: `sudo reboot`

---

**🎯 Ziel**: Einfache, automatisierte Installation von Carambus auf verschiedenen Plattformen mit konsistenter Konfiguration über das Scenario Management System. 