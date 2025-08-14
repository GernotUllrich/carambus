# Changelog

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Neue Docker-basierte Installation für Raspberry Pi
- Automatisierte Scoreboard-Konfiguration
- Web-basiertes Setup-Interface
- Parallele Development-Systeme für Mac Mini
- Inter-System-Kommunikation zwischen Local-Server und API-Server

### Changed
- Docker-Struktur neu organisiert (Development vs. Production als übergeordnete Modi)
- Port-Zuordnung für parallele Development-Systeme
- Umgebungsdateien für verschiedene Deployment-Typen
- Dokumentation konsolidiert und redundanzfrei gemacht

### Fixed
- Korrekte Architektur: 2 Production-Modi (API-Server zentral, Local-Server mit Carambus API URL)
- Development-Modus als übergeordneter Modus für alle Systeme
- Port-Konflikte bei parallelen Development-Systemen

## [7.2.0] - 2024-12-19

### Added
- Rails 7.2 Upgrade
- Hotwire/Stimulus Integration
- Action Cable für Echtzeit-Updates
- Administrate Admin-Interface
- Devise für Authentifizierung
- Pundit für Autorisierung

### Changed
- Ruby 3.2+ Unterstützung
- PostgreSQL als Hauptdatenbank
- Redis für Caching und Action Cable
- Puma als Web-Server
- Nginx als Reverse Proxy

### Fixed
- Performance-Optimierungen
- Sicherheitsverbesserungen
- Code-Qualität verbessert

## [7.1.0] - 2024-06-15

### Added
- Turnier-Management-System
- Spieler-Verwaltung
- Ligaverwaltung
- Live-Scoreboards
- Echtzeit-Updates

### Changed
- Moderne Web-Oberfläche
- Responsive Design
- Multi-Sprache (Deutsch/Englisch)
- API für Integrationen

### Fixed
- Stabilität verbessert
- Benutzerfreundlichkeit erhöht

## [7.0.0] - 2024-01-10

### Added
- Grundlegende Carambus-Funktionalität
- Billard-Turnierverwaltung
- Club-Management
- Benutzer-Verwaltung

### Changed
- Ruby on Rails Basis
- PostgreSQL Datenbank
- Moderne Web-Technologien

### Fixed
- Erste stabile Version
- Grundfunktionen implementiert

---

**Hinweis**: Alle Versionen vor 7.0.0 sind Legacy-Versionen und werden nicht mehr unterstützt.

**Migration**: Für bestehende Installationen siehe [Migration Guide](docs/INSTALLATION/QUICKSTART.md#migration-von-bestehenden-installationen). 