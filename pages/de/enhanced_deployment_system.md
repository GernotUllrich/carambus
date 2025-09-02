# Carambus Enhanced Mode System - Socket-basierte Deployment-Integration

## 🎯 **Übersicht**

Das erweiterte Mode System verwendet **Unix Sockets** für die effiziente Kommunikation zwischen NGINX und Puma, basierend auf der bewährten carambus2-Architektur.

## 🚀 **Socket-basiertes Deployment**

### **Template-Generierung und -Übertragung**

Das System generiert und überträgt automatisch:

1. **NGINX Konfiguration** (`config/nginx.conf`)
   - Verwendet Unix Socket: `unix:/var/www/{basename}/shared/sockets/{puma_socket}`
   - Kopiert nach `/etc/nginx/sites-available/{basename}`
   - Erstellt Symlink in `/etc/nginx/sites-enabled/`
   - Testet Konfiguration und lädt NGINX neu

2. **Puma.rb Konfiguration** (`config/puma.rb`)
   - Bindet an Unix Socket: `unix://{shared_dir}/sockets/puma-{rails_env}.sock`
   - Erstellt Socket-Verzeichnisse automatisch
   - Setzt korrekte Socket-Berechtigungen (0666)
   - Konfiguriert PID- und State-Dateien

3. **Puma Service Konfiguration** (`config/puma.service`)
   - Kopiert nach `/etc/systemd/system/puma-{basename}.service`
   - Erstellt Socket-Verzeichnisse vor Service-Start
   - Lädt systemd daemon neu
   - Aktiviert den Service

4. **Scoreboard URL** (`config/scoreboard_url`)
   - Kopiert nach `/var/www/{basename}/shared/config/scoreboard_url`

### **Deployment-Workflow**

```bash
# 1. Mode konfigurieren (generiert Socket-basierte Templates)
bundle exec rails 'mode:api' MODE_BASENAME=carambus_api MODE_HOST=newapi.carambus.de MODE_NGINX_PORT=80 MODE_PUMA_SOCKET=puma-production.sock MODE_SSL_ENABLED=true

# 2. Templates werden automatisch generiert
# 3. Deployment ausführen (überträgt automatisch Socket-Templates)
bundle exec cap production deploy
```

## 🔧 **Socket-basierte Konfiguration**

### **Unix Socket Vorteile**
- ✅ **Effizienter** - Keine TCP/IP Overhead
- ✅ **Sicherer** - Nur lokale Kommunikation
- ✅ **Schneller** - Direkte Kernel-Kommunikation
- ✅ **Skalierbarer** - Bessere Performance unter Last

### **Socket-Pfad Struktur**
```
/var/www/{basename}/shared/
├── sockets/
│   └── puma-{rails_env}.sock    # Unix Socket
├── pids/
│   ├── puma-{rails_env}.pid     # Process ID
│   └── puma-{rails_env}.state   # State File
└── log/
    ├── puma.stdout.log          # Standard Output
    └── puma.stderr.log          # Standard Error
```

## 🔧 **Automatische Template-Verwaltung**

### **Templates werden automatisch generiert**
```bash
# Bei jedem Mode-Wechsel werden Templates automatisch generiert
bundle exec rails 'mode:api' MODE_BASENAME=carambus_api MODE_NGINX_PORT=80 MODE_PUMA_SOCKET=puma-production.sock
```

### **Templates über Capistrano deployen**
```bash
# Alle Templates (automatisch nach Deployment)
bundle exec cap production deploy

# Einzelne Template-Tasks
bundle exec cap production deploy:nginx_config
bundle exec cap production deploy:puma_rb_config
bundle exec cap production deploy:puma_service_config
```

## 📋 **Capistrano Integration**

### **Automatische Template-Übertragung**

Die folgenden Dateien werden automatisch übertragen:
- `config/nginx.conf` → `/var/www/{basename}/shared/config/nginx.conf`
- `config/puma.rb` → `/var/www/{basename}/shared/puma.rb`
- `config/puma.service` → `/var/www/{basename}/shared/config/puma.service`
- `config/scoreboard_url` → `/var/www/{basename}/shared/config/scoreboard_url`

### **Deployment-Hooks**

```ruby
# Automatisch nach jedem Deployment
after "deploy:published", "deploy:deploy_templates"
```

### **Verfügbare Capistrano Tasks**

```bash
# Template-Deployment
cap deploy:deploy_templates              # Alle Templates deployen
cap deploy:nginx_config                  # NGINX Konfiguration deployen
cap deploy:puma_rb_config                # Puma.rb Konfiguration deployen
cap deploy:puma_service_config           # Puma Service deployen

# Puma Management
cap puma:restart                         # Puma neu starten
cap puma:stop                            # Puma stoppen
cap puma:start                           # Puma starten
cap puma:status                          # Puma Status anzeigen
```

## 🎛️ **Konfigurationsparameter**

