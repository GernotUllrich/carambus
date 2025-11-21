# WebSocket Lifecycle Analysis - ActionCable, StimulusReflex & CableReady

**Datum**: 2025-11-21  
**Problem**: Unvollständige Synchronisierung zwischen Browsern, Cable Connections werden nicht korrekt wiederhergestellt

---

## Architektur-Übersicht

### Die drei Systeme

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENT (Browser)                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────┐         ┌──────────────────────────┐  │
│  │ Stimulus Controller │────────▶│  StimulusReflex          │  │
│  │ (table_monitor)     │         │  (stimulate() calls)     │  │
│  └─────────────────────┘         └──────────────────────────┘  │
│           │                                  │                   │
│           │ data-action                      │ WebSocket         │
│           ▼                                  ▼                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              ActionCable Consumer                        │   │
│  │              (consumer.js)                               │   │
│  └─────────────────────────────────────────────────────────┘   │
│           │                                  │                   │
│           └──────────────────┬───────────────┘                   │
│                              │                                   │
│                    WebSocket über /cable                         │
└──────────────────────────────┼───────────────────────────────────┘
                               │
                               │ persistent WebSocket
                               │
┌──────────────────────────────┼───────────────────────────────────┐
│                         SERVER (Rails)                            │
├──────────────────────────────┼───────────────────────────────────┤
│                              ▼                                    │
│  ┌────────────────────────────────────────────────────────┐     │
│  │         ApplicationCable::Connection                    │     │
│  │  - Verbindung authentifizieren                          │     │
│  │  - connection_token zuweisen                            │     │
│  │  - User identifizieren                                  │     │
│  └────────────────────────────────────────────────────────┘     │
│                              │                                    │
│                              ▼                                    │
│  ┌────────────────────────────────────────────────────────┐     │
│  │         TableMonitorChannel                             │     │
│  │  - subscribed: stream_from "table-monitor-stream"       │     │
│  │  - empfängt: alle broadcasts auf diesem Stream          │     │
│  └────────────────────────────────────────────────────────┘     │
│         │                                        ▲                │
│         │ Reflex                                 │ Broadcast      │
│         ▼                                        │                │
│  ┌────────────────────┐               ┌────────────────────┐    │
│  │ TableMonitorReflex │──save!──────▶│ TableMonitorJob     │    │
│  │ - add_n            │  callback     │ - render HTML       │    │
│  │ - next_step        │               │ - CableReady ops    │    │
│  │ - etc.             │               │ - broadcast         │    │
│  └────────────────────┘               └────────────────────┘    │
└───────────────────────────────────────────────────────────────────┘
```

---

## 1. ActionCable Connection Lifecycle

### Initial Connection

**Client-Seite** (`consumer.js`):
```javascript
import { createConsumer } from "@rails/actioncable"
const consumer = createConsumer("/cable")
```

**Was passiert:**
1. Browser öffnet WebSocket zu `ws://host:port/cable`
2. Rails etabliert persistente Verbindung
3. Server ruft `ApplicationCable::Connection#connect` auf
4. User wird authentifiziert, `connection_token` wird zugewiesen
5. Verbindung bleibt dauerhaft offen (bis Browser/Server trennt)

### Channel Subscription

**Client-Seite** (`table_monitor_channel.js`):
```javascript
consumer.subscriptions.create("TableMonitorChannel", {
  initialized() { console.log("TableMonitor Channel initialized") },
  connected()    { console.log("TableMonitor Channel connected") },
  disconnected() { console.log("TableMonitor Channel disconnected") },
  received(data) { 
    if (data.cableReady) CableReady.perform(data.operations) 
  }
})
```

**Server-Seite** (`table_monitor_channel.rb`):
```ruby
class TableMonitorChannel < ApplicationCable::Channel
  def subscribed
    stream_from "table-monitor-stream"
    Rails.logger.info "TableMonitorChannel subscribed"
  end
end
```

**Was passiert:**
1. Client sendet Subscription-Request über WebSocket
2. Server ruft `subscribed` auf
3. Server registriert Client für Stream `"table-monitor-stream"`
4. Alle zukünftigen Broadcasts auf diesem Stream werden an Client gesendet
5. Channel bleibt subscribed, solange WebSocket offen ist

