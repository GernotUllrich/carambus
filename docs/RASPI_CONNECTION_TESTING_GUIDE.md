# Raspi 3 Connection Testing Guide

**Zweck**: Systematisches Testing des WebSocket Health Monitoring Systems  
**Datum**: 2025-11-21

---

## Voraussetzungen

### Server (carambus_bcw)

1. **Code deployed mit Health Monitoring**:
   ```bash
   cd /var/www/carambus_bcw/current
   git pull origin master
   bundle install
   yarn install
   yarn build && yarn build:css
   rails assets:precompile
   sudo systemctl restart carambus_bcw
   ```

2. **Force Reconnect aktiviert**:
   ```bash
   # In /etc/systemd/system/carambus_bcw.service
   Environment="FORCE_RECONNECT_ON_BOOT=true"
   
   sudo systemctl daemon-reload
   sudo systemctl restart carambus_bcw
   ```

3. **Logs beobachten**:
   ```bash
   tail -f /var/www/carambus_bcw/current/log/production.log
   ```

### Raspi 3 Kiosk

1. **Browser öffnen auf Scoreboard**:
   ```
   http://carambus.bcw.de/table_monitors/50000001?fullscreen=true&sb_state=fullscreen
   ```

2. **Developer Console öffnen** (für Testing):
   - F12 oder Ctrl+Shift+I
   - Console Tab

---

## Test 1: Normaler Betrieb

### Ziel
Verifizieren dass Health Monitoring ohne Probleme läuft.

### Steps

1. **Scoreboard öffnen**
   - Browser auf Raspi öffnet Scoreboard URL
   - Warten bis Seite vollständig geladen

2. **Status Indicator prüfen**
   - Oben rechts: Grüner Punkt sollte sichtbar sein
   - Punkt sollte langsam pulsieren (2s Intervall)

3. **Console Logs prüfen**
   ```javascript
   // Sollte erscheinen:
   🔌 TableMonitor Channel initialized
   🔌 TableMonitor Channel connected
   🔌 Consumer state: open
   🏥 Health monitor started
   ```

4. **Health Checks beobachten** (30 Sekunden warten)
   ```javascript
   // Alle 30 Sekunden sollte erscheinen:
   🏥 Health check: { connectionState: "open", timeSinceLastMessage: "15s" }
   ✅ Connection healthy
   ```

5. **Score-Änderungen testen**
   - Auf Scoreboard klicken (Score erhöhen)
   - Änderung sollte sofort erscheinen
   - Auf anderem Browser: Änderung sollte ankommen
   - Auf Raspi: Broadcasts von anderen sollten ankommen

### Erwartetes Ergebnis

✅ Status-Indicator bleibt grün  
✅ Health Checks alle 30s: "Connection healthy"  
✅ Score-Änderungen bidirektional funktionsfähig  
✅ Keine Errors in Console  
✅ Keine Reconnects/Reloads

---

## Test 2: Server Restart

### Ziel
Verifizieren dass Raspi nach Server-Restart automatisch reconnected.

### Steps

1. **Scoreboard läuft normal** (siehe Test 1)

2. **Server restarten**
   ```bash
   # Auf Server
   sudo systemctl restart carambus_bcw
   ```

3. **Server Logs beobachten**
   ```bash
   tail -f /var/www/carambus_bcw/current/log/production.log
   
   # Nach ~15 Sekunden sollte erscheinen:
   🔄 Sending force reconnect to all clients (server restarted)
   ✅ Force reconnect broadcast sent successfully
   ```

4. **Raspi Browser beobachten**
   
   **Console**:
   ```javascript
   // Sollte erscheinen:
   🔄 Server requested forced reconnect: server_restarted
   // (Seite lädt neu nach 2 Sekunden)
   ```
   
   **Status Indicator**:
   - Kurz orange (reconnecting)
   - Dann grün (healthy)

5. **Nach Reload: Funktionalität prüfen**
   - Score-Änderungen funktionieren
   - Broadcasts kommen an
   - Health Checks laufen normal

### Erwartetes Ergebnis

✅ Force Reconnect Broadcast nach ~15s  
✅ Raspi lädt Seite automatisch neu  
✅ Nach Reload: Alles funktioniert normal  
✅ Keine manuellen Eingriffe nötig

### Fehlerfall

❌ **Kein Force Reconnect Broadcast**:
```bash
# Manuell triggern:
cd /var/www/carambus_bcw/current
bundle exec rake cable:force_reconnect REASON="manual_after_restart"
```

