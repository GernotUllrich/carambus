# Health Check Logging Reduktion

## Problem
Die Health-Check-Mechanismen für Monitor-Wakeup verursachten excessive Logging, auch wenn die Funktionalität korrekt arbeitete.

## Hintergrund
**Warum Health-Checks?**
- Monitore am Local Server sind normalerweise ausgeschaltet/im Standby
- Beim Einschalten sollen sie **aktuelle** Daten zeigen, nicht eingefrorene alte Daten
- Health-Checks erkennen, wenn ein Monitor aufwacht und laden die Seite neu

**Das Problem:**
- Health-Checks laufen alle 30 Sekunden
- Wenn Monitor aus ist → WebSocket-Verbindung nicht offen
- Reconnect-Versuche → Page Reload → GET-Request
- **Resultat**: Viele Log-Einträge alle 30 Sekunden

## Lösung
✅ **Funktionalität beibehalten** (Health-Checks sind wichtig!)  
✅ **Logging drastisch reduzieren**

### Änderungen (2024-03-21)

#### 1. `app/javascript/channels/location_channel.js`
- Routine-Logs (connect, disconnect, health-start/stop) → nur bei `PERF_LOGGING`
- Health-Check-Warnungen → nur bei `PERF_LOGGING`
- **Page-Reload bleibt geloggt** mit klarer Nachricht: "Monitor wake-up: Reloading page for fresh data..."

#### 2. `app/javascript/channels/table_monitor_channel.js`
- Gleiche Änderungen wie location_channel.js
- Konsistentes Logging-Verhalten

#### 3. `app/controllers/locations_controller.rb` (aus vorheriger Session)
- Debug-Logs zu Params/User → `Rails.logger.debug` (nur bei `RAILS_LOG_LEVEL=debug`)
- Session-Daten-Logging → **komplett entfernt** (Sicherheitsrisiko!)
- Error-Logs → `Rails.logger.error` mit limitiertem Backtrace

## Logging-Steuerung

### Standard (Production)
```bash
# Minimales Logging (Standard für Production)
# Keine Health-Check-Logs
# Nur kritische Meldungen wie Page-Reloads
```

### Debug-Modus aktivieren (Browser Console)
```javascript
// Alle Performance-Logs aktivieren
localStorage.setItem('debug_cable_performance', 'true')
location.reload()

// Alle Logs komplett deaktivieren
localStorage.setItem('cable_no_logging', 'true')
location.reload()

// Zurücksetzen
localStorage.removeItem('debug_cable_performance')
localStorage.removeItem('cable_no_logging')
location.reload()
```

### Rails-seitiges Debug-Logging
```bash
# In production-bc-wedel.rb oder via ENV
export RAILS_LOG_LEVEL=debug

# Dann Deployment:
rake "scenario:deploy[carambus_bcw]"
```

## Erwartete Log-Reduktion

### Vorher (Production-Log)
```
[2026-03-21 13:34:32] Started GET "/locations/1?locale=de&sb_state=table_scores" for 127.0.0.1
[2026-03-21 13:34:32] Processing by LocationsController#show...
[2026-03-21 13:34:32] params[:table_id] = 
[2026-03-21 13:34:32] params[:sb_state] = table_scores
[2026-03-21 13:34:32] Current.user = scoreboard@carambus.de
[2026-03-21 13:34:32] [Scoreboard] 🎯 Table set from params...
[2026-03-21 13:34:32] Completed 200 OK in 45ms
... alle 30 Sekunden ...
```

### Nachher (Production-Log)
```
[2026-03-21 13:34:32] Started GET "/locations/1?locale=de&sb_state=table_scores" for 127.0.0.1
[2026-03-21 13:34:32] Processing by LocationsController#show...
[2026-03-21 13:34:32] Completed 200 OK in 45ms
... alle 30 Sekunden ...
```

**Reduktion**: ~80% weniger Log-Zeilen pro Request

### Browser Console (Standard)
```
// Nur beim tatsächlichen Monitor-Wakeup:
🔄 Monitor wake-up: Reloading page for fresh data...
```

