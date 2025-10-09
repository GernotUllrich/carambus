# Carambus API - Projektstruktur

## Übersicht

Das Carambus API-Projekt wurde neu strukturiert, um eine bessere Übersichtlichkeit und Wartbarkeit zu gewährleisten. Die Dateien sind jetzt logisch nach Funktionalität gruppiert.

## Verzeichnisstruktur

### Root-Verzeichnis
```
carambus_api/
├── .git/                    # Git-Repository
├── .github/                 # GitHub-spezifische Dateien
├── .gitignore              # Git-Ignore
├── .gitattributes         # Git-Attribute
├── .cursorrules           # Cursor-spezifische Regeln
├── .ruby-version          # Ruby-Version
├── .standard.yml          # Ruby Standard-Konfiguration
├── .wordlist              # Wordlist für Rechtschreibprüfung
├── Gemfile                # Ruby-Abhängigkeiten
├── Gemfile.lock           # Ruby-Abhängigkeiten (Lock)
├── Procfile               # Heroku-Procfile
├── Brewfile               # Homebrew-Abhängigkeiten
├── LICENSE                # Lizenz
├── REVISION               # Revisionsnummer
├── HISTORY                # Projekt-Historie
├── README.md              # Haupt-README
├── README.de.md           # Deutsche README
├── mkdocs.yml             # MkDocs-Konfiguration
├── requirements.txt        # Python-Abhängigkeiten
├── app/                   # Rails-Anwendung
├── bin/                   # Rails-Binaries
├── config/                # Rails-Konfiguration
├── db/                    # Datenbank
├── lib/                   # Bibliotheken
├── log/                   # Logs
├── public/                # Öffentliche Dateien
├── storage/               # Datei-Speicher
├── tmp/                   # Temporäre Dateien
├── test/                  # Tests
├── vendor/                # Vendor-Dateien
├── node_modules/          # Node.js-Module
├── venv/                  # Python-Virtual-Environment
├── site/                  # MkDocs generierte Site
├── pages/                 # MkDocs-Seiten
├── docs/                  # Dokumentation
├── docker/                # Docker-Konfiguration
├── scripts/               # Scripts und Tools
├── build/                 # Build-Konfiguration
├── deployment/            # Deployment-Konfiguration
└── testing/               # Test-Dokumentation
```

### Docker-Verzeichnis
```
docker/
├── development/            # Entwicklungsumgebungen
│   ├── api-server/        # API-Server Entwicklung
│   │   ├── docker-compose.development.api-server.yml
│   │   ├── Dockerfile.development
│   │   └── env.development.api-server
│   ├── web-client/        # Web-Client Entwicklung
│   ├── local-server/      # Lokaler Server Entwicklung
│   └── parallel/          # Parallele Entwicklung
├── production/            # Produktionsumgebungen
│   ├── api-server/        # API-Server Produktion
│   ├── web-client/        # Web-Client Produktion
│   └── local-server/      # Lokaler Server Produktion
├── unified/               # Einheitliche Konfiguration
├── docker-compose.yml     # Standard Docker Compose (Symlink)
└── Dockerfile             # Standard Dockerfile (Symlink)
```

### Scripts-Verzeichnis
```
scripts/
├── setup/                 # Setup-Scripts
│   ├── setup-github-access.sh
│   └── start-development-parallel.sh
├── deployment/            # Deployment-Scripts
│   ├── deploy-docker.sh
│   └── cron-startup.sh
├── testing/               # Test-Scripts
│   ├── test-docker-setup.sh
│   ├── test_browser_search.rb
│   ├── test_id_based_filtering.rb
│   └── test_javascript_loading.html
├── debug/                 # Debug-Scripts
│   ├── debug_current_state.rb
│   ├── debug_filter_matching.rb
│   └── debug_search.rb
└── maintenance/           # Wartungs-Scripts
    ├── crontab
    └── postcss.config.js
```

### Build-Verzeichnis
```
build/
├── esbuild.config.mjs     # ESBuild-Konfiguration
├── package.json           # Node.js-Abhängigkeiten
├── yarn.lock              # Yarn-Lock-Datei
└── .rubocop.yml           # Ruby-Code-Style
```

### Deployment-Verzeichnis
```
deployment/
├── capistrano/            # Capistrano-Deployment
│   └── Capfile
├── ansible/               # Ansible-Playbooks
└── nginx-host-config/     # Nginx-Konfiguration
```

