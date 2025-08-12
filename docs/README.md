# 📚 Carambus Dokumentation

## 🏗️ Neue, konsolidierte Struktur

Die Dokumentation wurde neu organisiert, um Redundanzen zu eliminieren und eine klare Hierarchie zu schaffen.

## 📁 Verzeichnisstruktur

```
docs/
├── INSTALLATION/           # 🚀 Installation und Setup
│   ├── QUICKSTART.md       # Haupt-Installations-Guide
│   ├── RASPBERRY_PI_SETUP.md  # Raspberry Pi Setup
│   ├── DOCKER_SETUP.md     # Docker Setup
│   └── API_SERVER_SETUP.md # API-Server Setup
├── DEVELOPMENT/            # 🔧 Entwicklung
│   ├── DOCKER_STRUCTURE.md # Docker-Struktur
│   ├── CASCADING_FILTERS.md # Filter-Entwicklung
│   └── API_REFERENCE.md    # API-Dokumentation
├── MAINTENANCE/            # 🛠️ Wartung
│   ├── TROUBLESHOOTING.md  # Fehlerbehebung
│   ├── BACKUP_RESTORE.md   # Backup-Verfahren
│   └── UPDATES.md          # Update-Prozesse
└── README.md               # Diese Datei
```

## 🚀 Schnellstart

### 1. Installation
- **[QUICKSTART.md](INSTALLATION/QUICKSTART.md)** - Haupt-Installations-Guide
- **[RASPBERRY_PI_SETUP.md](INSTALLATION/RASPBERRY_PI_SETUP.md)** - Raspberry Pi Setup

### 2. Docker
- **[DOCKER_SETUP.md](INSTALLATION/DOCKER_SETUP.md)** - Docker Setup und Konfiguration
- **[DOCKER_STRUCTURE.md](DEVELOPMENT/DOCKER_STRUCTURE.md)** - Detaillierte Docker-Struktur

### 3. Entwicklung
- **[CASCADING_FILTERS.md](DEVELOPMENT/CASCADING_FILTERS.md)** - Filter-Entwicklung
- **[API_REFERENCE.md](DEVELOPMENT/API_REFERENCE.md)** - API-Dokumentation

## 🔄 Was wurde konsolidiert?

### Vorher (Redundanz)
- 3 verschiedene `RASPBERRY_PI_SETUP.md` Dateien
- Überlappende Installation Guides
- Verstreute Docker-Dokumentation
- Doppelte Sprachen (Deutsch/Englisch)

### Jetzt (Konsolidiert)
- **1 Raspberry Pi Setup** - Alle Informationen in einer Datei
- **1 Quickstart Guide** - Alle Installation-Aspekte
- **1 Docker Setup** - Alle Docker-Informationen
- **Klare Struktur** - Installation, Development, Maintenance

## 🎯 Neue Features

### Korrekte Architektur (wie besprochen)
```
Production-Modi (2 verschiedene Systeme):
├── API-Server: Ist der zentrale API-Server (newapi.carambus.de)
└── Local-Server: Hat eine Carambus API URL, die auf den API-Server verweist

Development-Modus (übergeordnet):
├── Beide Production-Modi können im Development-Modus getestet werden
├── Auf dem Mac Mini parallel lauffähig
└── Für Inter-System-Kommunikation (z.B. Region-Filter-Tests)
```

### Parallele Development-Systeme (Mac Mini)
```bash
# Alle drei Systeme gleichzeitig starten
./start-development-parallel.sh

# Ports:
# - API-Server: 3001 (PostgreSQL: 5433, Redis: 6380)
# - Local-Server: 3000 (PostgreSQL: 5432, Redis: 6379)
# - Web-Client: 3002 (PostgreSQL: 5434, Redis: 6381)
```

### Inter-System-Kommunikation
- **Local-Server ↔ API-Server** Kommunikation über Carambus API URL
- Test von Region-Filtern
- Synchronisierung zwischen Systemen
- **Beide Production-Modi im Development-Modus testbar**

