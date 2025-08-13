# Carambus Docker Database Management

## Übersicht

Das Carambus Docker-System verwaltet verschiedene Datenbankvarianten für unterschiedliche Server-Typen:

- **API Server**: Zentrale Datenbanken (`carambus_api_production`, `carambus_api_development`)
- **Local Server**: Standard-Lokalserver (`carambus_production`, `carambus_development`)
- **Location Server**: Location-spezifische Server mit lokalen Erweiterungen (`carambus_production_xyz`)

## Neue Deployment-Architektur

### Phase 1: Vorbereitung auf dem Entwicklungssystem (Mac mini)
Das neue System trennt die Vorbereitung vom eigentlichen Deployment:

```bash
# Deployment-Paket für API Server erstellen
./doc/doc-local/docker/scripts/prepare-deployment.sh api-server

# Deployment-Paket für Location-spezifischen Server erstellen
./doc/doc-local/docker/scripts/prepare-deployment.sh location berlin

# Deployment-Paket für lokalen Server erstellen
./doc/doc-local/docker/scripts/prepare-deployment.sh local-server
```

### Phase 2: Deployment auf dem Zielsystem
Alle Server-Typen verwenden den gleichen Deployment-Prozess:

```bash
# Auf dem Zielsystem
tar -xzf carambus-api-server-20241201_143022.tar.gz
cd carambus-api-server-20241201_143022
./deploy-docker.sh
```

## Verzeichnisstruktur

```
doc/doc-local/docker/
├── databases/
│   ├── api-server/           # API Server Datenbanken
│   ├── local-server/         # Lokale Server Datenbanken
│   ├── development/          # Development Datenbanken
│   └── locations/            # Location-spezifische Datenbanken
│       ├── berlin/
│       ├── muenchen/
│       ├── hamburg/
│       └── ...
├── scripts/
│   ├── prepare-deployment.sh # Deployment-Pakete vorbereiten
│   ├── backup-databases.sh   # Datenbanken sichern
│   ├── restore-databases.sh  # Datenbanken wiederherstellen
│   ├── manage-databases.sh   # Zentrale Verwaltung
│   └── migrate-existing-databases.sh # Migration bestehender Backups
└── README.md
```

## Datenbank-Namenskonventionen

### API Server
- **Production**: `carambus_api_production`
- **Development**: `carambus_api_development`

### Local Server
- **Production**: `carambus_production`
- **Development**: `carambus_development`

### Location Server
- **Production**: `carambus_production_<location_code>`
- **Development**: `carambus_development_<location_code>` (nur in Ausnahmefällen)

**Wichtig**: Location-spezifische Server haben lokale Erweiterungen mit IDs > 50.000.000, die bei Versionssprüngen erhalten bleiben müssen.

## Verwendung

### 1. Datenbanken sichern

```bash
# Alle Datenbanken sichern
./doc/doc-local/docker/scripts/backup-databases.sh all

# Nur API Server Datenbanken
./doc/doc-local/docker/scripts/backup-databases.sh api-server

# Nur Location-spezifische Datenbanken
./doc/doc-local/docker/scripts/backup-databases.sh location berlin
```

### 2. Deployment-Paket erstellen

```bash
# API Server
./doc/doc-local/docker/scripts/prepare-deployment.sh api-server

# Local Server
./doc/doc-local/docker/scripts/prepare-deployment.sh local-server

# Location Server
./doc/doc-local/docker/scripts/prepare-deployment.sh location berlin
```

### 3. Datenbanken wiederherstellen

```bash
# Von Backup wiederherstellen
./doc/doc-local/docker/scripts/restore-databases.sh api-server carambus_api_production

# Mit spezifischem Backup
./doc/doc-local/docker/scripts/restore-databases.sh local-server carambus_production backup_20241201_143022.sql.gz
```

### 4. Zentrale Verwaltung

```bash
# Status aller Datenbanken
./doc/doc-local/docker/scripts/manage-databases.sh status

# Alle Datenbanken sichern
./doc/doc-local/docker/scripts/manage-databases.sh backup

# Alte Backups aufräumen
./doc/doc-local/docker/scripts/manage-databases.sh cleanup
```