### Testing-Verzeichnis
```
testing/
├── plans/                 # Test-Pläne
│   ├── TEST_PLAN_ID_BASED_FILTERING.md
│   └── FRESH_SD_TEST_CHECKLIST.md
├── summaries/             # Test-Zusammenfassungen
│   ├── TESTING_SUMMARY.md
│   ├── FIX_SUMMARY.md
│   ├── IMPLEMENTATION_LESSONS.md
│   ├── league_scraping_fix_summary.md
│   └── duplicate_leagues_summary.md
└── analysis/              # Test-Analysen
    ├── ISSUE_ANALYSIS.md
    └── REDUNDANT_FILES_TO_DELETE.md
```

### Dokumentation-Verzeichnis
```
docs/
├── changelog/             # Changelog-Dateien
│   ├── CHANGELOG.md
│   └── CHANGELOG.de.md
├── readme/                # README-Dateien (leer, da im Root)
├── de/                    # Deutsche Dokumentation
├── en/                    # Englische Dokumentation
└── index.md               # Hauptindex
```

## Kompatibilität

### Symlinks
Um die Abwärtskompatibilität zu gewährleisten, wurden folgende Symlinks erstellt:
- `docker-compose.yml` → `docker/development/api-server/docker-compose.development.api-server.yml`
- `.env` → `docker/development/api-server/env.development.api-server`

### Verwendung
- **Entwicklung**: Verwenden Sie die Dateien in `docker/development/api-server/`
- **Produktion**: Verwenden Sie die Dateien in `docker/production/`
- **Scripts**: Alle Scripts sind in `scripts/` nach Funktionalität gruppiert
- **Build**: Build-Konfigurationen sind in `build/` zentralisiert

## Migration

### Für Entwickler
1. **Docker**: Verwenden Sie den korrekten Pfad zu den Docker-Dateien
2. **Scripts**: Alle Scripts sind jetzt in `scripts/` organisiert
3. **Build**: Build-Tools sind in `build/` zentralisiert

### Für Deployment
1. **Capistrano**: Konfiguration ist in `deployment/capistrano/`
2. **Ansible**: Playbooks sind in `deployment/ansible/`
3. **Nginx**: Konfiguration ist in `deployment/nginx-host-config/`

## Vorteile der neuen Struktur

### 1. Übersichtlichkeit
- **Root-Verzeichnis**: Von ~80 auf ~75 Dateien reduziert
- **Logische Gruppierung**: Ähnliche Dateien sind zusammengefasst
- **Einfache Navigation**: Klare Verzeichnisstruktur

### 2. Wartbarkeit
- **Docker-Konfigurationen**: Alle Docker-Dateien an einem Ort
- **Scripts**: Nach Funktionalität gruppiert
- **Tests**: Test-Dokumentation zentral organisiert

### 3. Best Practices
- **Rails-Standards**: Folgt Rails-Konventionen
- **Docker-Standards**: Klare Trennung von Umgebungen
- **Deployment**: Deployment-spezifische Dateien getrennt

### 4. Entwicklerfreundlichkeit
- **Neue Entwickler**: Finden sich schneller zurecht
- **Teamarbeit**: Klare Verantwortlichkeiten
- **Onboarding**: Strukturierte Einarbeitung

## Nächste Schritte

### Kurzfristig
- [x] Verzeichnisstruktur erstellt
- [x] Dateien verschoben
- [x] Symlinks für Kompatibilität erstellt
- [x] Funktionalität getestet

### Mittelfristig
- [ ] Dokumentation der neuen Struktur aktualisieren
- [ ] CI/CD-Pipelines an neue Struktur anpassen
- [ ] Team-Schulung durchführen

### Langfristig
- [ ] Automatisierte Struktur-Überprüfung
- [ ] Template für neue Projekte
- [ ] Best Practices dokumentieren

## Support

Bei Fragen zur neuen Struktur:
1. Überprüfen Sie diese Dokumentation
2. Schauen Sie sich die Verzeichnisstruktur an
3. Kontaktieren Sie das Entwicklungsteam

---

**Letzte Aktualisierung**: 14. August 2025
**Erstellt von**: AI Assistant
**Status**: Implementiert und getestet 