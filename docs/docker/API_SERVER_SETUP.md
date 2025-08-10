# API Server Docker Setup - Carambus Production

## Übersicht
Diese Anleitung beschreibt das Setup des Carambus API-Servers auf einem Produktions-Server mit Docker.

## 🏁 Schnellstart

```bash
# Deployment auf API-Server
./deploy-docker.sh carambus_newapi www-data@carambus.de /var/www/carambus_newapi
```

## 📋 Voraussetzungen

### Server-Zugang
- **SSH**: `ssh -p 8910 www-data@carambus.de`
- **Domain**: newapi.carambus.de
- **SSL**: Let's Encrypt Zertifikate für carambus.de

### Benötigte Dateien
- Datenbank-Dump: `carambus_api_development_20250804_0218_fixed.sql.gz`
- Rails Credentials: `production.key`

## 🚀 Deployment-Prozess

### 1. Automatisches Deployment
```bash
# Auf Ihrem lokalen Computer ausführen
./deploy-docker.sh carambus_newapi www-data@carambus.de /var/www/carambus_newapi
```

Das Skript führt automatisch aus:
- Docker Installation (falls nötig)
- Repository klonen/aktualisieren
- Umgebungsvariablen konfigurieren
- Datenbank-Setup mit Dump
- Container-Build und -Start
- Nginx Host-Konfiguration
- SSL-Integration

### 2. Manuelle Schritte (nur bei Bedarf)

#### Server vorbereiten
```bash
# Mit Server verbinden
ssh -p 8910 www-data@carambus.de

# System aktualisieren (als root/sudo)
sudo apt update && sudo apt upgrade -y

# Docker installieren (falls nicht vorhanden)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker www-data
```

## ⚙️ Konfiguration

### Automatische Konfiguration für newapi:
- **Port**: 3001 (Host-Binding auf 127.0.0.1)
- **Datenbank**: carambus_newapi (Port 5433)
- **Redis**: Port 6380
- **Domain**: newapi.carambus.de
- **SSL**: Aktiviert via Host-Nginx + Let's Encrypt

### Nginx Host-Integration
Das Deployment konfiguriert automatisch:

```nginx
# /etc/nginx/sites-enabled/newapi.carambus.de
server {
    server_name newapi.carambus.de;
    
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_set_header Host $http_host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # SSL configuration
    listen 443 ssl http2;
    ssl_certificate /etc/letsencrypt/live/newapi.carambus.de/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/newapi.carambus.de/privkey.pem;
}
```

## 🔧 Wartung und Monitoring

### Container-Status prüfen
```bash
cd /var/www/carambus_newapi
docker compose ps
```

### Logs anschauen
```bash
# Web-Container Logs
docker compose logs web --tail=100

# Alle Services
docker compose logs --tail=50
```

### Performance Monitoring
```bash
# Container Ressourcen-Verbrauch
docker stats

# Nginx Logs
sudo tail -f /var/log/nginx/newapi.carambus.de_access.log
sudo tail -f /var/log/nginx/newapi.carambus.de_error.log
```

### Datenbank-Zugriff
```bash
# PostgreSQL Console
docker compose exec postgres psql -U www_data -d carambus_newapi

# Datenbank-Backup erstellen
docker compose exec postgres pg_dump -U www_data carambus_newapi > backup_$(date +%Y%m%d).sql
```

## 🚀 Updates und Deployments

### Code-Updates
```bash
# Erneutes Deployment (holt automatisch neuesten Code)
./deploy-docker.sh carambus_newapi www-data@carambus.de /var/www/carambus_newapi
```

### Datenbank-Updates
```bash
# Migrationen ausführen
cd /var/www/carambus_newapi
docker compose exec web bundle exec rails db:migrate
```

### Container neu starten
```bash
cd /var/www/carambus_newapi
docker compose restart web
```

## 🔒 Sicherheit

### SSL-Zertifikate erneuern
```bash
# Let's Encrypt Zertifikate automatisch erneuern
sudo certbot renew

# Nginx neu laden
sudo systemctl reload nginx
```

### Firewall-Einstellungen
```bash
# Nur notwendige Ports öffnen
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8910/tcp  # SSH Port
```

### Container-Sicherheit
- Container laufen als `www-data` User (nicht root)
- Datenbank ist nur intern erreichbar
- Redis ist nur intern erreichbar
- Web-Container ist nur auf 127.0.0.1 gebunden

## 🆘 Troubleshooting

### Container startet nicht
```bash
# Docker-Status prüfen
sudo systemctl status docker

# Container-Logs anschauen
docker compose logs web

# Container manuell starten
docker compose up -d
```

### 500 Internal Server Error
```bash
# Rails-Logs prüfen
docker compose logs web --tail=100

# Rails Console öffnen
docker compose exec web bundle exec rails console

# Asset-Precompilation
docker compose exec web bundle exec rails assets:precompile
```

### Nginx-Probleme
```bash
# Nginx-Konfiguration testen
sudo nginx -t

# Nginx-Status
sudo systemctl status nginx

# Nginx neu laden
sudo systemctl reload nginx
```

### Datenbank-Verbindungsprobleme
```bash
# PostgreSQL-Status prüfen
docker compose exec postgres pg_isready -U www_data

# Datenbank-Verbindung testen
docker compose exec web bundle exec rails db:version
```

## 📊 Backup-Strategie

### Automatische Backups
```bash
# Crontab für tägliche Backups
crontab -e

# Täglich um 2:00 Uhr
0 2 * * * cd /var/www/carambus_newapi && docker compose exec postgres pg_dump -U www_data carambus_newapi | gzip > /var/backups/carambus_newapi_$(date +\%Y\%m\%d).sql.gz
```

### Restore von Backup
```bash
# Datenbank wiederherstellen
cd /var/www/carambus_newapi
docker compose exec -T postgres psql -U www_data -d carambus_newapi < backup.sql
```

---

**⚡ Performance-Tipp**: Für optimale Performance sollte der Server mindestens 2GB RAM und SSD-Storage haben. Die Container sind für Produktions-Workloads optimiert.