# Carambus Deployment - Einfach und Übersichtlich

## Übersicht

Carambus verwendet **Capistrano** für alle Deployments. Docker wurde entfernt, da es unnötig komplex war.

## Server-Struktur

### Aktuell (carambus2 - Jumpstart Pro)
- **API Server**: `api.carambus.de` → `/var/www/carambus2_api/current`
- **Local Server**: `carambus.de` → `/var/www/carambus2/current`

### Neu (carambus - Open Source)
- **API Server**: `newapi.carambus.de` → `/var/www/carambus_api/current`
- **Local Server**: `new.carambus.de` → `/var/www/carambus/current`

## Deployment

### 1. Assets bauen
```bash
yarn build
yarn build:css
rails assets:precompile
```

### 2. Deployen

#### API Server (newapi.carambus.de)
```bash
# Einfach mit Skript
./scripts/deploy-api.sh

# Oder manuell
bundle exec cap api deploy
```

#### Local Server (new.carambus.de)
```bash
# Einfach mit Skript
./scripts/deploy-local.sh

# Oder manuell
bundle exec cap local deploy
```

## Konfiguration

### Capistrano-Konfigurationen
- `config/deploy/api.rb` - API Server
- `config/deploy/local.rb` - Local Server
- `config/deploy.rb` - Gemeinsame Einstellungen

### Nginx-Konfigurationen
- `nginx-host-config/newapi.carambus.de` - API Server
- `nginx-host-config/new.carambus.de` - Local Server

## Ports

- **API Server**: Port 3000
- **Local Server**: Port 3001

## Nach dem Deployment

### Nginx neu laden
```bash
sudo systemctl reload nginx
```

### Puma-Status prüfen
```bash
# API Server
sudo systemctl status puma_carambus_api

# Local Server  
sudo systemctl status puma_carambus
```

## Vorteile des neuen Setups

✅ **Einfach** - Ein Befehl deployt alles  
✅ **Übersichtlich** - Keine Docker-Komplexität  
✅ **Standard** - Normale Rails-Deployment-Pipeline  
✅ **Wartbar** - Weniger Konfigurationsdateien  
✅ **Zuverlässig** - Bewährtes Capistrano  

## Migration von carambus2

1. **Neue Domains testen** mit `newapi.carambus.de` und `new.carambus.de`
2. **Funktionalität verifizieren**
3. **DNS umstellen** von `api.carambus.de` → `newapi.carambus.de`
4. **Alte carambus2-Installationen** entfernen

## Entwicklung

Für lokale Entwicklung:
- **API Mode**: `RAILS_ENV=development rails server -p 3000`
- **Local Mode**: `RAILS_ENV=development rails server -p 3001`