---

## Test 3: Network Disconnect

### Ziel
Verifizieren dass Raspi bei Netzwerk-Unterbrechung automatisch reconnected.

### Steps

1. **Scoreboard läuft normal**

2. **WiFi am Raspi deaktivieren**
   ```bash
   # Auf Raspi (SSH oder lokal)
   sudo ifconfig wlan0 down
   
   # Oder: Router-seitig WiFi kurz aus/an
   ```

3. **Raspi Browser beobachten**
   
   **Sofort**:
   - Status Indicator wird rot
   - Console: "Connection not open"
   
   **Nach 30 Sekunden** (nächster Health Check):
   ```javascript
   ⚠️ Connection not open, state: closed
   🔄 Triggering reconnection, reason: connection_not_open
   ```

4. **WiFi wieder aktivieren**
   ```bash
   sudo ifconfig wlan0 up
   ```

5. **Reconnection beobachten**
   
   **Automatisch**:
   - Browser versucht Reconnect
   - Status Indicator: rot → orange → grün
   - Console: "Reconnection successful"
   
   **Falls Reconnect fehlschlägt nach 5s**:
   - Seite lädt automatisch neu
   - Console: "Reconnection failed, reloading page..."

### Erwartetes Ergebnis

✅ Status Indicator zeigt Problem (rot)  
✅ Automatischer Reconnect-Versuch  
✅ Bei Erfolg: Grün, weiter normal  
✅ Bei Misserfolg: Page Reload nach 5s  
✅ Keine manuellen Eingriffe nötig

---

## Test 4: Long Running Session

### Ziel
Verifizieren dass Connection über längere Zeit stabil bleibt.

### Steps

1. **Scoreboard öffnen und laufen lassen**
   - Minimum: 2 Stunden
   - Besser: 24 Stunden

2. **Periodisch prüfen** (alle 30 Minuten):
   - Status Indicator noch grün?
   - Health Checks laufen?
   - Score-Änderungen funktionieren?

3. **Server Logs prüfen**
   ```bash
   # Auf Server
   grep "TableMonitorChannel" log/production.log | tail -20
   
   # Sollten regelmäßig Heartbeats oder Messages sein
   ```

4. **Connection Stats prüfen**
   ```bash
   cd /var/www/carambus_bcw/current
   bundle exec rake cable:stats
   
   # Sollte zeigen:
   # Total connections: 1 (oder mehr)
   # Redis subscribers: 1 (oder mehr)
   # Keine WARNING über mismatch
   ```

### Erwartetes Ergebnis

✅ Connection bleibt grün über gesamte Zeit  
✅ Keine unerwarteten Reconnects/Reloads  
✅ Health Checks zeigen durchgehend "healthy"  
✅ Score-Updates funktionieren jederzeit  
✅ Kein Memory Leak (Server oder Client)

---

## Test 5: Message Timeout Simulation

### Ziel
Verifizieren dass stale Connections erkannt werden.

### Steps

1. **Scoreboard läuft normal**

2. **Server: Broadcasting stoppen** (simuliert)
   ```bash
   # Redis stoppen (VORSICHT: Nur für Test!)
   sudo systemctl stop redis
   ```

3. **Raspi Browser beobachten**
   
   **Nach 2 Minuten** (120 Sekunden ohne Message):
   ```javascript
   ⚠️ No messages received for 120 seconds
   🔄 Triggering reconnection, reason: message_timeout
   ```
   
   - Status Indicator wird orange
   - Reconnect-Versuch
   - Falls Redis noch down: Page Reload nach 5s

4. **Redis wieder starten**
   ```bash
   sudo systemctl start redis
   ```

5. **Nach Page Reload**
   - Connection wird neu aufgebaut
   - Status Indicator wird grün
   - Alles funktioniert normal

### Erwartetes Ergebnis

✅ Timeout wird nach 2 Minuten erkannt  
✅ Automatischer Reconnect-Versuch  
✅ Page Reload wenn nötig  
✅ Nach Redis-Restart: Normale Funktion

---

## Test 6: Tab Visibility Change

### Ziel
Verifizieren dass Raspi reconnected wenn Tab wieder aktiv wird.

### Steps

1. **Scoreboard läuft auf Raspi**

2. **Tab wechseln** oder **Browser minimieren**
   - Zu anderem Tab wechseln
   - Oder Browser minimieren
   - 5 Minuten warten

