# Carambus Shared Libraries

Diese Bibliotheken werden von allen Skripten im `bin/` Verzeichnis verwendet.

## carambus_env.sh

Stellt portable Pfadvariablen für Bash-Skripte bereit.

### Verwendung

```bash
#!/bin/bash
set -e

# Load Carambus environment
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/carambus_env.sh"

# Nun verfügbar:
echo "Base: $CARAMBUS_BASE"
echo "Data: $CARAMBUS_DATA"
echo "Scenarios: $SCENARIOS_PATH"
echo "Master: $CARAMBUS_MASTER"
```

### Exportierte Variablen

| Variable | Beschreibung | Beispiel |
|----------|-------------|----------|
| `CARAMBUS_BASE` | Hauptverzeichnis | `/Volumes/EXT2TB/gullrich/DEV/carambus` |
| `CARAMBUS_DATA` | Datenverzeichnis | `$CARAMBUS_BASE/carambus_data` |
| `SCENARIOS_PATH` | Scenario-Verzeichnis | `$CARAMBUS_DATA/scenarios` |
| `CARAMBUS_MASTER` | Master-Branch | `$CARAMBUS_BASE/carambus_master` |
| `CARAMBUS_API` | API-Branch | `$CARAMBUS_BASE/carambus_api` |
| `CARAMBUS_BCW` | BCW-Branch | `$CARAMBUS_BASE/carambus_bcw` |
| `CARAMBUS_LOCATION_5101` | Location-Branch | `$CARAMBUS_BASE/carambus_location_5101` |

### Erkennungsmethoden

1. **Environment Variable** `$CARAMBUS_BASE` (höchste Priorität)
2. **Config File** `~/.carambus_config`
3. **Auto-Detection** durch Suche nach `carambus_data/` Verzeichnis
4. **Fallback** zum Standard-Pfad

### Debug-Modus

```bash
export CARAMBUS_DEBUG=true
source lib/carambus_env.sh
# Zeigt: [CARAMBUS_ENV] CARAMBUS_BASE: /path/to/carambus
```

## Konfiguration

### Option 1: Keine Konfiguration (Auto-Detection)

Wenn Skripte aus dem `carambus_*/bin/` Verzeichnis ausgeführt werden, funktioniert Auto-Detection:

```bash
cd /any/path/carambus_master/bin
./install-client-only.sh ...  # Auto-erkennt /any/path als CARAMBUS_BASE
```

### Option 2: Config File

Erstelle `~/.carambus_config`:

```bash
# MacBook Pro
CARAMBUS_BASE=/Users/gullrich/Development/carambus

# Optional: Debug Mode
# CARAMBUS_DEBUG=true
```

### Option 3: Environment Variable

```bash
# In .zshrc oder .bashrc
export CARAMBUS_BASE=/Users/gullrich/Development/carambus

# Oder temporär
CARAMBUS_BASE=/tmp/test ./bin/some-script.sh
```

## Beispiel-Workflow: rsync von Mac Mini zu MacBook Pro

```bash
# 1. Auf MacBook Pro: rsync
cd ~/Development
rsync -av --exclude='node_modules' --exclude='tmp' --exclude='log' \
  macmini:/Volumes/EXT2TB/gullrich/DEV/carambus/ ./carambus/

# 2. Config erstellen
echo "CARAMBUS_BASE=$HOME/Development/carambus" > ~/.carambus_config

# 3. Skripte verwenden
cd ~/Development/carambus/carambus_master/bin
./setup-raspi-table-client.sh carambus_bcw 192.168.178.81 ...
# ✅ Funktioniert automatisch mit korrekten Pfaden!
```

## Siehe auch

- `../../lib/carambus_env.rb` - Ruby-Äquivalent für Rails/Rake
- `../../.carambus_config.example` - Beispiel-Konfiguration
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_data/CARAMBUS_BASE_IMPLEMENTATION.md` - Vollständige Dokumentation