---

## 2. Stimulus Controller Lifecycle

### Controller Connect/Disconnect

**Wichtig:** Stimulus Controller sind **DOM-gebunden**!

```javascript
export default class extends ApplicationController {
  connect() {
    super.connect()  // Registriert StimulusReflex
    console.log("TableMonitor controller connected!")
  }
  
  disconnect() {
    // Wird automatisch aufgerufen wenn DOM-Element entfernt wird
  }
}
```

**Wann wird `connect()` aufgerufen:**
- ✅ Beim ersten Laden der Seite
- ✅ Nach `innerHTML` replacement (neues DOM-Element mit `data-controller`)
- ✅ Nach Turbo navigation
- ❌ **NICHT** bei normalen CableReady updates (wenn Element bestehen bleibt)

**Wann wird `disconnect()` aufgerufen:**
- ✅ Wenn DOM-Element mit `data-controller` entfernt wird
- ✅ Vor Turbo navigation (altes DOM wird entfernt)
- ✅ Vor `innerHTML` replacement des Elements

### ⚠️ **KRITISCHES PROBLEM: innerHTML und Stimulus**

Wenn wir `innerHTML` auf ein **übergeordnetes Element** setzen:

```ruby
# Im Job
cable_ready["table-monitor-stream"].inner_html(
  selector: "#full_screen_table_monitor_#{table_monitor.id}",
  html: rendered_html
)
```

**Was passiert:**
1. Browser ersetzt komplettes HTML von `#full_screen_table_monitor_X`
2. **ALLE child Stimulus Controller werden getrennt** (`disconnect()`)
3. Browser parst neues HTML
4. Stimulus scannt neues DOM
5. **Neue Controller-Instanzen werden erstellt** (`connect()`)
6. `super.connect()` registriert neu bei StimulusReflex

**Aber:**
- ❓ Wird die **ActionCable Subscription** beibehalten? 
  - ✅ **JA** - ActionCable Consumer ist **global** und bleibt bestehen
  - ✅ Channel-Subscription bleibt aktiv (lebt in `consumer.subscriptions`)
  - ✅ WebSocket bleibt offen

---

## 3. StimulusReflex Flow

### User Action → Reflex → Response

```
USER CLICK
   │
   ▼
Stimulus Controller (add_n)
   │
   ▼
this.stimulate('TableMonitor#add_n', element)
   │
   ▼
StimulusReflex schickt über WebSocket:
{
  target: "TableMonitor#add_n",
  args: [...],
  url: current_url,
  tab_id: unique_id,
  element: {dataset: {...}}
}
   │
   ▼
SERVER: TableMonitorReflex#add_n
  - @table_monitor.add_n_balls(n)
  - @table_monitor.do_play
  - @table_monitor.save!
   │
   ▼
ActiveRecord Callback: after_update_commit
  - TableMonitorJob.perform_later(self, 'score_update')
   │
   ▼
TableMonitorJob#perform
  - table_monitor.reload              # Fresh data
  - table_monitor.clear_options_cache # No stale cache
  - render HTML
  - cable_ready["table-monitor-stream"].inner_html(...)
  - cable_ready.broadcast
   │
   ▼
ActionCable broadcasts zu ALLEN Clients auf "table-monitor-stream"
   │
   ├──▶ Browser A: table_monitor_channel.received(data)
   │              CableReady.perform(data.operations)
   │              innerHTML update
   │              Stimulus Controller disconnect/connect
   │
   ├──▶ Browser B: table_monitor_channel.received(data)
   │              CableReady.perform(data.operations)
   │              innerHTML update (wenn Selector existiert)
   │
   └──▶ Browser C: table_monitor_channel.received(data)
                  CableReady.perform(data.operations)
                  (ignoriert, wenn Selector nicht existiert)
```

---

## 4. Potenzielle Probleme

### Problem 1: innerHTML ersetzt DOM komplett

**Symptom:** Stimulus Controller wird neu erstellt, verliert internen State

**Beispiel:**
```javascript
export default class extends ApplicationController {
  connect() {
    this.someInternalState = "wichtig"  // ❌ VERLOREN bei innerHTML!
  }
}
```

