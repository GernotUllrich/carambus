# Carambus Deployment - Einfach und Übersichtlich

## Übersicht

Carambus verwendet **Capistrano** für alle Deployments. Docker wurde entfernt, da es unnötig komplex war.

## Server-Struktur

### Aktuell (carambus2 - Jumpstart Pro)
- **API Server**: `api.carambus.de` → `/var/www/carambus2_api/current`
- **Local Server**: `carambus.de` → `/var/www/carambus2/current`

### Neu (carambus - Open Source)
- **API Server**: `newapi.carambus.de` → `/var/www/carambus_api/current`
- **Local Server**: `carambus.de` → `/var/www/carambus/current`

## Deployment

### Einfach deployen

#### API Server (newapi.carambus.de)
```bash
# Einfach mit Skript
./scripts/deploy-api.sh

# Oder manuell
bundle exec cap api deploy
```

#### Local Server (carambus.de)
```bash
# Einfach mit Skript
./scripts/deploy-local.sh

# Oder manuell
bundle exec cap local deploy
```

## Asset-Building

**Wichtig**: Assets werden **automatisch auf dem Server** während des Deployments gebaut:

1. **Yarn-Dependencies installieren** - `yarn install --production=false`
2. **JavaScript bauen** - `yarn build`
3. **CSS bauen** - `yarn build:css`
4. **Rails Assets precompilieren** - `rails assets:precompile`

Du musst **nichts lokal** bauen - Capistrano übernimmt das alles!

## Konfiguration

### Capistrano-Konfigurationen
- `config/deploy/api.rb` - API Server
- `config/deploy/local.rb` - Local Server
- `config/deploy.rb` - Gemeinsame Einstellungen (inkl. Asset-Building)

### Nginx-Konfigurationen
- `nginx-host-config/newapi.carambus.de` - API Server
- `nginx-host-config/carambus.de` - Local Server

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
✅ **Automatisch** - Assets werden auf dem Server gebaut  
✅ **Übersichtlich** - Keine Docker-Komplexität  
✅ **Standard** - Normale Rails-Deployment-Pipeline  
✅ **Wartbar** - Weniger Konfigurationsdateien  
✅ **Zuverlässig** - Bewährtes Capistrano  

## Migration von carambus2

1. **Production Domains verwenden** `api.carambus.de` und `carambus.de`
2. **Funktionalität verifizieren**
3. **DNS umstellen** von `api.carambus.de` → `newapi.carambus.de`
4. **Alte carambus2-Installationen** entfernen

## Entwicklung

Für lokale Entwicklung:
- **API Mode**: `RAILS_ENV=development rails server -p 3000`
- **Local Mode**: `RAILS_ENV=development rails server -p 3001`

## Asset-Building Details

Das Asset-Building läuft in dieser Reihenfolge ab:

1. **Node.js/Yarn verifizieren** - Prüft ob Node.js 20.15.0 verfügbar ist
2. **Dependencies installieren** - `yarn install` im Release-Verzeichnis
3. **Frontend-Assets bauen** - `yarn build` und `yarn build:css`
4. **Rails Assets precompilieren** - Standard Rails Asset Pipeline
5. **Manifest verifizieren** - Prüft ob Assets korrekt erstellt wurden

Alle Tasks laufen automatisch im Production-Environment auf dem Server.