## Vereinfachte Docker-Konfiguration

### Neue vereinheitlichte Docker Compose Datei

Das neue System verwendet `docker-compose.unified.yml` für alle Server-Typen. Die Unterschiede werden über Environment-Variablen gesteuert:

```bash
# Standard (verwendet env.unified)
./deploy-docker.sh

# Mit spezifischer Environment-Datei
./deploy-docker.sh --env env.api-server
./deploy-docker.sh --env env.local-server
./deploy-docker.sh --env env.development
```

### Environment-Konfiguration

Die `env.unified` Datei konfiguriert automatisch alle Einstellungen basierend auf dem `SERVER_TYPE`:

```bash
# Für API Server
SERVER_TYPE=API_SERVER

# Für Local Server
SERVER_TYPE=LOCAL_SERVER

# Für Location Server
SERVER_TYPE=LOCATION_SERVER
LOCATION_CODE=berlin

# Für Development
SERVER_TYPE=DEVELOPMENT
```

## Deployment-Workflow

### Auf dem Entwicklungssystem (Mac mini)

1. **Datenbanken sichern**:
   ```bash
   ./doc/doc-local/docker/scripts/backup-databases.sh all
   ```

2. **Deployment-Paket erstellen**:
   ```bash
   ./doc/doc-local/docker/scripts/prepare-deployment.sh api-server
   ```

3. **Paket auf Zielserver übertragen**:
   ```bash
   scp carambus-api-server-*.tar.gz user@target-server:/tmp/
   ```

### Auf dem Zielsystem

1. **Paket entpacken**:
   ```bash
   tar -xzf /tmp/carambus-api-server-*.tar.gz
   cd carambus-api-server-*
   ```

2. **Environment anpassen** (falls nötig):
   ```bash
   # env.unified bearbeiten
   nano env.unified
   ```

3. **Docker starten**:
   ```bash
   ./deploy-docker.sh
   ```

## Vorteile des neuen Systems

1. **Einheitlicher Deployment-Prozess**: Alle Server-Typen verwenden den gleichen Ablauf
2. **Klare Trennung**: Vorbereitung auf dem Mac, Deployment auf dem Zielsystem
3. **Vereinfachte Konfiguration**: Eine Docker Compose Datei für alle Server
4. **Automatische Konfiguration**: Environment-Dateien passen sich automatisch an
5. **Bessere Wartbarkeit**: Weniger Duplikate, klarere Struktur

## Migration bestehender Backups

Falls Sie bereits Datenbank-Backups haben, können Sie diese in die neue Struktur migrieren:

```bash
./doc/doc-local/docker/scripts/migrate-existing-databases.sh
```

## Sicherheitshinweise

- Datenbank-Passwörter sollten in der Production geändert werden
- SSL-Zertifikate müssen manuell auf dem Zielsystem installiert werden
- Firewall-Regeln für die verwendeten Ports konfigurieren
- Regelmäßige Backups der Production-Datenbanken

## Troubleshooting

### Häufige Probleme

1. **Datenbank-Dump nicht gefunden**:
   - Stellen Sie sicher, dass der Backup-Prozess erfolgreich war
   - Überprüfen Sie den Pfad in der Environment-Datei

2. **Port-Konflikte**:
   - Ändern Sie die Ports in der Environment-Datei
   - Stoppen Sie andere Services, die die gleichen Ports verwenden

3. **Berechtigungsprobleme**:
   - Stellen Sie sicher, dass der `www-data` User die richtigen Rechte hat
   - Überprüfen Sie die Verzeichnisberechtigungen

### Logs anzeigen

```bash
# Alle Container-Logs
docker-compose -f docker-compose.unified.yml logs -f

# Nur Web-Container
docker-compose -f docker-compose.unified.yml logs -f web

# Nur Datenbank-Container
docker-compose -f docker-compose.unified.yml logs -f postgres
```

## Nächste Schritte

1. Testen Sie das neue System mit einem Development-Setup
2. Erstellen Sie Deployment-Pakete für Ihre verschiedenen Server
3. Migrieren Sie bestehende Backups in die neue Struktur
4. Aktualisieren Sie Ihre Deployment-Dokumentation 