**Lösung:** Kein interner State in Controller!
- ✅ Unser `table_monitor_controller.js` hat **keinen internen State**
- ✅ Alle Daten kommen vom Server (data-attributes, rendered HTML)

### Problem 2: Race Condition bei schnellen Updates

**Symptom:** Update A kommt an, bevor Job von Update B fertig ist

**Flow:**
```
Browser: click +10 → Reflex A → Job A (dauert 100ms)
Browser: click +10 → Reflex B → Job B (dauert 100ms)

Job A: reload (score=0) → render (score=10) → broadcast
Job B: reload (score=10) → render (score=20) → broadcast ✅ KORREKT

Browser empfängt:
  1. Broadcast A: innerHTML (score=10)
  2. Broadcast B: innerHTML (score=20) ✅ KORREKT
```

**Problem gelöst durch:**
- ✅ `table_monitor.reload` am Anfang von Job
- ✅ `table_monitor.save!` committet sofort
- ✅ Database Locks verhindern Race Conditions

### Problem 3: Selektive Updates vs. Full Screen

**Symptom:** Teaser-Update ändert nur `#teaser_X`, nicht `#full_screen_table_monitor_X`

**Was passiert:**

Wenn Browser A auf **Scoreboard-Ansicht** (`#full_screen_table_monitor_50000001`) ist:
```ruby
# Teaser-Update kommt an
cable_ready["table-monitor-stream"].inner_html(
  selector: "#teaser_50000001",  # ← Existiert NICHT auf Scoreboard-Seite!
  html: teaser_html
)
```

**Resultat:**
- ✅ Browser A: CableReady findet `#teaser_50000001` nicht → **ignoriert Update**
- ✅ Browser B (table_scores): CableReady findet `#teaser_50000001` → **updated**

**Das ist KORREKT!** DOM-Selector-Filtering funktioniert!

### Problem 4: WebSocket Disconnect/Reconnect

**Symptome:**
- "Cable disconnected"
- Updates kommen nicht mehr an
- Reflex-Calls funktionieren nicht mehr

**Mögliche Ursachen:**

#### A. Server Timeout
```ruby
# config/cable.yml
production:
  adapter: redis
  url: redis://localhost:6379/1
  channel_prefix: carambus_production
```

**Redis Connection Timeout:** Wenn Redis-Verbindung abbricht, kann ActionCable nicht mehr broadcasten

**Lösung:**
- Redis health check
- Reconnection logic in ActionCable (ist eingebaut)

#### B. Browser Tab Inactive

Moderne Browser pausieren WebSocket-Verbindungen bei inaktiven Tabs

**Was passiert:**
1. User wechselt zu anderem Tab
2. Browser pausiert WebSocket (nach ~30-60 Sekunden)
3. ActionCable.consumer automatische Reconnection
4. `disconnected()` → `connected()` callbacks werden aufgerufen
5. Subscriptions werden **automatisch neu etabliert**

**Logging:**
```javascript
disconnected() {
  console.log("TableMonitor Channel disconnected")
}

connected() {
  console.log("TableMonitor Channel connected")
}
```

**Lösung:** ✅ Ist bereits eingebaut! ActionCable reconnected automatisch.

#### C. Nginx/Puma Timeout

**Nginx config:**
```nginx
location /cable {
  proxy_pass http://puma_upstream;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection "upgrade";
  proxy_read_timeout 7200s;  # ← Wichtig!
  proxy_send_timeout 7200s;
}
```

**Wenn Timeout zu kurz:**
- Nginx trennt WebSocket nach X Sekunden
- Client versucht Reconnection
- Aber: Neue Verbindung könnte zu anderem Puma Worker gehen!

### Problem 5: Protocol Close beim Spielende

**Symptom:** "Wenn ich ein Spiel schließe, kriegen das andere Scoreboards bzw. table_scores nicht mit"

**Was sollte passieren:**

```ruby
# In TableMonitorReflex oder im Modell
def close_game
  @table_monitor.update!(state: 'finished')
  # ↓ after_update_commit callback
  TableMonitorJob.perform_later(@table_monitor, 'table_scores')
end
```

