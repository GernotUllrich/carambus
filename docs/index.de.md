# Carambus Dokumentation

Willkommen bei der Carambus-Dokumentation! Dieses Verzeichnis enthält umfassende Dokumentation für das Carambus Billard-Turnierverwaltungssystem.

## 🎯 Schnellstart nach Zielgruppe

### 🎯 Für Entscheider
Sie evaluieren Carambus für Ihren Verein oder Verband?
**Start**: [Entscheider-Übersicht](decision-makers/index.md)

### 🎮 Für Spieler
Sie nutzen Carambus als Turnierteilnehmer?
**Start**: [Spieler-Übersicht](players/index.md)

### 🏆 Für Turniermanager
Sie organisieren Turniere und Ligaspieltage?
**Start**: [Manager-Übersicht](managers/index.md)

### 🖥️ Für Systemadministratoren
Sie installieren und betreiben Carambus?
**Start**: [Administrator-Übersicht](administrators/index.md)

### 💻 Für Entwickler
Sie entwickeln mit oder an Carambus?
**Start**: [Entwickler-Übersicht](developers/index.md)

## 📚 Dokumentationsstruktur

Die Dokumentation ist jetzt klar nach Zielgruppen strukturiert:

```
docs/
├── index.md                        # Haupt-Landing-Page
│
├── decision-makers/                # Für Entscheider
│   ├── index.md                   # Übersicht
│   ├── executive-summary.md       # Executive Summary
│   ├── features-overview.md       # Feature-Übersicht
│   └── deployment-options.md      # Deployment-Optionen
│
├── players/                        # Für Spieler
│   ├── index.md                   # Übersicht
│   ├── scoreboard-guide.md        # Scoreboard-Bedienung
│   ├── tournament-participation.md # Turnierteilnahme
│   └── ai-search.md              # KI-Suche
│
├── managers/                       # Für Turniermanager
│   ├── index.md                   # Übersicht
│   ├── tournament-management.md   # Turnierverwaltung
│   ├── league-management.md       # Liga-Management
│   ├── single-tournament.md       # Einzelturnier
│   ├── table-reservation.md       # Tischreservierung
│   ├── admin_roles.md            # Admin-Rollen
│   ├── clubcloud_integration.md   # ClubCloud
│   └── search-filters.md         # Suche & Filter
│
├── administrators/                 # Für Admins
│   ├── index.md                   # Übersicht
│   ├── installation_overview.md   # Installation
│   ├── quickstart_raspberry_pi.md # Raspberry Pi
│   ├── raspberry-pi-client.md     # RasPi Client
│   ├── scoreboard_autostart_setup.md # Autostart
│   ├── server-architecture.md     # Architektur
│   ├── email_configuration.md     # E-Mail
│   └── database-setup.md         # Datenbank
│
├── developers/                     # Für Entwickler
│   ├── index.md                   # Übersicht
│   ├── getting-started.md         # Getting Started
│   ├── developer-guide.md         # Developer Guide
│   ├── database_design.md         # DB-Design
│   ├── er_diagram.md             # ER-Diagramm
│   ├── scenario_management.md     # Scenarios
│   ├── rake-tasks-debugging.md    # Testing
│   ├── deployment_workflow.md     # Deployment
│   ├── data_management.md         # Datenverwaltung
│   ├── database-partitioning.md   # DB-Partitionierung
│   └── ... (weitere tech. Docs)
│
└── reference/                      # Referenz
    ├── API.md                     # API-Doku
    ├── glossary.md                # Glossar
    ├── terms.md                   # AGB
    └── privacy.md                 # Datenschutz
```

## 🔍 Wichtigste Dokumente

### Einstieg
- **[Hauptindex](index.md)**: Übersicht über alle Zielgruppen
- **[Über das Projekt](about.md)**: Hintergrund und Geschichte

### Für Entscheider
- **[Executive Summary](decision-makers/executive-summary.md)**: Kompakter Überblick
- **[Feature-Übersicht](decision-makers/features-overview.md)**: Alle Funktionen
- **[Deployment-Optionen](decision-makers/deployment-options.md)**: Betriebsmodelle im Vergleich

