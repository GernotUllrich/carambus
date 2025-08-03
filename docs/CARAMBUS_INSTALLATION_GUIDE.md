# Carambus Server Installation & Migration Guide

## Übersicht

Dieses Dokument beschreibt die automatisierten Prozesse für:
1. **Neuinstallation** eines Carambus-Servers auf einem Raspberry Pi
2. **Migration** bestehender Installationen zu neuen Hauptversionen

Das Ziel ist es, diese Prozesse so zu vereinfachen, dass ein lokaler System-Manager ohne tiefe technische Kenntnisse diese Aufgaben durchführen kann.

## 🏗️ Architektur-Übersicht

### Bestehende Komponenten
- **Deployment**: Capistrano + Puma + Nginx
- **Scoreboard**: Automatisierter Autostart mit LXDE
- **Datenbank**: PostgreSQL mit API-Synchronisation
- **Docker**: Bereits konfiguriert (Dockerfile, Kamal)
- **Mode Switcher**: LOCAL vs API Modi

### Neue Automatisierungskomponenten
- **Docker Images**: Custom Raspberry Pi Images
- **Installations-Scripts**: Automatisierte Setup-Prozesse
- **Backup/Restore**: Lokalisierungs-Backup-System
- **Web-Interface**: Browser-basierte Konfiguration

## 🚀 Installationstypen

### Typ 1: Docker-basierte Installation (Empfohlen)

#### Vorteile
- ✅ Konsistente Umgebung
- ✅ Einfache Migration
- ✅ Minimaler technischer Aufwand
- ✅ Reproduzierbare Installationen
- ✅ Automatische Updates

#### Prozess
1. **Raspberry Pi Imager** mit Custom Image
2. **Automatische Konfiguration** beim ersten Boot
3. **Web-basierte Lokalisierung**
4. **Automatischer Scoreboard-Start**

### Typ 2: Ansible-basierte Installation

#### Vorteile
- ✅ Nutzt bestehende Infrastruktur
- ✅ Detaillierte Kontrolle
- ✅ Bewährte Methoden

#### Prozess
1. **Standard Raspberry Pi OS** Installation
2. **Ansible Playbook** für System-Setup
3. **Capistrano Deployment**
4. **Manuelle Lokalisierung**

### Typ 3: Hybrid-Ansatz

#### Kombination
- **Docker** für Anwendung
- **Ansible** für System-Setup
- **Custom Images** für Raspberry Pi

## 📋 Installationsprozess (Docker-basiert)

### Phase 1: Vorbereitung

#### 1.1 Custom Raspberry Pi Image erstellen
```bash
# Basis-Image mit Docker und Carambus vorinstalliert
# Automatische Konfiguration beim ersten Boot
# Web-basierte Lokalisierung
```

#### 1.2 Installations-Script
```bash
#!/bin/bash
# carambus-install.sh
# Automatische Installation nach Boot

# 1. System-Updates
sudo apt update && sudo apt upgrade -y

# 2. Docker installieren
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 3. Carambus Container starten
docker-compose up -d

# 4. Web-Interface für Lokalisierung starten
# http://localhost:8080/setup
```

### Phase 2: Automatische Konfiguration

#### 2.1 Netzwerk-Konfiguration
```yaml
# config/network.yml
network:
  hostname: "carambus-{location_id}"
  ip_address: "192.168.178.{ip_suffix}"
  wifi:
    ssid: "{wifi_ssid}"
    password: "{wifi_password}"
```

#### 2.2 Datenbank-Initialisierung
```bash
# Automatische Erstellung der lokalen Datenbank
# Synchronisation mit API-Server
# Erstellung der lokalen Konfiguration
```

### Phase 3: Web-basierte Lokalisierung

#### 3.1 Setup-Interface
```ruby
# app/controllers/setup_controller.rb
class SetupController < ApplicationController
  def index
    # Anzeige der Setup-Schritte
  end
  
  def configure_location
    # Konfiguration von Region, Club, Location
  end
  
  def configure_tables
    # Definition der Spieltische
  end
  
  def configure_users
    # Eintragung von Benutzern und Gastspielern
  end
end
```

#### 3.2 Setup-Workflow
1. **Region/Club auswählen**
2. **Location konfigurieren**
3. **Tische definieren**
4. **Benutzer anlegen**
5. **Scoreboard testen**

## 🔄 Migrationsprozess

### Phase 1: Backup erstellen

#### 1.1 Lokalisierungs-Backup
```bash
#!/bin/bash
# backup-localization.sh

# 1. Datenbank-Backup
pg_dump -Uwww_data carambus_production > backup_$(date +%Y%m%d_%H%M%S).sql

# 2. Konfigurations-Backup
tar -czf config_backup_$(date +%Y%m%d_%H%M%S).tar.gz \
  config/carambus.yml \
  config/database.yml \
  config/scoreboard_url

# 3. Lokalisierungs-Daten extrahieren
rails runner "LocalizationExporter.export_to_json"
```

#### 1.2 Backup-Validierung
```ruby
# lib/tasks/backup.rake
namespace :backup do
  desc "Validate backup integrity"
  task validate: :environment do
    # Prüfung der Backup-Integrität
    # Validierung der lokalen Daten
    # Bestätigung der Migration
  end
end
```

