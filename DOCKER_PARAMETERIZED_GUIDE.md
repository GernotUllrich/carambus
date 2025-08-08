# Carambus Parameterized Docker Deployment Guide

## Übersicht

Diese Lösung ermöglicht es, Carambus mit Docker auf verschiedenen Zielumgebungen zu deployen, ohne für jede Umgebung einen separaten Branch zu benötigen. Alle Konfigurationen werden über Umgebungsvariablen gesteuert.

## Konzept

### Ein Repository, Mehrere Deployments
- **Master Branch:** Enthält alle Docker-Konfigurationen
- **Parameter-basiert:** Verschiedene Deployments über Umgebungsvariablen
- **Flexibel:** Unterstützt lokale Tests, Raspberry Pi, API-Server, etc.

### Unterstützte Deployment-Typen

1. **carambus_raspberry** - Raspberry Pi Scoreboard
2. **carambus_newapi** - API-Server auf Hetzner
3. **carambus_local** - Lokale Entwicklung/Test

## Verwendung

### Automatisches Deployment

```bash
# Raspberry Pi Deployment
./deploy-docker.sh carambus_raspberry pi@192.168.178.53 /home/pi/carambus

# API-Server Deployment
./deploy-docker.sh carambus_newapi www-data@carambus-de:8910 /home/www-data/carambus_newapi

# Lokales Test-Deployment
./deploy-docker.sh carambus_local localhost /tmp/carambus_test
```

### Manuelles Deployment

```bash
# 1. Umgebungsvariablen setzen
export DEPLOYMENT_NAME=carambus_newapi
export DATABASE_NAME=carambus_api_production
export DATABASE_USER=www_data
export WEB_PORT=3000
export DOMAIN=newapi.carambus.de

# 2. .env Datei erstellen
cat > .env << EOF
DEPLOYMENT_NAME=$DEPLOYMENT_NAME
DATABASE_NAME=$DATABASE_NAME
DATABASE_USER=$DATABASE_USER
DATABASE_PASSWORD=${DEPLOYMENT_NAME}_production_password
WEB_PORT=$WEB_PORT
DOMAIN=$DOMAIN
EOF

# 3. Docker Compose starten
docker compose up -d
```

## Konfigurationsdateien

### docker-compose.yml
Parameterisierte Docker Compose Konfiguration mit Umgebungsvariablen:

```yaml
services:
  postgres:
    environment:
      POSTGRES_DB: ${DATABASE_NAME:-carambus_production}
      POSTGRES_USER: ${DATABASE_USER:-www_data}
      POSTGRES_PASSWORD: ${DATABASE_PASSWORD:-carambus_production_password}
    volumes:
      - ./doc/doc-local/docker/${DB_DUMP_FILE:-carambus_production_fixed.sql.gz}:/docker-entrypoint-initdb.d/${DB_DUMP_FILE:-carambus_production_fixed.sql.gz}
```

### nginx.conf
Flexible Nginx-Konfiguration mit SSL-Support:

```nginx
server {
    listen 80;
    server_name ${DOMAIN:-localhost};
    
    # Conditional redirect based on domain
    if ($host != "localhost") {
        return 301 https://$server_name$request_uri;
    }
}
```

### deploy-docker.sh
Intelligentes Deployment-Script mit automatischer Konfiguration:

```bash
# Configuration based on deployment name
case $DEPLOYMENT_NAME in
    carambus_raspberry|carambus_pi)
        DB_DUMP_FILE="carambus_production_fixed.sql.gz"
        DATABASE_NAME="carambus_production"
        DOMAIN=""
        ;;
    carambus_newapi|newapi)
        DB_DUMP_FILE="carambus_api_development_20250804_0218.sql.gz"
        DATABASE_NAME="carambus_api_production"
        DOMAIN="newapi.carambus.de"
        ;;
esac
```

## Deployment-Konfigurationen

### 1. carambus_raspberry
- **Ziel:** Raspberry Pi Scoreboard
- **Datenbank:** carambus_production
- **Dump:** carambus_production_fixed.sql.gz
- **Ports:** 3000, 5432, 6379
- **SSL:** Nein (lokales Netzwerk)

