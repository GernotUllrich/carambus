# Docker Troubleshooting Guide - Carambus

## 🚨 Häufige Probleme und Lösungen

### 1. Deployment-Probleme

#### `deploy-docker.sh` schlägt fehl
```bash
# Problem: Skript bricht ab
# Lösung: Verbose-Modus aktivieren
bash -x ./deploy-docker.sh carambus_newapi www-data@carambus.de /var/www/carambus_newapi

# Häufige Ursachen:
# - SSH-Verbindung fehlgeschlagen
# - Fehlende Berechtigungen
# - Docker nicht installiert
```

#### SSH-Verbindungsprobleme
```bash
# Problem: "Connection refused" oder "Permission denied"
# Lösung: SSH-Konfiguration prüfen
ssh -v -p 8910 www-data@carambus.de

# SSH-Agent für Key-Forwarding
ssh-add ~/.ssh/id_rsa
ssh -A -p 8910 www-data@carambus.de
```

### 2. Container-Probleme

#### Container startet nicht
```bash
# Status aller Container prüfen
docker compose ps

# Logs anschauen
docker compose logs

# Spezifischen Container-Log
docker compose logs web
docker compose logs postgres
docker compose logs redis

# Container manuell starten
docker compose up -d web
```

#### "Port already in use" Fehler
```bash
# Problem: Port 3001/5433/6380 bereits belegt
# Lösung: Verwendete Ports prüfen
sudo netstat -tulpn | grep :3001

# Oder anderen Port in .env konfigurieren
cd /pfad/zum/deployment
nano .env
# WEB_PORT=3002
# POSTGRES_PORT=5434
# REDIS_PORT=6381

docker compose down
docker compose up -d
```

### 3. Datenbank-Probleme

#### PostgreSQL startet nicht
```bash
# Container-Logs prüfen
docker compose logs postgres

# Datenbank-Verzeichnis-Berechtigungen
ls -la /var/lib/docker/volumes/

# Container neu erstellen (ACHTUNG: Daten gehen verloren!)
docker compose down
docker volume rm $(docker volume ls -q | grep postgres)
docker compose up -d postgres
```

#### "role does not exist" Fehler
```bash
# Problem: Datenbankbenutzer fehlt
# Lösung: Benutzer manuell erstellen
docker compose exec postgres psql -U postgres
CREATE ROLE www_data WITH LOGIN PASSWORD 'carambus_production_password';
ALTER ROLE www_data CREATEDB;
\q

# Oder Deployment erneut ausführen
./deploy-docker.sh carambus_newapi www-data@carambus.de /var/www/carambus_newapi
```

#### Datenbank-Import schlägt fehl
```bash
# Problem: SQL-Dump kann nicht importiert werden
# Lösung: Dump-Datei prüfen
gunzip -t carambus_api_development_20250804_0218_fixed.sql.gz

# Manueller Import
cd /pfad/zum/deployment
gunzip -c carambus_api_development_20250804_0218_fixed.sql.gz | docker compose exec -T postgres psql -U www_data -d carambus_newapi
```

### 4. Web-Application Probleme

#### HTTP 500 Internal Server Error
```bash
# Rails-Logs prüfen
docker compose logs web --tail=100

# Rails Console für Debugging
docker compose exec web bundle exec rails console

# Häufige Ursachen und Lösungen:
```

**Carambus.config.location_id ist nil:**
```bash
# Lösung: Produktions-Konfiguration prüfen
docker compose exec web cat config/carambus.yml | grep -A 10 "production:"

# Rails Environment prüfen
docker compose exec web bundle exec rails console
Rails.env  # sollte "production" sein
Carambus.config.location_id  # sollte nicht nil sein
```

**Devise/Warden Middleware Fehler:**
```bash
# Problem: "Warden::Proxy instance not found"
# Lösung: Rails Environment auf production setzen
cd /pfad/zum/deployment
grep RAILS_ENV docker-compose.yml
# Sollte sein: RAILS_ENV: production

# Container neu starten
docker compose restart web
```