3. **Zurück zu Scoreboard Tab**
   - Tab wieder aktivieren
   
   **Console sollte zeigen**:
   ```javascript
   📱 Page became visible, checking health...
   🏥 Health check: { connectionState: "open", ... }
   ```

4. **Funktionalität prüfen**
   - Score-Änderungen funktionieren
   - Broadcasts kommen an

### Erwartetes Ergebnis

✅ Bei Tab-Aktivierung: Sofortiger Health Check  
✅ Falls Connection tot: Automatisches Reconnect  
✅ Score-Updates funktionieren sofort

---

## Debugging Commands

### Server-seitig

```bash
# Connection Statistics
cd /var/www/carambus_bcw/current
bundle exec rake cable:stats

# Force Reconnect (manuell)
bundle exec rake cable:force_reconnect REASON="manual_test"

# Disconnect stale connections
bundle exec rake cable:disconnect_stale THRESHOLD=300

# Logs filtern
tail -f log/production.log | grep -E "(ActionCable|TableMonitorChannel|force reconnect)"

# Redis prüfen
redis-cli
> PING
> PUBSUB NUMSUB table-monitor-stream
> exit
```

### Client-seitig (Browser Console)

```javascript
// Connection State
consumer.connection.getState()

// Last received timestamp
new Date(tableMonitorSubscription.lastReceived)

// Time since last message
Math.round((Date.now() - tableMonitorSubscription.lastReceived) / 1000) + " seconds"

// Manual reconnect
consumer.connection.reopen()

// Force reload
window.location.reload()

// Listen to status changes
window.addEventListener('connection-status-change', (e) => {
  console.log('Status:', e.detail.status, new Date())
})
```

---

## Troubleshooting

### Status bleibt rot, kein Reconnect

**Check**:
```bash
# 1. Server läuft?
sudo systemctl status carambus_bcw

# 2. Redis läuft?
sudo systemctl status redis
redis-cli ping

# 3. Nginx config OK?
sudo nginx -t
grep -A 10 "location /cable" /etc/nginx/sites-enabled/carambus*

# 4. Port 3000 erreichbar?
curl -i http://localhost:3000/cable/health
```

**Fix**:
```bash
sudo systemctl restart redis
sudo systemctl restart carambus_bcw
sudo systemctl reload nginx
```

### Häufige Reconnects (alle 30 Sekunden)

**Check** (Server Logs):
```bash
grep "Health check" log/production.log | tail -50
```

**Mögliche Ursachen**:
- Instabiles WiFi am Raspi
- Server überlastet (Timeout)
- Redis Performance-Problem

**Fix**:
- Ethernet statt WiFi verwenden
- Server Resources erhöhen
- Timeout erhöhen (in JS: `this.maxSilenceTime = 180000`)

### Force Reconnect funktioniert nicht

**Check**:
```bash
# Initializer geladen?
grep "force reconnect" log/production.log

# Environment Variable gesetzt?
systemctl show carambus_bcw | grep FORCE_RECONNECT
```

**Fix**:
```bash
# In /etc/systemd/system/carambus_bcw.service
Environment="FORCE_RECONNECT_ON_BOOT=true"

sudo systemctl daemon-reload
sudo systemctl restart carambus_bcw

# Oder manuell nach jedem Restart:
bundle exec rake cable:force_reconnect
```

---

## Success Criteria

✅ **Test 1 (Normal)**: 30 Minuten ohne Probleme  
✅ **Test 2 (Server Restart)**: Automatischer Reconnect innerhalb 20s  
✅ **Test 3 (Network)**: Automatisches Recovery innerhalb 60s  
✅ **Test 4 (Long Running)**: 24 Stunden stabil  
✅ **Test 5 (Timeout)**: Erkennung nach 2 Minuten  
✅ **Test 6 (Visibility)**: Sofortiger Check bei Tab-Wechsel

**Alle Tests bestanden** → Ready für Production auf allen Raspis!

---

## Rollout Plan

1. ✅ Testing auf einem Raspi 3 (BCW)
2. ⏳ 24h Monitoring
3. ⏳ Deployment auf alle Location Raspis
4. ⏳ 1 Woche Monitoring
5. ⏳ Dokumentation finalisieren

---

**Status**: ⏳ Bereit für Testing  
**Nächster Schritt**: Test 1-6 auf Raspi 3 durchführen