### Browser Console (mit PERF_LOGGING)
```
🏥 Location Channel health monitor started for location 1
🏢 Location Channel connected for location 1
💓 Heartbeat started (every 60s)
🏥 Location Channel health check: {connectionState: "open", ...}
⚠️ Location Channel connection not open, state: connecting
🔄 Triggering reconnection, reason: connection_not_open
🔄 Monitor wake-up: Reloading page for fresh data...
```

## Health-Check-Konfiguration

Die Health-Checks sind konfigurierbar in beiden Channel-Dateien:

```javascript
// location_channel.js & table_monitor_channel.js
class HealthMonitor {
  constructor(subscription, locationId) {
    this.healthCheckFrequency = 30000  // 30 Sekunden (anpassbar)
    this.maxSilenceTime = 120000       // 2 Minuten ohne Messages (anpassbar)
    this.reconnectDelay = 5000         // 5 Sekunden bis Reload (anpassbar)
    this.forceReloadDelay = 10000      // 10 Sekunden bei failed reconnect
  }
}
```

### Empfohlene Werte für verschiedene Szenarien

#### Monitor selten eingeschaltet (aktuell)
```javascript
healthCheckFrequency: 30000   // 30s - gut für Monitor-Wakeup
maxSilenceTime: 120000        // 2min - toleriert längere Standby-Zeiten
reconnectDelay: 5000          // 5s - schneller Reload beim Aufwachen
```

#### Monitor häufig eingeschaltet
```javascript
healthCheckFrequency: 60000   // 60s - weniger frequent
maxSilenceTime: 180000        // 3min - toleranter
reconnectDelay: 10000         // 10s - mehr Zeit für Reconnect
```

#### Debugging/Testing
```javascript
healthCheckFrequency: 10000   // 10s - häufige Checks
maxSilenceTime: 30000         // 30s - schnelle Reaktion
reconnectDelay: 2000          // 2s - sofortiger Reload
```

## Testing der Änderungen

### 1. Deployment
```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
git pull

cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
rake "scenario:deploy[carambus_bcw]"
```

### 2. Log-Monitoring
```bash
# Production-Log beobachten
tail -f ~/carambus_bcw/current/log/production.log | grep "Started GET"

# Oder mit Timestamps
tail -f ~/carambus_bcw/current/log/production.log | grep -E "Started GET|Completed"
```

### 3. Browser Console
1. Monitor einschalten
2. F12 → Console öffnen
3. Warten auf Health-Check (30s)
4. **Erwartung**: Nur "Monitor wake-up: Reloading page..." beim ersten Mal
5. Danach: Keine Logs mehr (außer bei PERF_LOGGING)

### 4. Funktionalität testen
1. Monitor ausschalten
2. Im Backend: Scores ändern
3. Monitor einschalten
4. **Erwartung**: Seite lädt automatisch neu → aktuelle Scores sichtbar

## Weitere Optimierungen (optional)

### Option 1: Intervall verlängern
Falls 30s zu häufig sind:

```javascript
// in location_channel.js & table_monitor_channel.js
this.healthCheckFrequency = 60000 // 60s statt 30s
```

### Option 2: Smart Wake-Detection
Nur prüfen wenn Page tatsächlich hidden→visible wechselt:

```javascript
// Bereits implementiert via visibilitychange Event
// Keine Änderung nötig
```

### Option 3: Server-Side Health-Check-Logging reduzieren
Falls ActionCable-Server-Logs zu viel sind:

```ruby
# config/environments/production-bc-wedel.rb
config.action_cable.log_level = :error  # statt :info
```

## Rollback (falls Probleme)

Falls die Änderungen Probleme verursachen:

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
git checkout HEAD~1 app/javascript/channels/location_channel.js
git checkout HEAD~1 app/javascript/channels/table_monitor_channel.js

# Re-deploy
rake "scenario:deploy[carambus_bcw]"
```

## Related Documentation
- [LOGGING_REDUCTION.md](./LOGGING_REDUCTION.md) - Vorherige Logging-Optimierungen
