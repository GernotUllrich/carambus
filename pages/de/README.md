# Carambus Dokumentation

Willkommen bei der Carambus-Dokumentation! Dieses Verzeichnis enthält umfassende Dokumentation für das Carambus Billard-Turnierverwaltungssystem.

## 📚 Dokumentationsindex

### Erste Schritte
- **[README.md](../README.md)**: Projektübersicht und Schnellstart-Anleitung
- **[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)**: Umfassender Leitfaden für Entwickler
- **[API.md](API.md)**: Vollständige API-Dokumentation mit Beispielen

### Kern-Dokumentation
- **[database_design.md](database_design.md)**: Datenbankschema und Beziehungen
- **[tournament.md](tournament.md)**: Turnierverwaltungs-Workflows
- **[scoreboard_autostart_setup.md](scoreboard_autostart_setup.md)**: Scoreboard-Konfiguration
- **[data_management.md](data_management.md)**: Datenbehandlungsmuster

### Technische Dokumentation
- **[database_syncing.md](database_syncing.md)**: Datensynchronisation mit externen Quellen
- **[paper_trail_optimization.md](paper_trail_optimization.md)**: Versionsverfolgung-Optimierung
- **[filter_popup_usage.md](filter_popup_usage.md)**: UI-Komponenten-Dokumentation
- **[region_tagging_cleanup_summary.md](region_tagging_cleanup_summary.md)**: Regionsverwaltung

### Deployment & Betrieb
- **[Runbook](../doc/doc/Runbook)**: Produktions-Deployment-Anleitung
- **[Tournament.en.mds](../doc/doc/Tournament.en.mds)**: Turnierverwaltungs-Anleitung
- **[League.en.mds](../doc/doc/League.en.mds)**: Ligaverwaltungs-Anleitung
- **[tischreservierung_heizungssteuerung.md](tischreservierung_heizungssteuerung.md)**: Tischreservierung und Heizungssteuerung (BC Wedel)

### Admin-Dokumentation
- **[admin/user_management.md](admin/user_management.md)**: Benutzerverwaltung
- **[admin_roles.md](admin_roles.md)**: Rollenbasierte Zugriffskontrolle

### Rechtliches & Datenschutz
- **[terms.md](terms.md)**: Nutzungsbedingungen
- **[terms.de.md](terms.de.md)**: Nutzungsbedingungen (Deutsch)
- **[terms.en.md](terms.en.md)**: Nutzungsbedingungen (Englisch)
- **[privacy.md](privacy.md)**: Datenschutzerklärung

### Projektinformationen
- **[about.md](about.md)**: Projekt-Hintergrund und Entwicklerinformationen
- **[about.de.md](about.de.md)**: Projektinformationen (Deutsch)
- **[about.en.md](about.en.md)**: Projektinformationen (Englisch)

## 🎯 Schnelle Navigation

### Für neue Entwickler
1. Beginnen Sie mit **[README.md](../README.md)** für Projektübersicht
2. Lesen Sie **[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)** für Setup-Anweisungen
3. Überprüfen Sie **[database_design.md](database_design.md)** für Datenmodell-Verständnis
4. Prüfen Sie **[API.md](API.md)** für Integrationsmöglichkeiten

### Für Systemadministratoren
1. Überprüfen Sie **[Runbook](../doc/doc/Runbook)** für Deployment
2. Lesen Sie **[scoreboard_autostart_setup.md](scoreboard_autostart_setup.md)** für Scoreboard-Setup
3. Prüfen Sie **[tischreservierung_heizungssteuerung.md](tischreservierung_heizungssteuerung.md)** für Tischreservierung und Heizungssteuerung
4. Prüfen Sie **[data_management.md](data_management.md)** für Datenbehandlung

### Für Turnierorganisatoren
1. Lesen Sie **[tournament.md](tournament.md)** für Turnier-Workflows
2. Überprüfen Sie **[Tournament.en.mds](../doc/doc/Tournament.en.mds)** für detaillierte Anleitung
3. Prüfen Sie **[League.en.mds](../doc/doc/League.en.mds)** für Ligaverwaltung

### Für API-Benutzer
1. Beginnen Sie mit **[API.md](API.md)** für vollständige API-Dokumentation
2. Überprüfen Sie **[database_design.md](database_design.md)** für Datenstruktur
3. Prüfen Sie **[data_management.md](data_management.md)** für Datenmuster

## 📖 Dokumentationsstruktur

```
docs/
├── README.md                           # Diese Datei - Dokumentationsindex
├── DEVELOPER_GUIDE.md                  # Haupt-Entwicklerdokumentation
├── API.md                              # API-Dokumentation
├── database_design.md                  # Datenbankschema
├── tournament.md                       # Turnier-Workflows
├── scoreboard_autostart_setup.md       # Scoreboard-Konfiguration
├── tischreservierung_heizungssteuerung.md # Tischreservierung und Heizungssteuerung
├── data_management.md                  # Datenbehandlung
├── database_syncing.md                 # Externe Datensynchronisation
├── paper_trail_optimization.md         # Versionsverfolgung
├── filter_popup_usage.md               # UI-Komponenten
├── region_tagging_cleanup_summary.md   # Regionsverwaltung
├── admin_roles.md                      # Zugriffskontrolle
├── privacy.md                          # Datenschutzerklärung
├── terms.md                            # Nutzungsbedingungen
├── about.md                            # Projektinformationen
└── admin/                              # Admin-Dokumentation
    └── user_management.md              # Benutzerverwaltung
```

## 🔄 Dokumentationswartung

### Beitrag zur Dokumentation
- Folgen Sie dem [Beitragsleitfaden](../docs/DEVELOPER_GUIDE.md#mitwirken)
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

### Dokumentationsprobleme
- Melden Sie Dokumentationsfehler über [GitHub Issues](https://github.com/your-username/carambus/issues)
- Schlagen Sie Verbesserungen über [GitHub Discussions](https://github.com/your-username/carambus/discussions) vor

### Technischer Support
- Prüfen Sie den [Entwicklerleitfaden](DEVELOPER_GUIDE.md) für häufige Probleme
- Überprüfen Sie die [API-Dokumentation](API.md) für Integrationshilfe
- Konsultieren Sie das [Runbook](../doc/doc/Runbook) für Deployment-Probleme

### Community-Ressourcen
- **GitHub Issues**: Bug-Reports und Feature-Requests
- **GitHub Discussions**: Fragen und Community-Support
- **Projekt Wiki**: Zusätzliche community-gewartete Dokumentation

## 🌐 Sprachunterstützung

Die Carambus-Dokumentation ist in mehreren Sprachen verfügbar:

- **Englisch**: Primäre Dokumentationssprache
- **Deutsch**: Wichtige Dokumente für deutsche Benutzer übersetzt
- **Zukunft**: Zusätzliche Sprachunterstützung geplant

### Sprachspezifische Dateien
- `*.en.md`: Englische Dokumentation
- `*.de.md`: Deutsche Dokumentation
- `*.md`: Standardsprache (normalerweise Englisch)

---

*Diese Dokumentation wird vom Carambus-Entwicklungsteam gepflegt. Für Fragen oder Beiträge siehe den [Beitragsleitfaden](DEVELOPER_GUIDE.md#mitwirken).* 