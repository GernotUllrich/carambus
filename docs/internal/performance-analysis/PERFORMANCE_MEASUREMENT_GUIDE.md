# Performance Measurement Guide - WebSocket Broadcast Latency

**Datum**: 2025-11-21  
**Problem**: 1.5 Sekunden Delay zwischen Server Broadcast und Raspi 3 Update

---

## Implementiertes Measurement System

### Gemessene Metriken

Das System misst den **kompletten Pfad** von Server-Broadcast bis Client-DOM-Update:

```
┌──────────────────────────────────────────────────────────────────┐
│                           SERVER                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Job Start ──┐                                                   │
│              │                                                    │
│              ├─> Reload/Cache Clear (gemessen)                   │
│              │                                                    │
│              ├─> Render HTML (gemessen)                          │
│              │   - table_scores: X ms                            │
│              │   - teaser: Y ms                                  │
│              │   - scoreboard: Z ms                              │
│              │                                                    │
│              ├─> Broadcast (gemessen)                            │
│              │   - Redis Pub/Sub                                 │
│              │   - ActionCable                                   │
│              │                                                    │
│              └─> Job End                                         │
│                  Total: XXX ms                                   │
│                  Timestamp: 1732191234567 (ms since epoch)       │
└───────────────────────────────┬──────────────────────────────────┘
                                │
                                │ Network (gemessen)
                                │
┌───────────────────────────────▼──────────────────────────────────┐
│                          CLIENT (Raspi 3)                         │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Receive ──┐                                                     │
│            │ Network Latency = receive_time - broadcast_timestamp│
│            │                                                      │
│            ├─> CableReady.perform (gemessen)                     │
│            │   - DOM Manipulation                                │
│            │   - Stimulus reconnect                              │
│            │                                                      │
│            └─> DOM Update Complete                               │
│                Total Latency = dom_complete - broadcast_timestamp│
└──────────────────────────────────────────────────────────────────┘
```

---

## Server-Side Measurements

### TableMonitorJob Timing

**Automatisch geloggt** in `log/production.log`:

```ruby
📡 ========== TableMonitorJob START ==========
📡 TableMonitor ID: 50000001
📡 Operation Type: score_update
📡 Broadcast Timestamp: 1732191234567
📡 Render time: 45.23ms
📡 HTML size: 12456 bytes
📡 Broadcast time: 3.45ms
📡 Total job time: 52.68ms
📡 ========== TableMonitorJob END ==========
```

**Metriken**:
- **Render time**: Zeit für `ApplicationController.render(partial: ...)`
- **Broadcast time**: Zeit für `cable_ready.broadcast` (Redis Pub/Sub)
- **Total job time**: Gesamtzeit von Job Start bis Ende
- **Broadcast Timestamp**: Milliseconds since epoch (für Network Latency Berechnung)

---

## Client-Side Measurements

### Performance Logging

**Standard (immer aktiv)**: Kompakte Performance Summary

```javascript
⚡ Performance [#full_screen_table_monitor_50000001]: {
  network: "125ms",    // Netzwerk-Latenz (Server → Client)
  dom: "1234ms",       // DOM-Update Zeit (CableReady.perform)
  total: "1359ms"      // Gesamtzeit (Server Broadcast → DOM fertig)
}
```

**Debug Mode (optional)**: Detaillierte Logs

```javascript
// Aktivieren:
localStorage.setItem('debug_cable_performance', 'true')
window.location.reload()

// Deaktivieren:
localStorage.removeItem('debug_cable_performance')
window.location.reload()
```

**Debug Mode Ausgabe**:

```javascript
🔌 TableMonitor Channel connected
🏥 Health check: { connectionState: "open", timeSinceLastMessage: "15s" }
✅ Connection healthy
📥 TableMonitor Channel received: {
  timestamp: "2024-11-21T13:45:34.567Z",
  hasCableReady: true,
  operationCount: 1,
  type: "broadcast",
  broadcastTimestamp: 1732191234567,
  networkLatency: "125ms"
}
📥 CableReady operation #1: {
  type: "innerHTML",
  selector: "#full_screen_table_monitor_50000001",
  htmlSize: "12456 chars",
  selectorExists: true
}
⚡ Performance [#full_screen_table_monitor_50000001]: {
  network: "125ms",
  dom: "1234ms",
  total: "1359ms"
}
```

---

## Bottleneck Identifikation

### Typische Werte (Richtwerte)

**Server (Pi4)**:
- Reload/Cache: < 5ms
- Render (Scoreboard): 20-50ms
- Render (table_scores): 30-80ms
- Broadcast: 1-5ms
- **Total Server**: 30-140ms ✅

**Network (WiFi)**:
- LAN: 1-10ms
- WiFi (gut): 10-50ms
- WiFi (schlecht): 50-200ms
- **Target**: < 100ms ✅

