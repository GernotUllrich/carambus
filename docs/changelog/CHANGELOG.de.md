# Changelog

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> 🇬🇧 **English Version**: [../../CHANGELOG.md](../../CHANGELOG.md)

## [Unreleased]

### Hinzugefügt
- **Datenbank-Analyse-Tool** (`bin/check-database-states.sh`)
  - Umfassende Analyse von Datenbank-Zuständen über Local, Production und API Server
  - Vergleicht Version-IDs, table_locals und tournament_locals
  - Warnt bei unbumped IDs (< 50.000.000)
  - Zeigt ID-Bereiche und lokale Daten-Statistiken
  - Verwendung: `./bin/check-database-states.sh <scenario_name>`

- **Puma-Service-Wrapper** (`bin/puma-wrapper.sh`)
  - Korrekte rbenv-Initialisierung für Puma systemd-Service
  - Wechselt ins richtige Deployment-Verzeichnis
  - Verwendung: `puma-wrapper.sh <basename>` oder via `PUMA_BASENAME` Umgebungsvariable

- **Multi-WLAN-Unterstützung** für Raspberry Pi Client Setup
  - Konfiguration mehrerer WLAN-Netzwerke möglich
  - Automatischer Wechsel zwischen Entwicklungs- und Produktions-WLAN
  - DHCP für Entwicklungs-WLAN (flexible IP)
  - Statische IP für Produktions-WLAN (stabile Deployment)

### Geändert
- **Raspberry Pi Client Setup** für Debian Trixie-Kompatibilität
  - Von `chromium-browser` auf `chromium` Paket umgestellt (neuere Raspberry Pi OS Versionen)
  - Executable-Pfad von `/usr/bin/chromium-browser` auf `/usr/bin/chromium` aktualisiert
  - Behebt Installationsfehler: "Package chromium-browser is not available"

- **Netzwerk-Konfiguration** intelligenter gemacht
  - Automatische Erkennung von dhcpcd vs. NetworkManager
  - Unterstützung für beide Netzwerk-Management-Systeme
  - Automatische nmcli-Konfiguration für NetworkManager-Systeme

### Behoben
- Chromium-Paket-Installation auf neueren Raspberry Pi OS (Debian Trixie/Bookworm)
- Kompatibilität mit alten (Debian Bullseye) und neuen Raspberry Pi OS Versionen sichergestellt
- NetworkManager-basierte Systeme werden jetzt korrekt erkannt und konfiguriert

## [2025-10-17] - Branch-Integration

### Zusammengeführt
- Branch `scorebord_menu` erfolgreich in master integriert
  - Scoreboard-Menü-Verbesserungen
  - NetworkManager-Unterstützung im Setup-Script
  - Multi-WLAN-Support-Features
  - Automatische Erkennung von dhcpcd vs. NetworkManager

### Kompatibilität
- ✅ Raspberry Pi OS (Debian Bullseye) - Rückwärtskompatibilität erhalten
- ✅ Raspberry Pi OS (Debian Trixie/Bookworm) - Primäre Unterstützung
- ✅ dhcpcd-basierte Netzwerkkonfiguration
- ✅ NetworkManager-basierte Konfiguration

---

## [7.2.0] - 2024-12-19

### Hinzugefügt
- Rails 7.2 Upgrade
- Hotwire/Stimulus Integration
- Action Cable für Echtzeit-Updates
- Administrate Admin-Interface
- Devise für Authentifizierung
- Pundit für Autorisierung

### Geändert
- Ruby 3.2+ Unterstützung
- PostgreSQL als Hauptdatenbank
- Redis für Caching und Action Cable
- Puma als Web-Server
- Nginx als Reverse Proxy

### Behoben
- Performance-Optimierungen
- Sicherheitsverbesserungen
- Code-Qualität verbessert

## [7.1.0] - 2024-06-15

### Hinzugefügt
- Turnier-Management-System
- Spieler-Verwaltung
- Ligaverwaltung
- Live-Scoreboards
- Echtzeit-Updates

### Geändert
- Moderne Web-Oberfläche
- Responsive Design
- Multi-Sprache (Deutsch/Englisch)
- API für Integrationen

### Behoben
- Stabilität verbessert
- Benutzerfreundlichkeit erhöht

## [7.0.0] - 2024-01-10

### Hinzugefügt
- Grundlegende Carambus-Funktionalität
- Billard-Turnierverwaltung
- Club-Management
- Benutzer-Verwaltung

### Geändert
- Ruby on Rails Basis
- PostgreSQL Datenbank
- Moderne Web-Technologien

### Behoben
- Erste stabile Version
- Grundfunktionen implementiert

---

## Deployment-Hinweise

### Raspberry Pi Setup auf Debian Trixie/Bookworm

```bash
sh bin/setup-raspi-table-client.sh carambus_bcw <current_ip> \
  <ssid> <password> <static_ip> <table_number> [ssh_port] [ssh_user] [server_ip]
```

Das Script erkennt automatisch:
- Den korrekten Chromium-Paketnamen
- Das verwendete Netzwerk-Management-System (dhcpcd/NetworkManager)
- Konfiguriert entsprechend WLAN und statische IP

### Datenbank-Analyse

Zum Überprüfen von Datenbank-Zuständen vor/nach Deployments:

```bash
./bin/check-database-states.sh carambus_bcw
```

---

**Hinweis**: Alle Versionen vor 7.0.0 sind Legacy-Versionen und werden nicht mehr unterstützt.

**Migration**: Für bestehende Installationen siehe [Migration Guide](../INSTALLATION/QUICKSTART.md#migration-von-bestehenden-installationen).

---

## Historische Notizen

### Docker-Ansatz (Aufgegeben)

Frühere Versionen experimentierten mit einem Docker-basierten Deployment-Ansatz. Dieser wurde zugunsten der aktuellen Capistrano-basierten Deployment-Strategie aufgegeben. Die Docker-Konfigurationen bleiben im Repository für Referenzzwecke, sind aber nicht mehr der empfohlene Deployment-Weg.

**Aktueller Deployment-Ansatz:**
- Capistrano für Production-Deployments
- Systemd-Services für Puma
- Nginx als Reverse Proxy
- Direkte Server-Installation (keine Container)
