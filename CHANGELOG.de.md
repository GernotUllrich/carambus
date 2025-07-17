# Changelog

Alle wichtigen Änderungen am Carambus-Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
und dieses Projekt folgt der [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Hinzugefügt
- Umfassende Entwicklerdokumentation
- API-Dokumentation mit Beispielen
- Open Source-Projektstruktur
- Beitragsrichtlinien

### Geändert
- README mit Projektübersicht aktualisiert
- Dokumentationsorganisation verbessert

## [2.0.0] - 2024-01-15

### Hinzugefügt
- Rails 7.2 Upgrade mit Hotwire-Integration
- Stimulus Reflex für reaktive UI-Updates
- Action Cable Echtzeit-Funktionen
- Umfassendes Turnierverwaltungssystem
- Ligaverwaltung mit Team-Unterstützung
- Echtzeit-Scoreboard-Anzeigen
- Mehrsprachige Unterstützung (Deutsch/Englisch)
- Externe Datensynchronisation (BA/CC)
- Regionsbasierte Datenorganisation
- Erweiterte Benutzerverwaltung mit Rollen
- Administratives Interface über Administrate
- Hintergrund-Job-Verarbeitung
- API-Endpunkte für externe Integrationen

### Geändert
- Komplette Neuerstellung vom Legacy-System
- Moderne Web-Architektur mit WebSocket-Unterstützung
- Responsive Design für Mobilgeräte
- Verbessertes Datenmodell mit Concerns
- Erweiterte Sicherheit mit Pundit-Autorisierung

### Behoben
- Datensynchronisationsprobleme
- Echtzeit-Update-Zuverlässigkeit
- Scoreboard-Anzeigegenauigkeit
- Turnier-Workflow-Bugs

## [1.5.0] - 2023-06-20

### Hinzugefügt
- Turnierplanungsverbesserungen
- Erweiterte Spielerverwaltung
- Bessere Ligaorganisation
- Scoreboard-Autostart-Funktionalität

### Geändert
- Datenbankschema aktualisiert
- Benutzeroberfläche verbessert
- Erweiterte Datenvalidierung

### Behoben
- Verschiedene Bug-Fixes und Leistungsverbesserungen

## [1.4.0] - 2023-03-15

### Hinzugefügt
- Echtzeit-Scoreboard-Funktionen
- Tischüberwachungssystem
- Spielergebnisverfolgung
- Spielerranglisten-System

### Geändert
- Verbesserte Turnier-Workflows
- Erweiterte Datensynchronisation
- Bessere Fehlerbehandlung

## [1.3.0] - 2022-11-10

### Hinzugefügt
- Ligaverwaltungssystem
- Team-basierte Turniere
- Saisonverwaltung
- Erweiterte Berichterstattung

### Geändert
- Datenbankoptimierung
- Leistungsverbesserungen
- UI/UX-Verbesserungen

## [1.2.0] - 2022-07-25

### Hinzugefügt
- Turnierverwaltungssystem
- Spielerregistrierung
- Grundlegende Scoreboard-Funktionalität
- Datenimport/Export

### Geändert
- Verbessertes Datenbankdesign
- Erweiterte Benutzeroberfläche
- Bessere Datenvalidierung

## [1.1.0] - 2022-04-12

### Hinzugefügt
- Benutzerauthentifizierungssystem
- Grundlegende Turnierfunktionen
- Spielerverwaltung
- Standortverwaltung

### Geändert
- Initiale Rails-Anwendungsstruktur
- Datenbankschema-Design
- Grundlegende UI-Implementierung

## [1.0.0] - 2022-01-01

### Hinzugefügt
- Initiale Projekteinrichtung
- Grundlegende Rails-Anwendung
- PostgreSQL-Datenbank
- Entwicklungsumgebung

### Geändert
- Projektinitialisierung
- Entwicklungsworkflow-Setup
- Dokumentationsstruktur

---

## Versionshistorie Zusammenfassung

### Hauptversionen

#### v2.0.0 (Aktuell)
- **Moderne Rails-Anwendung**: Komplette Neuerstellung mit Rails 7.2 und modernen Webtechnologien
- **Echtzeit-Funktionen**: WebSocket-gestützte Scoreboards und Live-Updates
- **Umfassende Verwaltung**: Vollständiges Turnier- und Ligaverwaltungssystem
- **Externe Integration**: BA/CC-Datensynchronisation
- **Mehrsprachig**: Deutsche und englische Unterstützung

#### v1.x Serie
- **Grundlage**: Grundlegende Turnierverwaltung und Benutzersystem
- **Evolution**: Schrittweise Feature-Ergänzungen und Verbesserungen
- **Stabilität**: Produktionsreifes System für Billard-Clubs

### Technologie-Evolution

#### Aktueller Stack (v2.0+)
- **Backend**: Ruby on Rails 7.2
- **Frontend**: Hotwire (Turbo + Stimulus) + Stimulus Reflex
- **Datenbank**: PostgreSQL mit erweitertem Modell
- **Echtzeit**: Action Cable mit Redis
- **Deployment**: Capistrano + Puma + Nginx

#### Legacy Stack (v1.x)
- **Backend**: Ruby on Rails 6.x
- **Frontend**: Traditionelle server-gerenderte Views
- **Datenbank**: PostgreSQL
- **Deployment**: Benutzerdefinierte Deployment-Skripte

### Wichtige Meilensteine

#### 2024 - Open Source Release
- Umfassende Dokumentation
- Entwicklerfreundliche Struktur
- Community-Beitragsrichtlinien
- API-Dokumentation

#### 2023 - Produktionssystem
- Echtzeit-Scoreboards
- Turnierautomatisierung
- Datensynchronisation
- Multi-Standort-Unterstützung

#### 2022 - Initiale Entwicklung
- Projektkonzeption
- Grundlegende Funktionalität
- Benutzerverwaltung
- Turnierplanung

---

## Beitrag zum Changelog

Beim Hinzufügen von Einträgen zum Changelog, bitte folgen Sie diesen Richtlinien:

### Kategorien
- **Hinzugefügt**: Neue Features
- **Geändert**: Änderungen an bestehender Funktionalität
- **Veraltet**: Bald zu entfernende Features
- **Entfernt**: Entfernte Features
- **Behoben**: Bug-Fixes
- **Sicherheit**: Sicherheitsbezogene Änderungen

### Format
- Verwenden Sie klare, prägnante Beschreibungen
- Fügen Sie relevante Issue-Nummern ein
- Gruppieren Sie verwandte Änderungen zusammen
- Behalten Sie chronologische Reihenfolge innerhalb von Versionen

### Beispiele
```markdown
### Hinzugefügt
- Neuer Turnier-Erstellungswizard (#123)
- Echtzeit-Scoreboard-Updates (#124, #125)

### Behoben
- Turnierplanungs-Bug (#126)
- Scoreboard-Anzeigeprobleme (#127)
```

---

*Dieses Changelog wird vom Carambus-Entwicklungsteam gepflegt. Für Fragen oder Beiträge siehe den [Beitragsleitfaden](docs/DEVELOPER_GUIDE.de.md#mitwirken).* 