**Client (Raspi 3)**:
- Receive overhead: 1-5ms
- CableReady.perform:
  - Teaser: 50-200ms
  - table_scores: 200-500ms
  - Scoreboard: **800-2000ms** ⚠️ **BOTTLENECK**

### Problem auf Raspi 3

**DOM Manipulation ist langsam** wegen:
1. **innerHTML replacement** von großem HTML (12+ KB)
2. **Stimulus Controller disconnect/reconnect**
3. **Browser Reflow/Repaint**
4. **Langsame CPU** (1.2 GHz Quad-Core)

---

## Analyse-Workflow

### Step 1: Server Logs prüfen

```bash
# Auf Production Server
tail -f /var/www/carambus_bcw/current/log/production.log | grep "📡"

# Erwartete Ausgabe bei Score-Änderung:
📡 ========== TableMonitorJob START ==========
📡 TableMonitor ID: 50000001
📡 Operation Type: 
📡 Broadcast Timestamp: 1732191234567
📡 Render time: 45.23ms          ← Server Render
📡 HTML size: 12456 bytes
📡 Broadcast time: 3.45ms        ← Redis/ActionCable
📡 Total job time: 52.68ms       ← Total Server
📡 ========== TableMonitorJob END ==========
```

**Analyse**:
- Render time > 100ms? → Template Optimization nötig
- Broadcast time > 10ms? → Redis Problem
- Total > 200ms? → Server überlastet

### Step 2: Client Console prüfen

**Browser auf Raspi öffnen** → F12 → Console

```javascript
// Warte auf Score-Änderung, dann:
⚡ Performance [#full_screen_table_monitor_50000001]: {
  network: "125ms",     ← Netzwerk (Server → Client)
  dom: "1234ms",        ← DOM Update (BOTTLENECK!)
  total: "1359ms"       ← Gesamtlatenz
}
```

**Analyse**:
- network > 200ms? → WiFi/Netzwerk Problem
- dom > 1000ms? → **Client-Performance Problem** (Raspi 3)
- total = network + dom

### Step 3: Bottleneck identifizieren

| Metrik | Wert | Status | Problem |
|--------|------|--------|---------|
| Server Render | 45ms | ✅ OK | - |
| Server Broadcast | 3ms | ✅ OK | - |
| Network Latency | 125ms | ⚠️ OK | WiFi könnte besser sein |
| Client DOM Update | **1234ms** | ❌ SLOW | **Hauptproblem** |
| **Total** | **1359ms** | ❌ SLOW | Wegen Client DOM |

**Conclusion**: Client DOM Manipulation ist der Bottleneck!

---

## Optimierungsstrategien

### Option 1: JSON Broadcasting (bereits implementiert)

Siehe: `docs/JSON_BROADCASTING_FINAL_SUCCESS.md`

**Vorher** (innerHTML):
- Server rendered HTML: 12 KB
- Client DOM Update: 1200ms

**Nachher** (JSON):
- Server sendet JSON: 200 bytes
- Client textContent: 50ms

**Speedup**: 24x schneller! ✅

**Aber**: Nur für Score-Updates. Full Scoreboard braucht innerHTML.

### Option 2: Partial Updates

Statt komplettes Scoreboard:

```ruby
# Nur Score-Feld updaten
cable_ready["table-monitor-stream"].inner_html(
  selector: "#score_playera_#{table_monitor.id}",
  html: "<span>#{score}</span>"  # Klein!
)
```

**Problem**: Komplex, viele Selektoren, fehleranfällig

### Option 3: Hardware Upgrade

- Raspi 3: 1.2 GHz Quad-Core ARM Cortex-A53
- Raspi 4: 1.5 GHz Quad-Core ARM Cortex-A72 (**30% schneller**)
- Raspi 5: 2.4 GHz Quad-Core ARM Cortex-A76 (**2x schneller**)

**DOM Update auf Pi4**: ~600-800ms (50% schneller)  
**DOM Update auf Pi5**: ~300-400ms (75% schneller)

### Option 4: Optimized HTML/CSS

- Weniger DOM-Nodes (Simplify Template)
- Weniger CSS Classes
- Kein JavaScript in Template
- Preload Critical CSS

**Expected Gain**: 10-20% schneller

### Option 5: Browser Tuning

Chromium Flags für Performance:

```bash
chromium-browser \
  --disable-gpu \
  --disable-software-rasterizer \
  --disable-dev-shm-usage \
  --disable-accelerated-2d-canvas \
  --num-raster-threads=4
```

**Expected Gain**: 5-15% schneller

---

## Monitoring Setup

### Permanent Performance Logging

**Für Production Monitoring** (ohne Debug-Spam):

```javascript
// Performance Summary ist IMMER aktiv
⚡ Performance [selector]: { network: "...", dom: "...", total: "..." }

// Debug Logging nur bei Bedarf
localStorage.setItem('debug_cable_performance', 'true')
```

### Server Metrics Collection

**Optional**: Parse Logs für Grafana/Prometheus