**TableMonitorJob sollte broadcasten:**
```ruby
def perform_table_scores_update(table_monitor)
  location = table_monitor.table.location
  cable_ready["table-monitor-stream"].inner_html(
    selector: "#table_scores",
    html: render("locations/table_scores", location: location, ...)
  )
  cable_ready.broadcast  # ← KRITISCH!
end
```

**Potenzielle Probleme:**

#### A. Callback wird nicht getriggert
```ruby
# ❌ FALSCH - kein Callback!
@table_monitor.state = 'finished'
# Kein save! → Kein after_update_commit!

# ✅ RICHTIG
@table_monitor.update!(state: 'finished')  # Triggert Callback
```

#### B. Falscher operation_type
```ruby
# In after_update_commit
relevant_keys = (previous_changes.keys - %w[
  data nnn panel_state pointer_mode current_element updated_at
])

if relevant_keys.any?
  # ✅ Bei game_id Änderung (Spielende): 'table_scores'
  TableMonitorJob.perform_later(self, 'table_scores')
else
  # ❌ Bei unwichtigen Änderungen: 'score_update'
  TableMonitorJob.perform_later(self, 'score_update')
end
```

**Wenn `state` Änderung NICHT in `relevant_keys` ist:**
- Job wird mit 'score_update' aufgerufen
- Nur Scoreboard wird aktualisiert
- `table_scores` wird **NICHT** aktualisiert! ❌

**Lösung prüfen:**
```ruby
# In table_monitor.rb after_update_commit
relevant_keys = (previous_changes.keys - %w[
  data nnn panel_state pointer_mode current_element updated_at
])

# Ist 'state' in den ignored keys? NEIN ✅
# Ist 'game_id' in den ignored keys? NEIN ✅
# Also sollte table_scores Update getriggert werden!
```

#### C. Job läuft, aber broadcast kommt nicht an

**Debugging in Job:**
```ruby
def perform(table_monitor, operation_type)
  Rails.logger.info "📡 TableMonitorJob START: id=#{table_monitor.id} op=#{operation_type}"
  
  table_monitor.reload
  table_monitor.clear_options_cache
  
  case operation_type
  when "table_scores"
    Rails.logger.info "📡 Broadcasting table_scores update"
    perform_table_scores_update(table_monitor)
  # ...
  end
  
  Rails.logger.info "📡 Calling broadcast..."
  cable_ready.broadcast
  Rails.logger.info "📡 Broadcast sent!"
end
```

**In Browser Console prüfen:**
```javascript
// Kommt Update an?
received(data) {
  console.log("📥 TableMonitor Channel received:", data)
  if (data.cableReady) {
    console.log("📥 CableReady operations:", data.operations)
    CableReady.perform(data.operations)
  }
}
```

---

## 5. Debugging-Strategie

### Server-Side Logging

**In `table_monitor.rb`:**
```ruby
after_update_commit lambda {
  Rails.logger.info "🔔 after_update_commit triggered"
  Rails.logger.info "🔔 Previous changes: #{previous_changes.inspect}"
  
  relevant_keys = (previous_changes.keys - %w[
    data nnn panel_state pointer_mode current_element updated_at
  ])
  
  Rails.logger.info "🔔 Relevant keys: #{relevant_keys.inspect}"
  
  if relevant_keys.any?
    Rails.logger.info "🔔 Enqueuing table_scores job"
    TableMonitorJob.perform_later(self, 'table_scores')
  else
    Rails.logger.info "🔔 Enqueuing score_update job"
    TableMonitorJob.perform_later(self, 'score_update')
  end
}
```

**In `table_monitor_job.rb`:**
```ruby
def perform(table_monitor, operation_type)
  Rails.logger.info "📡 === TableMonitorJob START ==="
  Rails.logger.info "📡 ID: #{table_monitor.id}"
  Rails.logger.info "📡 Operation: #{operation_type}"
  Rails.logger.info "📡 Stream: table-monitor-stream"
  
  # ... rendering ...
  
  Rails.logger.info "📡 Selector: #{selector}"
  Rails.logger.info "📡 HTML size: #{html.bytesize} bytes"
  Rails.logger.info "📡 Calling broadcast..."
  
  cable_ready.broadcast
  
  Rails.logger.info "📡 Broadcast complete!"
  Rails.logger.info "📡 === TableMonitorJob END ==="
end
```

