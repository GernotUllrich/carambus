# Carambus Docker Setup

Dieses Docker-Setup ermöglicht es, die Carambus Rails-Anwendung in isolierten Containern zu betreiben.

## 🐳 Was ist Docker?

Docker ist eine Container-Technologie, die Anwendungen in isolierten Umgebungen ausführt:

- **Isolation**: Jede Anwendung läuft in ihrem eigenen Container
- **Portabilität**: Läuft überall gleich (Entwicklung, Staging, Produktion)
- **Effizienz**: Teilt sich das Host-Betriebssystem
- **Reproduzierbarkeit**: Immer die gleiche Umgebung

## 📋 Voraussetzungen

- Docker (Version 20.10+)
- Docker Compose (Version 2.0+)
- Mindestens 4GB RAM
- 10GB freier Speicherplatz

## 🚀 Schnellstart

### 1. Repository klonen
```bash
git clone <repository-url>
cd carambus_api
```

### 2. Docker Setup ausführen
```bash
./docker-setup.sh
```

Das Skript führt automatisch aus:
- Prüfung der Docker-Installation
- Erstellung der `.env` Datei
- SSL-Zertifikat-Generierung
- Docker Image Build
- Service-Start
- Datenbank-Migrationen

### 3. Anwendung aufrufen
- **HTTP**: http://localhost
- **HTTPS**: https://localhost

## 🔧 Manuelle Installation

### 1. Umgebungsvariablen konfigurieren
```bash
cp env.example .env
# Bearbeite .env mit deinen Werten
```

### 2. SSL-Zertifikate erstellen
```bash
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/key.pem -out ssl/cert.pem \
    -subj "/C=DE/ST=NRW/L=Dortmund/O=Carambus/CN=localhost"
```

### 3. Docker Images bauen
```bash
docker-compose build
```

### 4. Services starten
```bash
docker-compose up -d
```

### 5. Datenbank einrichten
```bash
docker-compose exec web bundle exec rails db:create
docker-compose exec web bundle exec rails db:migrate
docker-compose exec web bundle exec rails db:seed  # Optional
```

## 📊 Services

Das Setup enthält folgende Services:

### 🐘 PostgreSQL (Datenbank)
- **Port**: 5432
- **Container**: carambus_postgres
- **Daten**: Persistiert in Docker Volume

### 🔴 Redis (Cache)
- **Port**: 6379
- **Container**: carambus_redis
- **Daten**: Persistiert in Docker Volume

### 🚀 Rails Application
- **Port**: 3000 (intern)
- **Container**: carambus_web
- **Logs**: stdout/stderr

### 🌐 Nginx (Reverse Proxy)
- **Port**: 80 (HTTP), 443 (HTTPS)
- **Container**: carambus_nginx
- **Features**: SSL, Gzip, Static Files

## 🛠️ Nützliche Befehle

### Service-Management
```bash
# Services starten
docker-compose up -d

# Services stoppen
docker-compose down

# Services neu starten
docker-compose restart

# Status anzeigen
docker-compose ps
```

### Logs
```bash
# Alle Logs
docker-compose logs -f

# Spezifischer Service
docker-compose logs -f web
docker-compose logs -f postgres
docker-compose logs -f redis
```

### Shell-Zugriff
```bash
# Rails Container
docker-compose exec web bash

# PostgreSQL Container
docker-compose exec postgres psql -U carambus -d carambus_production

# Redis Container
docker-compose exec redis redis-cli
```

### Datenbank-Operationen
```bash
# Migrationen ausführen
docker-compose exec web bundle exec rails db:migrate

# Seeds ausführen
docker-compose exec web bundle exec rails db:seed

# Rails Console
docker-compose exec web bundle exec rails console
```

### Backup/Restore
```bash
# PostgreSQL Backup
docker-compose exec postgres pg_dump -U carambus carambus_production > backup.sql

# PostgreSQL Restore
docker-compose exec -T postgres psql -U carambus carambus_production < backup.sql
```

## 🔧 Konfiguration

### Umgebungsvariablen (.env)
```bash
# Datenbank
POSTGRES_PASSWORD=your_secure_password
DATABASE_URL=postgresql://carambus:password@postgres:5432/carambus_production

# Redis
REDIS_URL=redis://redis:6379/0

# Rails
RAILS_ENV=production
RAILS_MASTER_KEY=your_master_key
SECRET_KEY_BASE=your_secret_key
```

### SSL-Zertifikate
Für Produktion sollten echte SSL-Zertifikate verwendet werden:
```bash
# Let's Encrypt (empfohlen)
certbot certonly --webroot -w /path/to/webroot -d yourdomain.com

# Zertifikate kopieren
cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ssl/cert.pem
cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ssl/key.pem
```

## 🐛 Troubleshooting

### Port-Konflikte
```bash
# Prüfe belegte Ports
netstat -tulpn | grep :80
netstat -tulpn | grep :443
netstat -tulpn | grep :5432
```

### Speicherplatz
```bash
# Docker System bereinigen
docker system prune -a
docker volume prune
```

### Container-Logs
```bash
# Detaillierte Logs
docker-compose logs --tail=100 web
```

### Datenbank-Verbindung
```bash
# PostgreSQL-Verbindung testen
docker-compose exec postgres pg_isready -U carambus
```

## 🔒 Sicherheit

### Produktions-Empfehlungen
1. **Starke Passwörter** in `.env` verwenden
2. **Echte SSL-Zertifikate** für HTTPS
3. **Firewall** konfigurieren
4. **Regelmäßige Backups** erstellen
5. **Docker Images** regelmäßig updaten

### Monitoring
```bash
# Container-Ressourcen
docker stats

# Disk-Usage
docker system df
```

## 📚 Weitere Ressourcen

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Rails Docker Guide](https://guides.rubyonrails.org/getting_started_with_devcontainer.html)
- [PostgreSQL Docker](https://hub.docker.com/_/postgres)
- [Redis Docker](https://hub.docker.com/_/redis)
- [Nginx Docker](https://hub.docker.com/_/nginx) 