```ruby
# config/initializers/performance_logging.rb
ActiveSupport::Notifications.subscribe('table_monitor_job.broadcast') do |name, start, finish, id, payload|
  duration = ((finish - start) * 1000).round(2)
  
  StatsD.timing('table_monitor.job.duration', duration)
  StatsD.timing('table_monitor.job.render', payload[:render_time])
  StatsD.timing('table_monitor.job.broadcast', payload[:broadcast_time])
end
```

---

## Troubleshooting

### Problem: Keine Performance Logs im Client

**Check**:
```javascript
// In Browser Console
console.log("Debug enabled:", localStorage.getItem('debug_cable_performance'))
console.log("Performance logging:", typeof PERF_LOGGING !== 'undefined')
```

**Fix**:
```bash
# JavaScript neu kompilieren
cd /var/www/carambus_bcw/current
yarn build
sudo systemctl restart carambus_bcw
```

### Problem: Kein broadcast_timestamp in Operations

**Check Server Logs**:
```bash
grep "Broadcast Timestamp" log/production.log | tail -1
```

**Fix**: TableMonitorJob.rb deployed?
```bash
git log --oneline -1 app/jobs/table_monitor_job.rb
```

### Problem: Network Latency > 500ms

**Check WiFi**:
```bash
# Auf Raspi
ping -c 10 carambus.bcw.de

# Erwartung: < 50ms average
```

**Fix**:
- Ethernet statt WiFi verwenden
- WiFi Access Point näher platzieren
- 5GHz statt 2.4GHz

### Problem: Server Render > 200ms

**Check Database**:
```bash
# Slow queries?
grep "ActiveRecord" log/production.log | grep -E "[0-9]{3,}ms"
```

**Fix**:
- Database Indexes hinzufügen
- N+1 Queries eliminieren
- Template Caching

---

## Expected Results

### Baseline (Raspi 3, vor Optimierung)

```
Server:    50ms
Network:   120ms
DOM:       1400ms    ← BOTTLENECK
─────────────────
Total:     1570ms
```

### Mit JSON Broadcasting (Score Updates)

```
Server:    15ms     (weniger zu rendern)
Network:   10ms     (kleinere Payload)
DOM:       50ms     (textContent statt innerHTML)
─────────────────
Total:     75ms     ✅ 20x schneller!
```

### Mit Hardware Upgrade (Raspi 4)

```
Server:    50ms
Network:   120ms
DOM:       700ms    (50% schneller CPU)
─────────────────
Total:     870ms    ✅ 45% schneller
```

### Mit Hardware + Optimierung (Raspi 4 + JSON)

```
Server:    15ms
Network:   10ms
DOM:       25ms     (JSON + schnellere CPU)
─────────────────
Total:     50ms     ✅ 30x schneller!
```

---

## Recommendations

### Immediate (bereits implementiert)

1. ✅ **Performance Measurement System**
   - Server: Timestamps + Timing
   - Client: Network + DOM Timing
   - Conditional Logging

2. ⏳ **JSON Broadcasting für Score-Updates**
   - Siehe: `JSON_BROADCASTING_FINAL_SUCCESS.md`
   - Bereits implementiert, nur aktivieren

### Short Term

3. **WiFi → Ethernet** auf kritischen Raspis
   - Reduziert Network Latency: 120ms → 10ms
   - Stabiler, keine Dropouts

4. **Browser Tuning** für Raspi 3
   - Chromium Flags optimieren
   - Expected: 10-15% schneller

### Medium Term

5. **Template Optimization**
   - Weniger DOM Nodes
   - Simplified HTML Structure
   - Expected: 10-20% schneller

6. **Partial Updates** für häufige Änderungen
   - Nur Score-Bereich statt ganzes Scoreboard
   - Complex, aber effektiv

### Long Term

7. **Hardware Upgrade** zu Raspi 4/5
   - Pi4: 50% schneller
   - Pi5: 75% schneller
   - Kostet, aber beste Lösung

---

## Usage Examples

### Enable Debug Logging (temporary)

```javascript
// In Browser Console auf Raspi
localStorage.setItem('debug_cable_performance', 'true')
window.location.reload()

// Nach Testing
localStorage.removeItem('debug_cable_performance')
window.location.reload()
```

### Monitor Performance (production)

```bash
# Server Logs
ssh user@server
tail -f /var/www/carambus_bcw/current/log/production.log | grep "📡"

# Dann auf Raspi Score ändern und Werte notieren
```

### Analyze Bottleneck

```javascript
// Browser Console (während Score-Änderung)
⚡ Performance [#full_screen_table_monitor_50000001]: {
  network: "125ms",  // OK
  dom: "1234ms",     // PROBLEM!
  total: "1359ms"
}

// Conclusion: DOM ist Bottleneck → Hardware oder JSON Broadcasting
```

---

**Status**: ✅ System implementiert, bereit für Production Testing  
**Nächster Schritt**: Measurements auf Raspi 3 durchführen und dokumentieren