### 2. carambus_newapi
- **Ziel:** Hetzner API-Server
- **Datenbank:** carambus_api_production
- **Dump:** carambus_api_development_20250804_0218.sql.gz
- **Ports:** 3000, 5432, 6379
- **SSL:** Ja (Let's Encrypt)
- **Domain:** newapi.carambus.de

### 3. carambus_local
- **Ziel:** Lokale Entwicklung
- **Datenbank:** carambus_development
- **Dump:** carambus_production_fixed.sql.gz
- **Ports:** 3000, 5432, 6379
- **SSL:** Nein

## Umgebungsvariablen

### Erforderliche Variablen
- `DEPLOYMENT_NAME`: Name des Deployments
- `DATABASE_NAME`: Datenbankname
- `DATABASE_USER`: Datenbankbenutzer
- `DATABASE_PASSWORD`: Datenbankpasswort

### Optionale Variablen
- `REDIS_DB`: Redis Datenbanknummer (default: 0)
- `WEB_PORT`: Web-Server Port (default: 3000)
- `POSTGRES_PORT`: PostgreSQL Port (default: 5432)
- `REDIS_PORT`: Redis Port (default: 6379)
- `DB_DUMP_FILE`: Datenbank-Dump Datei
- `DOMAIN`: Domain-Name für SSL

## Deployment-Prozess

### Automatisiert (deploy-docker.sh)
1. **Server-Vorbereitung**
   - Docker und Docker Compose Installation
   - Verzeichnisstruktur erstellen

2. **Datei-Transfer**
   - Anwendungsdateien kopieren
   - Datenbank-Dump kopieren
   - Credentials kopieren

3. **Konfiguration**
   - .env Datei erstellen
   - Umgebungsvariablen setzen

4. **Deployment**
   - Docker Images bauen
   - Services starten
   - Health Checks ausführen

### Manuell
```bash
# 1. Server vorbereiten
ssh user@server
mkdir -p /path/to/deployment
cd /path/to/deployment

# 2. Dateien kopieren
scp -r ./* user@server:/path/to/deployment/
scp doc/doc-local/docker/dump.sql.gz user@server:/path/to/deployment/doc/doc-local/docker/

# 3. .env erstellen
cat > .env << EOF
DEPLOYMENT_NAME=my_deployment
DATABASE_NAME=my_database
# ... weitere Variablen
EOF

# 4. Starten
docker compose up -d
```

## Monitoring und Wartung

### Service-Status
```bash
# Alle Services anzeigen
docker compose ps

# Logs anzeigen
docker compose logs -f

# Spezifische Service-Logs
docker compose logs -f web
docker compose logs -f postgres
docker compose logs -f nginx
```

### Health Checks
```bash
# Application Health Check
curl -f http://localhost:3000/health

# Database Health Check
docker compose exec postgres pg_isready -U $DATABASE_USER -d $DATABASE_NAME

# Redis Health Check
docker compose exec redis redis-cli ping
```

### Backup und Updates
```bash
# Database Backup
docker compose exec postgres pg_dump -U $DATABASE_USER $DATABASE_NAME | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz

# Services neu starten
docker compose down
docker compose up -d

# Images neu bauen
docker compose build --no-cache
docker compose up -d
```

## Troubleshooting

### Häufige Probleme

1. **Port-Konflikte**
   ```bash
   # Verfügbare Ports prüfen
   netstat -tulpn | grep :3000
   ```

2. **Datenbank-Verbindung**
   ```bash
   # PostgreSQL-Logs prüfen
   docker compose logs postgres
   
   # Manuell verbinden
   docker compose exec postgres psql -U $DATABASE_USER -d $DATABASE_NAME
   ```

3. **SSL-Zertifikate**
   ```bash
   # Zertifikat-Pfad prüfen
   ls -la /etc/letsencrypt/live/$DOMAIN/
   
   # Nginx-Konfiguration testen
   docker compose exec nginx nginx -t
   ```

### Rollback
```bash
# Services stoppen
docker compose down

# Volumes löschen (Vorsicht: Datenverlust!)
docker compose down -v

# Images löschen
docker compose down --rmi all
```

## Erweiterte Konfiguration

### Neue Deployment-Typen hinzufügen

1. **deploy-docker.sh erweitern:**
   ```bash
   case $DEPLOYMENT_NAME in
       carambus_custom)
           DB_DUMP_FILE="custom_dump.sql.gz"
           DATABASE_NAME="custom_production"
           DATABASE_USER="custom_user"
           DOMAIN="custom.domain.com"
           ;;
   esac
   ```

2. **Docker Compose anpassen:**
   ```yaml
   services:
     custom_service:
       image: custom_image
       environment:
         CUSTOM_VAR: ${CUSTOM_VAR:-default}
   ```

### Multi-Environment Support
```bash
# Verschiedene Umgebungen gleichzeitig
./deploy-docker.sh carambus_staging staging-server /path/to/staging
./deploy-docker.sh carambus_production prod-server /path/to/production
```

## Best Practices

### Sicherheit
- Credentials niemals committen
- SSL-Zertifikate regelmäßig erneuern
- Firewall-Regeln konfigurieren
- Nicht-root User verwenden

### Performance
- Volume-Mounts für persistente Daten
- Health Checks für alle Services
- Log-Rotation konfigurieren
- Resource-Limits setzen

### Monitoring
- Logs zentral sammeln
- Metrics exportieren
- Alerts konfigurieren
- Backup-Strategien implementieren

## Support

Bei Problemen:
1. Logs prüfen: `docker compose logs -f`
2. Service-Status: `docker compose ps`
3. Health Checks ausführen
4. Dokumentation konsultieren
5. GitHub Issues erstellen 