### Client-Side Logging

**Erweiterte `table_monitor_channel.js`:**
```javascript
consumer.subscriptions.create("TableMonitorChannel", {
  initialized() {
    console.log("🔌 TableMonitor Channel initialized")
    this.connectionAttempts = 0
  },

  connected() {
    console.log("🔌 TableMonitor Channel connected")
    console.log("🔌 Consumer state:", consumer.connection.getState())
    this.connectionAttempts = 0
  },

  disconnected() {
    console.log("🔌 TableMonitor Channel disconnected")
    this.connectionAttempts++
    console.log("🔌 Disconnect count:", this.connectionAttempts)
  },

  received(data) {
    console.log("📥 TableMonitor Channel received:", {
      timestamp: new Date().toISOString(),
      hasCableReady: !!data.cableReady,
      operationCount: data.operations?.length,
      operations: data.operations
    })
    
    if (data.cableReady) {
      data.operations.forEach(op => {
        console.log("📥 CableReady operation:", {
          type: op.operation,
          selector: op.selector,
          htmlSize: op.html?.length
        })
      })
      
      CableReady.perform(data.operations)
      console.log("✅ CableReady operations performed")
    }
  }
});
```

### Network Monitoring

**WebSocket Frames in Browser DevTools:**
1. Öffne Chrome DevTools
2. Network Tab → Filter: WS (WebSockets)
3. Klicke auf `/cable` Verbindung
4. Tab "Messages" zeigt alle Frames:
   - **Outgoing:** Client → Server (Reflex calls, pings)
   - **Incoming:** Server → Client (Broadcasts, confirmations)

**Gesunde Verbindung zeigt:**
- Regelmäßige `{"type":"ping"}` messages
- Entsprechende `{"type":"confirm_subscription"}` bei connect
- Broadcast messages bei Updates

**Problematische Verbindung:**
- Connection State = "closed" or "connecting"
- Keine ping messages
- Broadcasts kommen nicht an

---

## 6. Best Practices & Empfehlungen

### ✅ Was wir richtig machen

1. **Keine Client-Side State** 
   - Stimulus Controller speichern nichts intern
   - Alles kommt vom Server

2. **Reload + Cache Clear**
   ```ruby
   table_monitor.reload
   table_monitor.clear_options_cache
   ```

3. **save! statt save**
   - Garantiert Commit vor Callback
   - Exception bei Fehler

4. **Globaler Stream**
   - Einfache Architektur
   - DOM-Selector filtering

### ⚠️ Was zu prüfen ist

1. **Callback Trigger** 
   - Loggen in `after_update_commit`
   - Sind alle wichtigen Attribute NICHT in exclude-Liste?

2. **Job Execution**
   - Läuft Job wirklich?
   - Wird `broadcast` aufgerufen?
   - Richtige operation_type?

3. **WebSocket Health**
   - Sind Connections stabil?
   - Reconnection funktioniert?
   - Redis läuft?

4. **Browser Tab State**
   - Sind Tabs aktiv?
   - Background Tabs können pausieren

### 🔧 Empfohlene Verbesserungen

#### 1. Explizites Logging einbauen

```ruby
# In carambus_master/config/initializers/cable_ready_logging.rb
CableReady::Channels.class_eval do
  def broadcast
    Rails.logger.info "📡 CableReady broadcasting to: #{@identifier}"
    Rails.logger.info "📡 Operations: #{@enqueued_operations.size}"
    super
  end
end
```

#### 2. Health Check Endpoint

```ruby
# In routes.rb
get '/cable/health', to: 'cable_health#show'

# app/controllers/cable_health_controller.rb
class CableHealthController < ApplicationController
  def show
    render json: {
      redis: redis_healthy?,
      active_connections: ActionCable.server.connections.size,
      active_streams: ActionCable.server.pubsub.send(:redis_connection).pubsub("channels", "*")
    }
  end
  
  private
  
  def redis_healthy?
    ActionCable.server.pubsub.send(:redis_connection).ping == "PONG"
  rescue
    false
  end
end
```