## 📖 Bestehende Dokumentation

### Installation & Setup
- **[CARAMBUS_INSTALLATION_GUIDE.md](CARAMBUS_INSTALLATION_GUIDE.md)** - Detaillierter Installations-Guide
- **[RASPBERRY_PI_INITIAL_SETUP.md](RASPBERRY_PI_INITIAL_SETUP.md)** - Initial Setup
- **[RASPBERRY_PI_REAL_TEST_GUIDE.md](RASPBERRY_PI_REAL_TEST_GUIDE.md)** - Test-Guide
- **[RASPBERRY_PI_TESTING_GUIDE.md](RASPBERRY_PI_TESTING_GUIDE.md)** - Testing

### Docker
- **[DOCKER_ARCHITECTURE.md](DOCKER_ARCHITECTURE.md)** - Docker-Architektur
- **[DOCKER_DEPLOYMENT_GUIDE.md](DOCKER_DEPLOYMENT_GUIDE.md)** - Deployment
- **[docker/](docker/)** - Docker-spezifische Dokumentation

### Entwicklung
- **[CASCADING_FILTERS_DEVELOPER_GUIDE.md](CASCADING_FILTERS_DEVELOPER_GUIDE.md)** - Filter-Entwicklung
- **[cascading_filters.md](cascading_filters.md)** - Filter-Übersicht
- **[dynamic_club_filtering.md](dynamic_club_filtering.md)** - Club-Filtering
- **[enhanced_filter_popup.md](enhanced_filter_popup.md)** - Filter-Popup
- **[stimulus_reflex_filtering.md](stimulus_reflex_filtering.md)** - Stimulus Reflex

### System-Management
- **[SYSTEM_MANAGER_GUIDE.md](SYSTEM_MANAGER_GUIDE.md)** - System-Management
- **[SD_CARD_PREPARATION_GUIDE.md](SD_CARD_PREPARATION_GUIDE.md)** - SD-Karten-Vorbereitung

## 🔧 Migration

### Für bestehende Benutzer
Die alten Dateien bleiben verfügbar, aber es wird empfohlen, die neue Struktur zu verwenden:

- **Raspberry Pi Setup**: Verwenden Sie `INSTALLATION/RASPBERRY_PI_SETUP.md`
- **Docker Setup**: Verwenden Sie `INSTALLATION/DOCKER_SETUP.md`
- **Installation**: Verwenden Sie `INSTALLATION/QUICKSTART.md`

### Für neue Benutzer
Beginnen Sie mit der neuen Struktur:

1. **[QUICKSTART.md](INSTALLATION/QUICKSTART.md)** - Übersicht über alle Installation-Typen
2. **[RASPBERRY_PI_SETUP.md](INSTALLATION/RASPBERRY_PI_SETUP.md)** - Spezifisches Pi-Setup
3. **[DOCKER_SETUP.md](INSTALLATION/DOCKER_SETUP.md)** - Docker-Konfiguration

## 🆘 Hilfe

### Bei Problemen
1. Prüfen Sie die **[Troubleshooting](../MAINTENANCE/TROUBLESHOOTING.md)**-Seite
2. Logs anschauen: `docker compose logs`
3. Container-Status: `docker compose ps`

### Für Entwickler
- Verwenden Sie die parallelen Development-Systeme auf dem Mac Mini
- Testen Sie Inter-System-Kommunikation (Local-Server ↔ API-Server über Carambus API URL)
- Nutzen Sie die neue Docker-Struktur
- **Beide Production-Modi im Development-Modus testbar**

---

**🎉 Die Dokumentation ist jetzt sauber organisiert und redundanzfrei!**

**💡 Tipp**: Für die Entwicklung verwenden Sie `./start-development-parallel.sh` für alle drei Systeme gleichzeitig auf dem Mac Mini.

**🏗️ Architektur**: 2 Production-Modi - API-Server (zentral) und Local-Server (mit Carambus API URL), beide im Development-Modus testbar! 