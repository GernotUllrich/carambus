# Carambus Docker Architecture

## Übersicht

Diese Dokumentation beschreibt die neue, klare Docker-Architektur für Carambus, die drei Haupttypen von Deployment unterstützt:

1. **API Server** - Zentraler Server für alle Clients
2. **Local Server** - Lokale Server für Turniere/Clubs
3. **Development** - Entwicklungsumgebung auf dem Mac

## 🏗️ Architektur-Übersicht

### Deployment-Typen

#### 1. API Server
- **Zweck**: Zentrale API für alle Carambus-Clients
- **Domain**: newapi.carambus.de → api.carambus.de
- **Datenbank**: carambus_api_production
- **User**: www-data
- **Ports**: Standard (3000, 5432, 6379)

#### 2. Local Server
- **Zweck**: Lokale Server für Turniere, Clubs, Events
- **Domain**: new.carambus.de → carambus.de
- **Datenbank**: carambus_production
- **User**: www-data
- **Ports**: Standard (3000, 5432, 6379)
- **Besonderheit**: Unterstützt location-spezifische Erweiterungen

#### 3. Development
- **Zweck**: Entwicklungsumgebung auf dem Mac
- **Domain**: Keine (localhost)
- **Datenbank**: carambus_development
- **User**: www-data
- **Ports**: Standard (3000, 5432, 6379)
- **Besonderheit**: Code-Volumes für Live-Entwicklung

### Location-spezifische Server

Für spezielle Standorte können location-spezifische Server erstellt werden:

- **Datenbank**: carambus_production_xyz
- **Domain**: carambus.xyz.de
- **Besonderheit**: Lokale Erweiterungen (id > 50000000) bleiben erhalten

## 📁 Datei-Struktur

```
carambus_api/
├── docker-compose.yml                    # Basis-Konfiguration
├── docker-compose.api-server.yml         # API Server
├── docker-compose.local-server.yml       # Local Server
├── docker-compose.development.yml        # Development
├── env.api-server                        # API Server Environment
├── env.local-server                      # Local Server Environment
├── env.development                       # Development Environment
├── deploy-docker.sh                      # Deployment Script
└── Dockerfile                            # Basis Docker Image
```

## 🚀 Schnellstart

### API Server deployen
```bash
# Auf dem API-Server
./deploy-docker.sh api-server www-data@carambus.de:8910 /var/www/carambus_api
```

### Local Server deployen
```bash
# Standard Local Server
./deploy-docker.sh local-server www-data@192.168.178.53:8910 /var/www/carambus

# Location-spezifischer Server
./deploy-docker.sh local-server-berlin www-data@192.168.178.54:8910 /var/www/carambus
```

### Development starten
```bash
# Lokale Entwicklungsumgebung
./deploy-docker.sh development localhost
```

## 🔧 Konfiguration

### Environment-Variablen

Alle Konfigurationen werden über Environment-Dateien gesteuert:

#### API Server (env.api-server)
```bash
DEPLOYMENT_TYPE=API_SERVER
RAILS_ENV=production
DATABASE_NAME=carambus_api_production
DOMAIN=newapi.carambus.de
USE_HTTPS=true
```

#### Local Server (env.local-server)
```bash
DEPLOYMENT_TYPE=LOCAL_SERVER
RAILS_ENV=production
DATABASE_NAME=carambus_production
DOMAIN=new.carambus.de
USE_HTTPS=true
LOCATION_CODE=
```

#### Development (env.development)
```bash
DEPLOYMENT_TYPE=LOCAL_SERVER
RAILS_ENV=development
DATABASE_NAME=carambus_development
DOMAIN=
USE_HTTPS=false
LOCATION_CODE=
```

### Datenbank-Namen

| Deployment-Typ | Produktion | Entwicklung |
|----------------|------------|-------------|
| API Server | carambus_api_production | carambus_api_development |
| Local Server | carambus_production | carambus_development |
| Location XYZ | carambus_production_xyz | carambus_development_xyz |

## 🐳 Docker-Services

### Basis-Services (alle Deployment-Typen)

#### PostgreSQL
- **Image**: postgres:15
- **User**: www_data
- **Port**: 5432
- **Health Check**: pg_isready

#### Redis
- **Image**: redis:7-alpine
- **Port**: 6379
- **Health Check**: redis-cli ping

#### Web (Rails)
- **Base Image**: ruby:3.2.1-slim
- **User**: www-data (UID 33)
- **Port**: 3000
- **Environment**: Rails-spezifisch

### Deployment-spezifische Anpassungen

#### API Server
- Feste Datenbank: carambus_api_production
- HTTPS erforderlich
- Nginx-Integration

#### Local Server
- Konfigurierbare Datenbank
- Location-Code Support
- Lokale Erweiterungen

#### Development
- Code-Volumes für Live-Entwicklung
- Development-Modus
- Debugging-Tools

## 🔒 Sicherheit

### User-Management
- Alle Services laufen unter www-data (UID 33)
- Keine Root-Container
- Sichere Berechtigungen

### Netzwerk
- Ports nur auf localhost gebunden
- Nginx als Reverse-Proxy
- SSL/TLS für Produktion

### Datenbank
- Separate Datenbanken pro Deployment
- Sichere Passwörter
- Keine externen Verbindungen

## 📊 Monitoring

### Health Checks
```bash
# Container-Status
docker compose ps

# Health-Check
curl -f http://localhost:3000/health

# Logs
docker compose logs -f web
```

### Performance
```bash
# Container-Ressourcen
docker stats

# Disk-Usage
docker system df
```

## 🔄 Deployment-Workflow

### 1. Vorbereitung
```bash
# Repository klonen
git clone git@github.com:GernotUllrich/carambus.git
cd carambus

# Deployment-Script ausführbar machen
chmod +x deploy-docker.sh
```

### 2. Konfiguration
```bash
# Environment-Datei anpassen
cp env.api-server .env
# Bearbeite .env nach Bedarf
```

### 3. Deployment
```bash
# Deployment starten
./deploy-docker.sh api-server www-data@carambus-de:8910
```

### 4. Verifikation
```bash
# Services prüfen
docker compose ps

# Anwendung testen
curl -f http://localhost:3000
```

## 🐛 Troubleshooting

### Häufige Probleme

#### Container startet nicht
```bash
# Logs prüfen
docker compose logs web

# Container neu starten
docker compose restart web
```

#### Datenbank-Verbindung
```bash
# Datenbank-Status
docker compose exec postgres pg_isready -U www_data

# Rails-Konsole
docker compose exec web rails console
```

#### Port-Konflikte
```bash
# Ports prüfen
netstat -tlnp | grep :3000

# Container stoppen
docker compose down
```

## 📈 Skalierung

### Horizontale Skalierung
- Mehrere Web-Container möglich
- Load-Balancing über Nginx
- Redis für Session-Sharing

### Vertikale Skalierung
- Resource-Limits in docker-compose
- Memory und CPU-Optimierung
- Storage-Optimierung

## 🔮 Zukünftige Entwicklungen

### Geplante Features
1. **Kubernetes Support**: K8s Manifests
2. **CI/CD Pipeline**: GitHub Actions
3. **Monitoring**: Prometheus/Grafana
4. **Backup**: Automatische Backups
5. **Auto-Scaling**: Basierend auf Last

### Migration
- Bestehende Deployments können migriert werden
- Schrittweise Umstellung möglich
- Rollback-Strategien verfügbar

---

*Diese Dokumentation wird kontinuierlich erweitert. Für Fragen oder Beiträge siehe die Community-Ressourcen.* 