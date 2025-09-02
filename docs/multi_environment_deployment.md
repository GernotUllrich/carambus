# Multi-Environment Deployment System

## 🏗️ **Architektur-Übersicht**

### **Directory-Struktur:**
```
/Volumes/EXT2TB/gullrich/DEV/
├── projects/                        # Git Repositories (sauber)
│   ├── carambus_api/               # API Server Repository
│   ├── carambus_local_hetzner/     # Lokaler Server Repository
│   └── carambus_local_raspi/       # Raspberry Pi Repository
│
└── carambus_data/                   # Generierte Daten (nicht im Repo)
    ├── api_server/                  # Daten für API Server
    │   ├── config/
    │   ├── credentials/
    │   ├── environments/
    │   ├── database_dumps/
    │   └── deploy/
    │
    ├── local_hetzner/              # Daten für lokalen Hetzner Server
    │   ├── config/
    │   ├── credentials/
    │   ├── environments/
    │   ├── database_dumps/
    │   └── deploy/
    │
    └── local_raspi/                 # Daten für Raspberry Pi
        ├── config/
        ├── credentials/
        ├── environments/
        ├── database_dumps/
        └── deploy/
```

## 🚀 **Deployment-Workflows**

### **1. API Server Deployment (newapi.carambus.de)**

```bash
# 1. Repository vorbereiten
cd /Volumes/EXT2TB/gullrich/DEV/projects/carambus_api
bundle install

# 2. Externe Daten-Verwaltung aktivieren
bundle exec rails 'data:set_directory[api_server]'

# 3. Mode konfigurieren
MODE_BASENAME=carambus_api \
MODE_DOMAIN=newapi.carambus.de \
MODE_SSL_ENABLED=true \
MODE_HOST=carambus.de \
MODE_PORT=8910 \
MODE_NGINX_PORT=80 \
MODE_PUMA_SOCKET=/var/www/carambus_api/shared/sockets/puma-production.sock \
bundle exec rails mode:api

# 4. Templates generieren und in externes Directory kopieren
bundle exec rails data:generate_templates

# 5. Dateien ins Repository kopieren (für Capistrano)
bundle exec rails data:deploy

# 6. Deployment ausführen
bundle exec cap production deploy
```

### **2. Lokaler Server Deployment (new.carambus.de)**

```bash
# 1. Repository vorbereiten
cd /Volumes/EXT2TB/gullrich/DEV/projects/carambus_local_hetzner
bundle install

# 2. Externe Daten-Verwaltung aktivieren
bundle exec rails 'data:set_directory[local_hetzner]'

# 3. Mode konfigurieren
MODE_BASENAME=carambus \
MODE_DOMAIN=new.carambus.de \
MODE_SSL_ENABLED=true \
MODE_HOST=carambus.de \
MODE_PORT=8910 \
MODE_NGINX_PORT=80 \
MODE_PUMA_SOCKET=/var/www/carambus/shared/sockets/puma-production.sock \
bundle exec rails mode:local

# 4. Templates generieren und in externes Directory kopieren
bundle exec rails data:generate_templates

# 5. Dateien ins Repository kopieren (für Capistrano)
bundle exec rails data:deploy

# 6. Deployment ausführen
bundle exec cap production deploy
```

## 🔧 **Rake Tasks**

### **Data Management Tasks:**
```bash
# Externes Directory setzen
bundle exec rails 'data:set_directory[environment_name]'

# Templates generieren und ins externe Directory kopieren
bundle exec rails data:generate_templates

# Dateien vom externen Directory ins Repository kopieren
bundle exec rails data:deploy
```

### **Mode Tasks:**
```bash
# API Server konfigurieren
bundle exec rails mode:api

# Lokalen Server konfigurieren
bundle exec rails mode:local

# Status anzeigen
bundle exec rails mode:status

# Vollständiges Deployment (inkl. Server-Setup)
bundle exec rails mode:full_deploy
```

## 📊 **Datenbank-Management**

### **Datenbank-Dump erstellen:**
```bash
# Lokaler Dump (für Entwicklung)
bundle exec rails mode:prepare_db_dump

# Server-Dump (von API Server)
ssh www-data@carambus.de -p 8910
cd /var/www/carambus_api/current
pg_dump -Uwww_data carambus_api_production | gzip > carambus_api_production.sql.gz
```

### **Datenbank-Dump deployen:**
```bash
# Dump auf Server kopieren
scp -P 8910 carambus_api_production.sql.gz www-data@carambus.de:/tmp/

# Dump auf Server wiederherstellen
ssh www-data@carambus.de -p 8910
sudo -u postgres psql carambus_production < /tmp/carambus_api_production.sql
```

## 🔐 **Sicherheit**

### **Credentials-Management:**
- Alle Credentials werden im externen `carambus_data` Directory gespeichert
- Keine Credentials im Git Repository
- Separate Credentials für jede Umgebung

### **SSL-Zertifikate:**
- Let's Encrypt Zertifikate für alle Domains
- Automatische HTTP zu HTTPS Weiterleitung
- SSL-Konfiguration in NGINX-Templates

## 🐛 **Troubleshooting**

### **Häufige Probleme:**

1. **PG::ConnectionBad**: 
   - Prüfe `database.yml` Username (`www_data` vs `www-data`)
   - Prüfe PostgreSQL-Passwort
   - Prüfe Datenbank-Existenz

2. **502 Bad Gateway**:
   - Prüfe Puma Service Status: `sudo systemctl status puma-carambus`
   - Prüfe Socket-Pfad in `puma.rb`
   - Prüfe NGINX-Konfiguration

3. **Ruby Version Mismatch**:
   - Stelle sicher, dass Ruby 3.2.1 installiert ist
   - Prüfe `.ruby-version` und `Gemfile`
   - Regeneriere `Gemfile.lock` lokal

### **Debugging-Commands:**
```bash
# Puma Service Status
sudo systemctl status puma-carambus

# NGINX Konfiguration testen
sudo nginx -t

# PostgreSQL Verbindung testen
sudo -u postgres psql carambus_production

# Rails Console
RAILS_ENV=production bundle exec rails c
```

## 📝 **Best Practices**

1. **Immer externe Daten-Verwaltung verwenden**
2. **Templates vor Deployment testen**
3. **Datenbank-Dumps vor Deployment erstellen**
4. **Idempotente Deployments sicherstellen**
5. **Logs nach Deployment prüfen**

## 🔄 **Versionierung**

### **Git Workflow:**
- Feature-Branches für neue Features
- Master-Branch für stabile Releases
- Tags für Versionen

### **Datenbank-Versionierung:**
- PaperTrail für Model-Versionierung
- `last_version_id` für API-Synchronisation
- Automatische Sequence-Reset nach Dumps
