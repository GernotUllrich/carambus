# TV Display Freeze Fix - table_scores Page (2025-02-10)

## ⚠️ UPDATE (2025-02-10 Evening)

**Diese JavaScript-Lösung funktioniert NICHT für TV-Standby!** Der Browser-Prozess wird vom OS eingefroren und kann keine JavaScript-Events ausführen.

**→ Siehe stattdessen:** [`BROWSER_WATCHDOG_SOLUTION.md`](BROWSER_WATCHDOG_SOLUTION.md) für die **funktionierende OS-Level Lösung**.

Die hier beschriebene JavaScript-Lösung bleibt im Code als "Defense in Depth" für Fälle wo der Browser responsive ist, funktioniert aber **nicht** für echten TV-Standby.

---

## 🚨 Problem

Die `table_scores` Seite auf dem Samsung TV Browser friert ein, wenn der TV aus dem Standby aufgewacht wird. Die Seite zeigt oft ein eingefrorenes Bild, wenn der TV eingeschaltet wird.

### Symptome

- ✅ Server läuft normal (Raspberry Pi 5, 24/7)
- ✅ Andere Browser/Geräte funktionieren normal
- ❌ Samsung TV Browser zeigt eingefrorenes Bild nach Standby
- ❌ WebSocket-Verbindung ist tot, aber Seite merkt es nicht
- ❌ Keine automatische Aktualisierung beim TV-Aufwachen

### Root Cause

**TV Standby Mode:**
- Samsung TV Browser geht in den Standby, wenn TV ausgeschaltet wird
- WebSocket-Verbindungen (ActionCable) werden unterbrochen
- Browser-Tab bleibt "im Hintergrund" für Stunden
- Beim TV-Einschalten: Browser wacht auf, aber WebSocket ist tot
- Seite zeigt veraltete Daten, keine Live-Updates mehr

**Warum existierende Health Checks nicht ausreichten:**
1. Health Checks liefen nur alle 30 Sekunden
2. Page Visibility API wurde nicht für location_channel.js genutzt
3. Kein dedizierter Wake-from-Sleep Detection Mechanismus
4. TV Standby-Zeit (Stunden) überschritt alle Timeouts deutlich

## ✅ Solution

### 1. Neuer Stimulus Controller für table_scores

**`app/javascript/controllers/table_scores_monitor_controller.js`**

Spezialisierter Controller für TV-Display-Seiten:

- **Page Visibility API Detection:**
  - Erkennt wenn TV aus Standby aufwacht (`visibilitychange` event)
  - Misst wie lange Seite hidden war
  - Force Reload wenn Threshold überschritten (Standard: 5 Minuten)

- **Heartbeat Check:**
  - Zusätzlicher periodischer Check (alle 30 Sekunden)
  - Erkennt "stuck" Zustände auch wenn Page visible
  - Force Reload wenn keine Activity für zu lange

- **Konfigurierbar:**
  ```html
  data-table-scores-monitor-sleep-threshold-value="300000"  <!-- 5 Minuten -->
  data-table-scores-monitor-debug-value="false"             <!-- Debug Logging -->
  ```

### 2. Erweiterte ActionCable Health Monitoring

**`app/javascript/channels/location_channel.js`**

Analog zu `table_monitor_channel.js`, jetzt auch für `location_channel`:

- **`LocationChannelHealthMonitor` Klasse:**
  - Periodische Health Checks (alle 30 Sekunden)
  - Page Visibility Change Handler
  - Automatic Reconnection mit Fallback zu Page Reload
  - Status Indicator Updates

- **Client-Server Heartbeat:**
  - Client sendet alle 60 Sekunden Heartbeat an Server
  - Server antwortet mit `heartbeat_ack`
  - Hält Connection alive und bestätigt Bidirektionalität

- **Disconnect Protection:**
  - Zählt Connection Attempts
  - Force Reload nach 5+ Disconnects
  - Verhindert endlose Reconnect-Loops

### 3. View Integration

**`app/views/locations/scoreboard_table_scores.html.erb`**

```erb
<div data-controller="table-scores-monitor" 
     data-table-scores-monitor-sleep-threshold-value="300000"
     data-table-scores-monitor-debug-value="false">
  
  <!-- Existing content -->
  
</div>
```

## 📁 Geänderte/Neue Dateien