### Phase 2: Neue Version installieren

#### 2.1 Automatische Installation
```bash
#!/bin/bash
# migrate-to-new-version.sh

# 1. Backup erstellen
./backup-localization.sh

# 2. Neue Version herunterladen
docker pull carambus/carambus:latest

# 3. Container stoppen
docker-compose down

# 4. Neue Version starten
docker-compose up -d

# 5. Datenbank-Migration
docker-compose exec app rails db:migrate

# 6. Backup wiederherstellen
./restore-localization.sh
```

#### 2.2 Rollback-Mechanismus
```bash
#!/bin/bash
# rollback-migration.sh

# Bei Problemen: Zurück zur vorherigen Version
docker-compose down
docker tag carambus/carambus:previous carambus/carambus:current
docker-compose up -d
./restore-localization.sh
```

### Phase 3: Backup wiederherstellen

#### 3.1 Lokalisierungs-Restore
```bash
#!/bin/bash
# restore-localization.sh

# 1. Datenbank wiederherstellen
psql -Uwww_data carambus_production < backup_*.sql

# 2. Konfiguration wiederherstellen
tar -xzf config_backup_*.tar.gz

# 3. Lokalisierungs-Daten importieren
rails runner "LocalizationImporter.import_from_json"

# 4. Scoreboard neu starten
systemctl restart scoreboard
```

## 🛠️ Technische Implementierung

### Docker-Compose Konfiguration
```yaml
# docker-compose.yml
version: '3.8'
services:
  app:
    image: carambus/carambus:latest
    ports:
      - "3000:3000"
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgresql://www_data:password@db:5432/carambus_production
    depends_on:
      - db
      - redis
    volumes:
      - ./config:/rails/config
      - ./storage:/rails/storage
      - ./log:/rails/log

  db:
    image: postgres:13
    environment:
      - POSTGRES_DB=carambus_production
      - POSTGRES_USER=www_data
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:6-alpine
    volumes:
      - redis_data:/data

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - app

volumes:
  postgres_data:
  redis_data:
```

### Web-basiertes Setup-Interface
```ruby
# app/views/setup/index.html.erb
<div class="setup-wizard">
  <div class="step active" data-step="1">
    <h2>Willkommen bei Carambus</h2>
    <p>Lassen Sie uns Ihren Server konfigurieren...</p>
    
    <div class="form-group">
      <label>Region auswählen:</label>
      <select id="region-select">
        <option value="">Bitte wählen...</option>
        <% Region.all.each do |region| %>
          <option value="<%= region.id %>"><%= region.name %></option>
        <% end %>
      </select>
    </div>
    
    <div class="form-group">
      <label>Club auswählen:</label>
      <select id="club-select" disabled>
        <option value="">Bitte Region zuerst wählen...</option>
      </select>
    </div>
    
    <button class="btn btn-primary" onclick="nextStep()">Weiter</button>
  </div>
  
  <!-- Weitere Setup-Schritte... -->
</div>
```

## 📊 Monitoring und Wartung

### Health-Check System
```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def index
    health_status = {
      database: database_healthy?,
      redis: redis_healthy?,
      scoreboard: scoreboard_healthy?,
      api_connection: api_connection_healthy?
    }
    
    render json: health_status
  end
  
  private
  
  def database_healthy?
    ActiveRecord::Base.connection.active?
  rescue
    false
  end
  
  def redis_healthy?
    Redis.new.ping == "PONG"
  rescue
    false
  end
  
  def scoreboard_healthy?
    systemctl("is-active", "scoreboard") == "active"
  end
  
  def api_connection_healthy?
    # Prüfung der API-Verbindung
  end
end
```

### Automatische Updates
```bash
#!/bin/bash
# auto-update.sh

# Täglich um 2:00 Uhr prüfen
# Neue Version verfügbar?
# Backup erstellen
# Update durchführen
# Tests ausführen
# Rollback bei Problemen
```

## 🔧 Troubleshooting

### Häufige Probleme

#### 1. Scoreboard startet nicht
```bash
# Diagnose
systemctl status scoreboard
journalctl -u scoreboard -f

# Lösung
sudo systemctl restart scoreboard
```

#### 2. Datenbank-Verbindung fehlschlägt
```bash
# Diagnose
docker-compose logs db
psql -Uwww_data -h localhost carambus_production

# Lösung
docker-compose restart db
```

#### 3. API-Synchronisation funktioniert nicht
```bash
# Diagnose
curl -I https://api.carambus.de/health
rails runner "ApiHealthChecker.check"

# Lösung
# Netzwerk-Konfiguration prüfen
# API-Credentials validieren
```

## 📚 Nächste Schritte

### Sofortige Implementierung
1. **Docker-Image** für Raspberry Pi erstellen
2. **Web-basiertes Setup-Interface** entwickeln
3. **Backup/Restore-System** implementieren
4. **Dokumentation** für System-Manager erstellen

### Langfristige Verbesserungen
1. **Automatische Updates** implementieren
2. **Monitoring-Dashboard** entwickeln
3. **Remote-Management** ermöglichen
4. **Multi-Location-Support** erweitern

---

*Diese Dokumentation wird kontinuierlich erweitert und basiert auf der bestehenden Carambus-Architektur.* 