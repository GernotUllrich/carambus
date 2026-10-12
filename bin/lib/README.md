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
| `CARAMBUS_BASE` | Hauptverzeichnis | `/Users/gullrich/DEV/carambus` |
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
# Auf jedem Rechner derselbe Pfad (siehe unten)
CARAMBUS_BASE=/Users/gullrich/DEV/carambus

# Optional: Debug Mode
# CARAMBUS_DEBUG=true
```

### Option 3: Environment Variable

```bash
# In .zshrc oder .bashrc
export CARAMBUS_BASE=/Users/gullrich/DEV/carambus

# Oder temporär
CARAMBUS_BASE=/tmp/test ./bin/some-script.sh
```

## Mehrere Rechner: der Pfad ist eine Invariante

Die Skripte selbst funktionieren unter jedem Pfad. Trotzdem liegt der Baum auf
**jedem** eigenen Rechner (Mac Mini, MacBook Pro) unter `/Users/gullrich/DEV/carambus`.

Grund: Claude Code leitet sein Projektverzeichnis unter `~/.claude/projects/` aus
dem absoluten Arbeitspfad ab (`/`→`-`, `_`→`-`). Ein anderer Pfad ergibt ein anderes,
leeres Verzeichnis — Memory und Projektzustand sind auf diesem Rechner dann
unsichtbar, ohne dass etwas fehlschlägt. Belegt: Als der Baum unter `/Volumes/EXT2TB/…`
lag, blieben 28 Memory-Dateien rund fünf Monate unerreichbar.

Einen zweiten Rechner deshalb nicht per Kopie unter einem anderen Pfad anlegen,
sondern den Baum am selben Pfad auschecken.

## Siehe auch

- `../../lib/carambus_env.rb` - Ruby-Äquivalent für Rails/Rake
- `../../.carambus_config.example` - Beispiel-Konfiguration
- `/Users/gullrich/DEV/carambus/carambus_data/CARAMBUS_BASE_IMPLEMENTATION.md` - Vollständige Dokumentation