### Für Benutzer
- **[Scoreboard-Anleitung](players/scoreboard-guide.md)**: Bedienung am Tisch
- **[Turnierverwaltung](managers/tournament-management.md)**: Turniere organisieren
- **[Liga-Management](managers/league-management.md)**: Ligaspieltage durchführen

### Für Administratoren
- **[Installation](administrators/installation-overview.md)**: Alle Installationsoptionen
- **[Raspberry Pi Setup](administrators/raspberry-pi-quickstart.md)**: RasPi in 30 Minuten
- **[Server-Architektur](administrators/server-architecture.md)**: System-Übersicht

### Für Entwickler
- **[Getting Started](developers/getting-started.md)**: Entwicklungsumgebung
- **[Developer Guide](developers/developer-guide.md)**: Umfassendes Handbuch
- **[Datenbank-Design](developers/database-design.md)**: Schema und Modelle
- **[API-Referenz](reference/API.md)**: REST-API Dokumentation

## 🌍 Sprachen

Die Dokumentation ist verfügbar in:
- 🇩🇪 **Deutsch** (Primärsprache)
- 🇺🇸 **Englisch** (Übersetzungen für wichtigste Dokumente)

Zum Sprachwechsel verwenden Sie den Language-Selector in der mkdocs-Navigation.

## 🔄 Dokumentationswartung

### Beitrag zur Dokumentation
- Folgen Sie dem [Contribution Guide](developers/developer-guide.md)
- Aktualisieren Sie relevante Dokumentation beim Hinzufügen von Features
- Fügen Sie Code-Beispiele für neue APIs ein
- Behalten Sie Konsistenz über alle Dokumente hinweg

### Dokumentationsstandards
- Verwenden Sie klare, prägnante Sprache
- Fügen Sie praktische Beispiele ein
- Stellen Sie deutsche und englische Versionen bereit, wo angemessen
- Halten Sie Dokumentation mit Code-Änderungen aktuell

### Versionskontrolle
- Dokumentation ist mit der Codebasis versioniert
- Große Änderungen erfordern Dokumentations-Updates
- API-Änderungen müssen vor dem Release dokumentiert werden

## 📞 Hilfe erhalten

### Dokumentation durchsuchen
- Verwenden Sie die **Suchfunktion** (oben rechts in mkdocs)
- Nutzen Sie die **Inhaltsverzeichnisse** jeder Seite
- Prüfen Sie das **[Glossar](reference/glossary.md)** für Fachbegriffe

### Support-Kanäle
- **GitHub Issues**: [https://github.com/GernotUllrich/carambus/issues](https://github.com/GernotUllrich/carambus/issues)
- **E-Mail**: gernot.ullrich@gmx.de
- **Projekt**: [Billardclub Wedel 61 e.V.](http://www.billardclub-wedel.de/)

### Fehlende Dokumentation?
Wenn Sie Dokumentation vermissen oder Fehler finden:
1. Erstellen Sie ein GitHub Issue
2. Oder senden Sie eine E-Mail an gernot.ullrich@gmx.de
3. Pull Requests sind willkommen!

## 🚀 Schnelle Links

### Für neue Benutzer
- [Was ist Carambus?](about.md)
- [Für welche Zielgruppe bin ich?](index.md)
- [Wie installiere ich Carambus?](administrators/installation-overview.md)

### Für erfahrene Benutzer
- [API-Dokumentation](reference/API.md)
- [Datenbank-Schema](developers/database-design.md)
- [Deployment-Workflow](developers/deployment-workflow.md)

---

**Version**: 2.0 (Reorganisiert Dezember 2024)  
**Status**: Vollständig  
**Sprachen**: Deutsch, Englisch

*Willkommen in der neu strukturierten Carambus-Dokumentation! Wählen Sie oben Ihre Zielgruppe für den besten Einstieg.*