#### 3. Client-Side Connection Monitor

```javascript
// In application.js
class ConnectionMonitor {
  constructor() {
    this.lastPing = Date.now()
    this.checkInterval = setInterval(() => this.check(), 5000)
  }
  
  check() {
    const now = Date.now()
    const sinceLastPing = now - this.lastPing
    
    if (sinceLastPing > 60000) {  // 1 Minute ohne Ping
      console.warn("⚠️ No ping from server for 60s - connection may be dead")
      console.warn("⚠️ Attempting manual reconnect...")
      consumer.connection.reopen()
    }
  }
  
  recordPing() {
    this.lastPing = Date.now()
  }
}

const monitor = new ConnectionMonitor()

// In table_monitor_channel.js
received(data) {
  if (data.type === 'ping') monitor.recordPing()
  // ... rest of code
}
```

---

## 7. Troubleshooting Checklist

Wenn "Spiel schließen wird nicht synchronisiert":

### Schritt 1: Server Logs prüfen

```bash
# Production
tail -f /var/www/carambus_bcw/current/log/production.log | grep -E "(after_update_commit|TableMonitorJob|CableReady)"

# Development
tail -f log/development.log | grep -E "(after_update_commit|TableMonitorJob|CableReady)"
```

**Erwartete Ausgabe:**
```
🔔 after_update_commit triggered
🔔 Previous changes: {"state"=>["playing", "finished"], "game_id"=>[123, nil]}
🔔 Relevant keys: ["state", "game_id"]
🔔 Enqueuing table_scores job
📡 TableMonitorJob START: id=50000001 op=table_scores
📡 Broadcasting table_scores update
📡 Calling broadcast...
📡 Broadcast complete!
```

**Wenn fehlt:**
- Kein `after_update_commit` → `save!` wurde nicht aufgerufen
- Kein `table_scores` → Attribute in exclude-Liste
- Kein `Broadcast complete` → Exception im Job

### Schritt 2: Browser Console prüfen

**Auf BEIDEN Browsern (Scoreboard + table_scores):**

```javascript
// Console Output erwarten:
🔌 TableMonitor Channel connected
📥 TableMonitor Channel received: {timestamp: "...", hasCableReady: true, ...}
📥 CableReady operation: {type: "innerHTML", selector: "#table_scores", ...}
✅ CableReady operations performed
```

**Wenn fehlt:**
- Kein `connected` → WebSocket tot
- Kein `received` → Broadcast kommt nicht an
- Kein `CableReady operation` → Falsche Daten
- Kein `operations performed` → CableReady Error

### Schritt 3: WebSocket Frames prüfen

**Chrome DevTools → Network → WS → /cable:**

**Gesund:**
```
← {"type":"ping"}
→ {"type":"confirm_subscription","identifier":"{\"channel\":\"TableMonitorChannel\"}"}
← {"identifier":"...", "message":{"cableReady":true,"operations":[...]}}
```

**Problem:**
```
← {"type":"ping"}
(keine weiteren messages)
```

### Schritt 4: Redis prüfen

```bash
redis-cli
> PING
PONG
> PUBSUB CHANNELS *
1) "table-monitor-stream"
> PUBSUB NUMSUB table-monitor-stream
1) "table-monitor-stream"
2) (integer) 3   # ← 3 subscribed clients
```

---

## Fazit

**Die Architektur ist grundsätzlich solide:**
- ✅ ActionCable verbindet persistent
- ✅ Reconnection ist automatisch
- ✅ Stimulus Controllers reconnecten bei innerHTML
- ✅ DOM-Selector Filtering funktioniert

**Aber:** Es gibt Lücken in der Observability!

**Nächste Schritte:**
1. Logging wie oben beschrieben einbauen
2. Mit Logging das "Spielende synchronisiert nicht" Problem tracken
3. Wenn Callback/Job ausgeführt wird aber nicht ankommt → WebSocket/Redis Problem
4. Wenn Callback nicht getriggert wird → Model/Reflex Code prüfen

---

**Sollen wir das Logging jetzt einbauen und dann systematisch testen?**