### Neue Dateien

1. **`app/javascript/controllers/table_scores_monitor_controller.js`**
   - TV Wake-from-Sleep Detection
   - Page Reload Mechanismus
   - Heartbeat Monitoring

### Geänderte Dateien

1. **`app/views/locations/scoreboard_table_scores.html.erb`**
   - Stimulus Controller Integration
   - Wrapper `<div>` mit data-attributes

2. **`app/javascript/channels/location_channel.js`**
   - `LocationChannelHealthMonitor` Klasse hinzugefügt
   - Page Visibility Change Handler
   - Client Heartbeat Mechanismus
   - Connection Attempt Counter

## 🧪 Testing

### Test Setup

1. **Samsung TV Browser:** Öffne `table_scores` Seite
2. **TV ausschalten:** Warte 5+ Minuten
3. **TV einschalten:** Beobachte Verhalten

### Erwartetes Verhalten

#### ✅ VORHER (Problematisch):
1. TV ausschalten → Seite friert ein
2. TV einschalten → **Eingefrorenes Bild** (z.B. Spiel von vor Stunden)
3. WebSocket tot, keine Updates
4. **Manueller Reload nötig**

#### ✅ NACHHER (Fixed):
1. TV ausschalten → Seite friert ein (normal)
2. TV einschalten → **Automatischer Reload nach 1 Sekunde**
3. Seite zeigt aktuellen Stand
4. WebSocket aktiv, Live-Updates funktionieren
5. **Kein manueller Reload nötig**

### Debug Mode

Aktiviere Debug Logging für Diagnose:

```erb
data-table-scores-monitor-debug-value="true"
```

Dann in Browser Console:

```javascript
// Stimulus Controller Logs
[TableScoresMonitor] 🖥️ Table Scores Monitor connected
[TableScoresMonitor] 😴 Page hidden (TV standby?)
[TableScoresMonitor] 👁️ Page visible (TV wake?)
[TableScoresMonitor] 🔄 Sleep threshold exceeded, forcing reload...

// Location Channel Logs
🏥 Location Channel health check: { connectionState: "open", ... }
💓 Heartbeat sent to server
💓 Heartbeat acknowledged by server
```

## 🔧 Configuration Options

### Sleep Threshold

Wie lange Seite hidden sein darf bevor Force Reload:

```erb
<!-- 5 Minuten (Standard) -->
data-table-scores-monitor-sleep-threshold-value="300000"

<!-- 2 Minuten (aggressiver) -->
data-table-scores-monitor-sleep-threshold-value="120000"

<!-- 10 Minuten (toleranter) -->
data-table-scores-monitor-sleep-threshold-value="600000"
```

**Empfehlung:** 5 Minuten ist ein guter Kompromiss
- Kurze Standby-Zeiten (< 5 min) vermeiden unnötige Reloads
- Lange Standby-Zeiten (> 5 min) triggern zuverlässig Reload

### Health Check Frequency

In `location_channel.js`:

```javascript
this.healthCheckFrequency = 30000 // 30 Sekunden (Standard)
this.maxSilenceTime = 120000      // 2 Minuten ohne Message
```

## 🎯 Additional Benefits

### 1. Robustere WebSocket-Verbindung

- Erkennt Connection-Probleme schneller
- Automatische Wiederverbindung
- Fallback zu Page Reload wenn nötig

### 2. Bessere TV Browser Kompatibilität

- Samsung TV Browser
- LG TV Browser
- Andere WebOS/Tizen Browser
- Raspberry Pi Chromium im Kiosk Mode

### 3. Generalisierbar

Der `table-scores-monitor` Controller kann auch für andere Display-Seiten verwendet werden:

- `scoreboard_tournament_scores.html.erb`
- `scoreboard_big_table_scores.html.erb`
- Andere "Display Only" Seiten

## 📊 Architecture Notes

### Why Both Stimulus Controller AND Channel Health Monitor?

**Stimulus Controller (`table_scores_monitor_controller.js`):**
- **Purpose:** Page-level wake-from-sleep detection
- **Scope:** Specific to table_scores view
- **Trigger:** Page Visibility API
- **Action:** Force full page reload

**Channel Health Monitor (`location_channel.js`):**
- **Purpose:** WebSocket connection health
- **Scope:** All pages using LocationChannel
- **Trigger:** Connection state, message timeouts
- **Action:** Reconnect or reload