**Asset-Pipeline Probleme:**
```bash
# Assets precompilieren
docker compose exec web bundle exec rails assets:precompile

# Asset-Dateien prüfen
docker compose exec web ls -la public/assets/

# CSS/JS nicht geladen:
# Browser-Cache leeren und neu laden
```

### 5. Nginx-Probleme

#### 502 Bad Gateway
```bash
# Problem: Nginx kann Container nicht erreichen
# Container-Status prüfen
docker compose ps

# Port-Binding prüfen
docker compose exec web netstat -tulpn | grep :3000

# Nginx-Konfiguration testen
sudo nginx -t

# Nginx-Logs prüfen
sudo tail -f /var/log/nginx/newapi.carambus.de_error.log
```

#### SSL-Zertifikat Probleme
```bash
# Zertifikat-Status prüfen
sudo certbot certificates

# Zertifikat erneuern
sudo certbot renew

# Nginx nach Zertifikat-Update neu laden
sudo systemctl reload nginx
```

### 6. Performance-Probleme

#### Langsame Antwortzeiten
```bash
# Container-Ressourcen prüfen
docker stats

# RAM-Verbrauch
free -h

# Disk-Space
df -h

# Rails-Performance-Logs
docker compose logs web | grep "Completed.*in"
```

#### Out of Memory Errors
```bash
# Problem: Container läuft aus dem Speicher
# Lösung: Memory-Limits erhöhen oder System-RAM erweitern

# Docker Memory-Limits prüfen
docker stats

# System-Memory prüfen
free -h
cat /proc/meminfo
```

### 7. Netzwerk-Probleme

#### Container können sich nicht erreichen
```bash
# Docker-Netzwerk prüfen
docker network ls
docker network inspect carambus_newapi_default

# Container-IPs prüfen
docker compose exec web hostname -i
docker compose exec postgres hostname -i

# Connectivity testen
docker compose exec web ping postgres
```

### 8. Debugging-Tools

#### Logs sammeln
```bash
# Alle Logs in eine Datei
cd /pfad/zum/deployment
docker compose logs > debug_logs_$(date +%Y%m%d_%H%M).txt

# System-Logs
sudo journalctl -u docker > docker_system_logs.txt
```

#### Container-Zugriff für Debugging
```bash
# Shell in Web-Container
docker compose exec web bash

# Shell in PostgreSQL-Container
docker compose exec postgres bash

# Root-Zugriff (falls nötig)
docker compose exec --user root web bash
```

#### Konfiguration exportieren
```bash
# Aktuelle Konfiguration sichern
cd /pfad/zum/deployment
cp .env .env.backup
cp docker-compose.yml docker-compose.yml.backup

# Container-Konfiguration anzeigen
docker compose config
```

## 🆘 Notfall-Prozeduren

### Kompletter Neustart
```bash
# Alle Container stoppen und entfernen
docker compose down

# Volumes entfernen (ACHTUNG: Daten gehen verloren!)
docker volume prune

# Images neu bauen
docker compose build --no-cache

# Neu starten
docker compose up -d
```

### System-Recovery
```bash
# Bei schwerwiegenden Problemen: Komplettes Neu-Deployment
./deploy-docker.sh carambus_newapi www-data@carambus.de /var/www/carambus_newapi

# Backup wiederherstellen
cd /var/www/carambus_newapi
gunzip -c /var/backups/carambus_newapi_latest.sql.gz | docker compose exec -T postgres psql -U www_data -d carambus_newapi
```

## 📞 Support-Informationen sammeln

Wenn Sie Hilfe benötigen, sammeln Sie diese Informationen:

```bash
# System-Info
uname -a
docker --version
docker compose version

# Container-Status
cd /pfad/zum/deployment
docker compose ps
docker compose logs --tail=100

# System-Ressourcen
free -h
df -h
docker stats --no-stream

# Netzwerk-Status
netstat -tulpn | grep -E ":(3000|3001|5432|5433|6379|6380)"
```

---

**💡 Tipp**: Die meisten Probleme lassen sich durch ein erneutes Deployment lösen: `./deploy-docker.sh [deployment_name] [server] [path]`