### **NGINX Parameter**
- `MODE_NGINX_PORT` - Web-Port (default: 80)
- `MODE_SSL_ENABLED` - SSL aktiviert (true/false, default: false)
- `MODE_DOMAIN` - Domain-Name

### **Puma Socket Parameter**
- `MODE_PUMA_SOCKET` - Socket-Name (default: puma-{rails_env}.sock)
- `MODE_RAILS_ENV` - Rails Environment

### **Scoreboard Parameter**
- `MODE_LOCATION_ID` - Location ID für URL-Generierung
- `MODE_SCOREBOARD_URL` - Manuelle Scoreboard URL

## 🔄 **Deployment-Workflow Beispiel**

### **In-house Server (Raspberry Pi)**
```bash
# 1. Mode konfigurieren
bundle exec rails 'mode:local' \
  MODE_HOST=192.168.1.100 \
  MODE_PORT=22 \
  MODE_NGINX_PORT=3131 \
  MODE_PUMA_SOCKET=puma-production.sock \
  MODE_SSL_ENABLED=false

# 2. Templates werden automatisch generiert
# 3. Deployment
bundle exec cap production deploy
```

### **Production Server (Hetzner)**
```bash
# 1. Mode konfigurieren
bundle exec rails 'mode:api' \
  MODE_BASENAME=carambus_api \
  MODE_HOST=newapi.carambus.de \
  MODE_PORT=8910 \
  MODE_PUMA_SOCKET=puma-production.sock \
  MODE_SSL_ENABLED=true \
  MODE_NGINX_PORT=80

# 2. Templates werden automatisch generiert
# 3. Deployment
bundle exec cap production deploy
```

## 🔍 **Troubleshooting**

### **Socket-Berechtigungen prüfen**
```bash
# Socket-Verzeichnis prüfen
ls -la /var/www/carambus_api/shared/sockets/

# Socket-Berechtigungen prüfen
ls -la /var/www/carambus_api/shared/sockets/puma-production.sock
```

### **NGINX Socket-Konfiguration testen**
```bash
# Lokal testen
sudo nginx -t

# Auf Server testen
ssh -p 8910 www-data@newapi.carambus.de 'sudo nginx -t'
```

### **Puma Socket Status**
```bash
# Socket-Verbindung prüfen
ssh -p 8910 www-data@newapi.carambus.de 'netstat -an | grep puma'

# Service Status
ssh -p 8910 www-data@newapi.carambus.de 'sudo systemctl status puma-carambus_api.service'
```

### **Socket-Verzeichnisse erstellen**
```bash
# Manuell Socket-Verzeichnisse erstellen
ssh -p 8910 www-data@newapi.carambus.de 'sudo mkdir -p /var/www/carambus_api/shared/sockets /var/www/carambus_api/shared/pids /var/www/carambus_api/shared/log'
```

## 📁 **Dateistruktur**

```
config/
├── nginx.conf.erb          # NGINX Template (Socket-basiert)
├── puma.rb.erb             # Puma.rb Template (Socket-basiert)
├── puma.service.erb        # Puma Service Template
├── scoreboard_url.erb      # Scoreboard URL Template
├── nginx.conf              # Generierte NGINX Konfiguration
├── puma.rb                 # Generierte Puma.rb Konfiguration
├── puma.service            # Generierter Puma Service
└── scoreboard_url          # Generierte Scoreboard URL

lib/capistrano/tasks/
└── templates.rake          # Capistrano Template-Tasks
```

## ✅ **Vorteile der Socket-basierten Architektur**

1. **Performance** - Unix Sockets sind schneller als TCP/IP
2. **Sicherheit** - Keine Netzwerk-Exposition
3. **Effizienz** - Weniger Overhead
4. **Skalierbarkeit** - Bessere Performance unter Last
5. **Kompatibilität** - Bewährte carambus2-Architektur
6. **Automatisierung** - Vollständige Template-Generierung
7. **Debugging** - Vollständige RubyMine-Integration
8. **Wartbarkeit** - Zentrale Socket-Verwaltung

## 🔄 **Multi-Environment Deployment**

### **Deployment-Script Integration**
```bash
# API Server Deployment mit automatischem Pull
./bin/deploy.sh deploy-api

# Local Server Deployment mit automatischem Pull
./bin/deploy.sh deploy-local

# Full Local Deployment
./bin/deploy.sh full-local
```

### **Automatischer Repo-Pull**
Das Deployment-System führt automatisch einen `git pull` für die jeweiligen Szenario-Ordner durch, bevor das Deployment startet.

## 🎉 **Fazit**

Das **Enhanced Mode System** mit Socket-basierter Architektur bietet:

- ✅ **Vollständige Automatisierung**
- ✅ **Socket-basierte Performance**
- ✅ **RubyMine-Integration**
- ✅ **Multi-Environment Support**
- ✅ **Automatische Template-Generierung**
- ✅ **Robuste Deployment-Pipeline**

**Empfehlung**: Verwende das Enhanced Mode System für alle Carambus-Deployments.

Das System macht das Deployment **schnell, sicher und wartbar**! 🚀
