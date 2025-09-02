# Carambus Enhanced Mode System - Deployment Integration

## 🎯 **Übersicht**

Das erweiterte Mode System integriert sich nahtlos in das Capistrano Deployment und überträgt automatisch alle generierten Templates und Konfigurationen.

## 🚀 **Automatisches Deployment**

### **Template-Generierung und -Übertragung**

Das System generiert und überträgt automatisch:

1. **NGINX Konfiguration** (`config/nginx.conf`)
   - Kopiert nach `/etc/nginx/sites-available/{basename}`
   - Erstellt Symlink in `/etc/nginx/sites-enabled/`
   - Testet Konfiguration und lädt NGINX neu

2. **Puma Service Konfiguration** (`config/puma.service`)
   - Kopiert nach `/etc/systemd/system/puma-{basename}.service`
   - Lädt systemd daemon neu
   - Aktiviert den Service

3. **Scoreboard URL** (`config/scoreboard_url`)
   - Kopiert nach `/var/www/{basename}/shared/config/scoreboard_url`

### **Deployment-Workflow**

```bash
# 1. Mode konfigurieren (generiert Templates)
bundle exec rails 'mode:api' MODE_BASENAME=carambus_api MODE_HOST=newapi.carambus.de

# 2. Templates für Deployment generieren
bundle exec rails mode:generate_templates

# 3. Deployment ausführen (überträgt automatisch Templates)
bundle exec cap production deploy
```

## 🔧 **Manuelle Template-Verwaltung**

### **Templates kopieren**
```bash
bundle exec rails mode:copy_templates
```
Kopiert generierte Templates nach `/local_storage/`

### **Templates manuell deployen**
```bash
bundle exec rails mode:deploy_templates
```
Deployt Templates aus `/local_storage/` zum Server

### **Templates über Capistrano deployen**
```bash
# Alle Templates
bundle exec cap production deploy:deploy_templates

# Nur NGINX
bundle exec cap production deploy:nginx_config

# Nur Puma Service
bundle exec cap production deploy:puma_service_config
```

## 📋 **Capistrano Integration**

### **Automatische Template-Übertragung**

Die folgenden Dateien werden automatisch übertragen:
- `config/nginx.conf` → `/var/www/{basename}/shared/config/nginx.conf`
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

### **Puma Parameter**
- `MODE_PUMA_PORT` - Application-Port (default: 3000/3001)
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
  MODE_PUMA_PORT=3000 \
  MODE_SSL_ENABLED=false

# 2. Templates generieren
bundle exec rails mode:generate_templates

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
  MODE_SSL_ENABLED=true

# 2. Templates generieren
bundle exec rails mode:generate_templates

# 3. Deployment
bundle exec cap production deploy
```

## 🔍 **Troubleshooting**

### **NGINX Konfiguration testen**
```bash
# Lokal testen
sudo nginx -t

# Auf Server testen
ssh -p 8910 www-data@newapi.carambus.de 'sudo nginx -t'
```

### **Puma Service Status**
```bash
# Service Status
ssh -p 8910 www-data@newapi.carambus.de 'sudo systemctl status puma-carambus_api.service'

# Service starten
ssh -p 8910 www-data@newapi.carambus.de 'sudo systemctl start puma-carambus_api.service'
```

### **Templates manuell aktualisieren**
```bash
# Templates neu generieren
bundle exec rails mode:generate_templates

# Templates manuell deployen
bundle exec rails mode:deploy_templates
```

## 📁 **Dateistruktur**

```
config/
├── nginx.conf.erb          # NGINX Template
├── puma.service.erb        # Puma Service Template
├── scoreboard_url.erb      # Scoreboard URL Template
├── nginx.conf              # Generierte NGINX Konfiguration
├── puma.service            # Generierter Puma Service
└── scoreboard_url          # Generierte Scoreboard URL

local_storage/
├── nginx_configs/          # Lokale NGINX Konfigurationen
├── puma_configs/           # Lokale Puma Konfigurationen
├── scoreboard_configs/     # Lokale Scoreboard URLs
└── database_dumps/         # Database Dumps

lib/capistrano/tasks/
└── templates.rake          # Capistrano Template-Tasks
```

## ✅ **Vorteile**

1. **Automatisierung** - Templates werden automatisch generiert und übertragen
2. **Konsistenz** - Alle Server verwenden die gleichen Konfigurationen
3. **Flexibilität** - Unterstützung für verschiedene Server-Typen
4. **Debugging** - Vollständige RubyMine-Integration
5. **Sicherheit** - Templates werden getestet vor Aktivierung
6. **Wartbarkeit** - Zentrale Template-Verwaltung