**Together:**
- **Defense in Depth:** Multiple layers of protection
- **Fast Recovery:** Whichever detects problem first triggers fix
- **Complementary:** Controller handles sleep, Monitor handles connection issues

### Why Not Just Rely on ActionCable's Built-in Reconnection?

ActionCable's built-in reconnection is good, but:

1. **TV Standby is Special:** Connection is "open" on client side, but dead server-side
2. **Long Sleep Times:** Hours of sleep exceed ActionCable's assumptions
3. **Stale State:** Even after reconnect, DOM might show old data
4. **User Experience:** Full reload ensures fresh state, no confusion

## 🔗 Related Documentation

- **`BROWSER_WATCHDOG_SOLUTION.md`** - **FUNKTIONIERENDE LÖSUNG für TV-Standby** ⭐
- `BLANK_TABLE_SCORES_BUG_FIX.md` - Previous table_scores fix (variable mismatch)
- `WEBSOCKET_LIFECYCLE_ANALYSIS.md` - ActionCable architecture
- `SCOREBOARD_ARCHITECTURE.md` - Server-driven architecture

## ✅ Result

⚠️ **Diese Lösung funktioniert NICHT für TV-Standby!**

**Warum nicht:**
- TV Standby friert Browser-Prozess komplett ein
- JavaScript kann nicht ausgeführt werden
- Page Visibility API Events werden nicht gefeuert
- Browser bleibt eingefroren bis Prozess neu startet

**Funktionierende Lösung:**
→ [`BROWSER_WATCHDOG_SOLUTION.md`](BROWSER_WATCHDOG_SOLUTION.md) - OS-Level Watchdog mit systemd Timer

**Was diese Lösung trotzdem leistet:**
- ✅ Erkennt kurze Inaktivitäts-Phasen (< 5 Minuten)
- ✅ Reload bei normalem Browser-Sleep (nicht TV-Standby)
- ✅ "Defense in Depth" Layer
- ✅ Schnelle Recovery wenn Browser responsive ist

## 🚀 Deployment

```bash
# In carambus_master/
git add .
git commit -m "Fix: TV display freeze on table_scores after standby"
git push

# User führt aus (scenario checkout):
cd /Users/gullrich/DEV/carambus/carambus_bcw/
git pull
rake "scenario:deploy[carambus_bcw]"
```

## 📝 Future Improvements

### Optional Enhancements

1. **Visual "Reloading" Indicator:**
   - Zeige kurze Meldung "Aktualisiere..." (bereits implementiert in `showReloadMessage()`)
   - Kann weiter verbessert werden (Animation, Branding, etc.)

2. **Configurable via Admin Panel:**
   - Sleep Threshold als Location Setting
   - Enable/Disable Auto-Reload per Display

3. **Metrics/Logging:**
   - Zähle wie oft Reloads triggered werden
   - Log Wake-from-Sleep Events für Monitoring

4. **Smart Reload:**
   - Prüfe ob Daten sich geändert haben (via HTTP HEAD request)
   - Nur reload wenn nötig

### Known Limitations

1. **1 Sekunde "Black Screen":**
   - Während Page Reload kurz schwarzer Bildschirm
   - Akzeptabel, da nur beim TV-Aufwachen
   - Alternative: AJAX-basierter Content Refresh (komplexer)

2. **Network Dependency:**
   - Reload funktioniert nur wenn Netzwerk verfügbar
   - Kein Problem im LAN-Setup (Raspberry Pi lokal)
   - Bei WAN: Eventuell längere Reload-Zeiten

## 🎓 Lessons Learned

1. **TV Browsers are Special:**
   - Aggressive Power Management
   - Long Standby Times (hours)
   - Standard WebSocket reconnection nicht ausreichend

2. **Page Visibility API is Essential:**
   - Zuverlässige Detection von Wake-from-Sleep
   - Besser als Timer-basierte Heuristiken

3. **Full Page Reload is OK:**
   - Einfachste und zuverlässigste Lösung
   - User Experience: 1 Sekunde Reload vs. veraltete Daten

4. **Multiple Layers of Protection:**
   - Stimulus Controller + Channel Health Monitor
   - Redundante Mechanismen erhöhen Robustheit
