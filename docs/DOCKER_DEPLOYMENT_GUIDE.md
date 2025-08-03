# Carambus Docker Deployment Guide

## Übersicht

Dieses Dokument beschreibt die Docker-basierte Deployment-Strategie für Carambus, die sowohl für Raspberry Pi als auch für Server-Umgebungen optimiert ist.

## 🏗️ Architektur

### Multi-Platform Support
- **ARM32v7**: Raspberry Pi und ARM-basierte Geräte
- **AMD64**: Server und Desktop-Umgebungen
- **Multi-Platform**: Automatische Plattform-Erkennung

### Container-Struktur
```
carambus/
├── app/                    # Rails-Anwendung
├── db/                     # PostgreSQL-Datenbank
├── redis/                  # Redis-Cache
└── nginx/                  # Nginx-Webserver
```

## 🚀 Schnellstart

### Voraussetzungen
- Docker und Docker Compose installiert
- Mindestens 2GB RAM verfügbar
- 10GB freier Speicherplatz

### Installation
```bash
# Repository klonen
git clone https://github.com/GernotUllrich/carambus.git
cd carambus

# SSL-Zertifikat generieren
./bin/generate-ssl-cert.sh

# Docker-Image bauen
./bin/build-docker-image.sh -p raspberry-pi

# Container starten
docker-compose -f docker-compose.raspberry-pi.yml up -d
```

## 📋 Docker-Images

### Raspberry Pi Image
```dockerfile
# Dockerfile.raspberry-pi
FROM arm32v7/ruby:3.2.1-slim
# Optimiert für ARM-Architektur
# Minimale Größe für Raspberry Pi
```

**Features:**
- ARM32v7 optimiert
- Ruby 3.2.1
- Node.js 18.x
- Yarn 1.22.22
- PostgreSQL Client
- Redis Support

### Server Image
```dockerfile
# Dockerfile
FROM ruby:3.3-slim
# Standard x86_64 Image
# Vollständige Funktionalität
```

**Features:**
- AMD64 optimiert
- Ruby 3.3
- Node.js 20.x
- Yarn 1.22.22
- Alle Development-Tools

## 🔧 Konfiguration

### Environment Variables
```bash
# .env
RAILS_ENV=production
DATABASE_URL=postgresql://www_data:password@db:5432/carambus_production
REDIS_URL=redis://redis:6379/0
RAILS_MASTER_KEY=your_master_key_here
```

### Docker Compose
```yaml
# docker-compose.raspberry-pi.yml
version: '3.8'
services:
  app:
    image: carambus/carambus:raspberry-pi
    ports:
      - "3000:3000"
    environment:
      - RAILS_ENV=production
    depends_on:
      - db
      - redis
```

## 🛠️ Build-Prozess

### Image bauen
```bash
# Raspberry Pi Image
./bin/build-docker-image.sh -p raspberry-pi -t v1.0.0

# Server Image
./bin/build-docker-image.sh -p x86_64 -t v1.0.0

# Multi-Platform Image
./bin/build-docker-image.sh -p multi -t v1.0.0 --push
```

### Build-Optionen
- `-p, --platform`: Plattform (raspberry-pi, x86_64, multi)
- `-t, --tag`: Image-Tag
- `--push`: Image zu Registry pushen
- `-h, --help`: Hilfe anzeigen

## 🔒 SSL-Konfiguration

### Zertifikat generieren
```bash
# Standard-Zertifikat
./bin/generate-ssl-cert.sh

# Custom-Zertifikat
./bin/generate-ssl-cert.sh -n carambus.de -d 730
```

### SSL-Optionen
- `-d, --days`: Gültigkeit in Tagen
- `-c, --country`: Land
- `-s, --state`: Bundesland
- `-t, --city`: Stadt
- `-o, --org`: Organisation
- `-n, --name`: Common Name

## 📊 Monitoring

### Health Checks
```bash
# Container-Status
docker-compose ps

# Health-Check
curl -f http://localhost:3000/health

# Logs anzeigen
docker-compose logs -f app
```

### Performance-Monitoring
```bash
# Container-Ressourcen
docker stats

# Image-Größe
docker images carambus/carambus

# Disk-Usage
docker system df
```

## 🔄 Deployment-Workflow

### 1. Entwicklung
```bash
# Lokale Entwicklung
docker-compose up -d

# Tests ausführen
docker-compose exec app rails test

# Datenbank-Migration
docker-compose exec app rails db:migrate
```

### 2. Staging
```bash
# Staging-Image bauen
./bin/build-docker-image.sh -p x86_64 -t staging

# Staging-Umgebung deployen
docker-compose -f docker-compose.staging.yml up -d
```

### 3. Produktion
```bash
# Produktions-Image bauen
./bin/build-docker-image.sh -p multi -t v1.0.0 --push

# Produktions-Umgebung deployen
docker-compose -f docker-compose.production.yml up -d
```

## 🐛 Troubleshooting

### Häufige Probleme

#### Container startet nicht
```bash
# Logs prüfen
docker-compose logs app

# Container neu starten
docker-compose restart app

# Datenbank-Verbindung prüfen
docker-compose exec app rails db:version
```

#### SSL-Fehler
```bash
# Zertifikat neu generieren
./bin/generate-ssl-cert.sh

# Nginx neu starten
docker-compose restart nginx
```

#### Speicherplatz-Probleme
```bash
# Docker-Cleanup
docker system prune -a

# Volumes prüfen
docker volume ls

# Backup erstellen
./bin/backup-localization.sh
```

### Debug-Modi
```bash
# Debug-Container starten
docker-compose -f docker-compose.debug.yml up

# Rails-Konsole
docker-compose exec app rails console

# Bash-Shell
docker-compose exec app bash
```

## 📈 Performance-Optimierung

### Image-Optimierung
- Multi-Stage Builds
- Layer-Caching
- Alpine Linux Base Images
- Minimal Dependencies

### Runtime-Optimierung
- Resource Limits
- Health Checks
- Auto-Restart
- Log-Rotation

### Netzwerk-Optimierung
- Nginx Reverse Proxy
- SSL-Termination
- Gzip-Kompression
- HTTP/2 Support

## 🔐 Sicherheit

### Best Practices
- Non-Root User
- Read-Only Volumes
- Security Headers
- SSL/TLS Encryption

### Vulnerability Scanning
```bash
# Docker Scout
docker scout cves carambus/carambus:latest

# Trivy Scanner
trivy image carambus/carambus:latest
```

## 📚 Nächste Schritte

### Geplante Features
1. **Kubernetes Support**: K8s Manifests
2. **CI/CD Pipeline**: GitHub Actions
3. **Monitoring**: Prometheus/Grafana
4. **Backup**: Automatische Backups
5. **Scaling**: Auto-Scaling

### Community-Beitrag
- Bug-Reports: GitHub Issues
- Feature-Requests: GitHub Discussions
- Code-Contributions: Pull Requests
- Documentation: Wiki

---

*Diese Dokumentation wird kontinuierlich erweitert. Für Fragen oder Beiträge siehe die Community-Ressourcen.* 