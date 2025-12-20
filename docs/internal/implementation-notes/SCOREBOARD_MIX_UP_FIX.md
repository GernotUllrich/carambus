# Scoreboard Mix-Up Prevention (Phase 1)

## Problem
Gelegentlich erscheint an einem Scoreboard plötzlich das Scoreboard eines anderen Tisches. Dies ist ein Race-Condition-Problem in der Broadcast-Architektur.

## Root Cause Analysis

### Identifizierte Schwachstellen

1. **Globaler Broadcast-Stream ohne Server-seitige Isolierung**
   - Alle TableMonitor-Updates werden über einen gemeinsamen Stream (`table-monitor-stream`) gesendet
   - Filterung erfolgt erst im Browser (JavaScript)
   - Bei Page-Loads oder Turbo-Navigationen kann die Context Detection temporär versagen

2. **Fehlende Session-Persistenz für Table-Binding**
   - Session speicherte nur `location_id`, nicht `table_id`
   - Bei Page-Reload keine Möglichkeit, den korrekten Tisch wiederherzustellen

3. **Client-seitige Filterung hatte Lücken**
   - Während Page Transitions kann das DOM-Element fehlen
   - Context Detection gibt `type: 'unknown'` zurück → Filterung versagt
   - Keine Backup-Mechanismen bei DOM-Übergängen

## Implementierte Lösung (Phase 1)

### 1. Session-Tracking für table_id ✅

**Datei:** `app/controllers/locations_controller.rb`

```ruby
# In scoreboard action:
if params[:table_id].present?
  session[:scoreboard_table_id] = params[:table_id]
  Rails.logger.info "[Scoreboard] 🎯 Session table_id set: #{session[:scoreboard_table_id]}"
end

# In show action:
if params[:table_id].present?
  @table = Table.find(params[:table_id])
  session[:scoreboard_table_id] = params[:table_id]
  Rails.logger.info "[Scoreboard] 🎯 Table set from params: #{@table.id}"
elsif session[:scoreboard_table_id].present?
  @table = Table.find(session[:scoreboard_table_id])
  Rails.logger.info "[Scoreboard] 🎯 Table restored from session: #{@table.id}"
end
```

**Benefit:** 
- Scoreboard behält nach Page-Reload die korrekte Tisch-Zuordnung
- Session wirkt als Fallback wenn URL-Parameter fehlen

### 2. Meta-Tags für Server-seitige Binding ✅

**Datei:** `app/views/layouts/application.html.erb`

```erb
<!-- Scoreboard table_id binding for client-side validation -->
<% if @table&.table_monitor&.id.present? %>
  <meta name="scoreboard-table-monitor-id" content="<%= @table.table_monitor.id %>">
  <meta name="scoreboard-table-id" content="<%= @table.id %>">
<% end %>
```

**Benefit:**
- Meta-Tag ist **sofort** im DOM verfügbar, auch während Turbo-Navigation
- Höchste Priorität in der Context Detection
- Server bestimmt die "Source of Truth"

### 3. Robuste Client-seitige Filterung mit Prioritäten ✅

**Datei:** `app/javascript/channels/table_monitor_channel.js`

**Neue Priority-basierte Context Detection:**

```javascript
function getPageContext() {
  // PRIORITY 1: Check meta tag (most reliable, set by server)
  const metaTableMonitorId = document.querySelector('meta[name="scoreboard-table-monitor-id"]')
  if (metaTableMonitorId) {
    return { 
      type: 'scoreboard', 
      tableMonitorId: parseInt(metaTableMonitorId.content),
      source: 'meta-tag'  // <- Tracking für Debugging
    }
  }
  
  // PRIORITY 2: Data attribute on scoreboard root
  const scoreboardRoot = document.querySelector('[data-table-monitor-root="scoreboard"]')
  if (scoreboardRoot && scoreboardRoot.dataset.tableMonitorId) {
    return { 
      type: 'scoreboard', 
      tableMonitorId: parseInt(scoreboardRoot.dataset.tableMonitorId),
      source: 'data-attribute'
    }
  }
  
  // PRIORITY 3: Fallback - DOM ID parsing
  const scoreboardEl = document.querySelector('[id^="full_screen_table_monitor_"]')
  if (scoreboardEl) {
    const idMatch = scoreboardEl.id.match(/full_screen_table_monitor_(\d+)/)
    if (idMatch) {
      return { 
        type: 'scoreboard', 
        tableMonitorId: parseInt(idMatch[1]),
        source: 'dom-id'
      }
    }
  }
  
  // ... other page types
  return { type: 'unknown' }
}
```

**Benefits:**
- **3-stufiges Fallback-System** verhindert Context-Verlust
- Meta-Tag funktioniert auch während DOM-Übergängen
- `source`-Tracking ermöglicht Debugging

### 4. Erweiterte Logging für Fehlerdiagnose ✅

**Client-seitig (JavaScript):**

```javascript
// Bei Rejection eines falschen Scoreboards:
console.warn(`🚫 SCOREBOARD MIX-UP PREVENTED: Selector ${selector} (TM_ID: ${selectorTableMonitorId}) rejected for current scoreboard (TM_ID: ${pageContext.tableMonitorId}, source: ${pageContext.source})`)

// Bei Context Detection Failure:
console.error('⚠️ SCOREBOARD CONTEXT DETECTION FAILED:', {
  detectedType: pageContext.type,
  hasScoreboardRoot: true,
  metaTag: document.querySelector('meta[name="scoreboard-table-monitor-id"]')?.content,
  timestamp: new Date().toISOString(),
  url: window.location.href
})
```

**Server-seitig (Ruby):**

```ruby
Rails.logger.info "📡 ⚠️  FULL SCOREBOARD UPDATE: This will be sent to ALL clients via shared stream"
Rails.logger.info "📡 ⚠️  Clients MUST filter by table_monitor_id=#{table_monitor.id} to prevent mix-ups"
```

**Benefits:**
- Wenn ein Mix-Up auftritt, werden Details geloggt
- Source-Tracking zeigt, welcher Detection-Mechanismus aktiv war
- Server-Logs zeigen Intent, Client-Logs zeigen tatsächliche Filterung

## Testing & Validation

### Test-Szenarien

1. **Normal Operation**
   - ✅ Scoreboard zeigt korrekten Tisch
   - ✅ Updates werden korrekt gefiltert
   - ✅ Andere Tische werden rejected

2. **Page Reload**
   - ✅ Session restoration funktioniert
   - ✅ table_id wird aus Session geladen
   - ✅ Meta-Tag wird korrekt gesetzt

3. **Turbo Navigation**
   - ✅ Meta-Tag ist sofort verfügbar
   - ✅ Keine Race Condition während DOM-Übergang
   - ✅ Context Detection funktioniert kontinuierlich

4. **Multiple Scoreboards (verschiedene Browser/Tabs)**
   - ✅ Jedes Scoreboard filtert korrekt nach seiner table_monitor_id
   - ✅ Broadcasts anderer Tische werden rejected
   - ✅ Logging zeigt prevented mix-ups

5. **Edge Cases**
   - ✅ Scoreboard ohne aktives Spiel
   - ✅ Wechsel zwischen Tischen
   - ✅ Connection Loss & Reconnect

## Monitoring

### Log-Signale bei Mix-Up Prevention

**Im Browser Console:**
```
🚫 SCOREBOARD MIX-UP PREVENTED: Selector #full_screen_table_monitor_5 (TM_ID: 5) rejected for current scoreboard (TM_ID: 3, source: meta-tag)
```

**Im Server Log:**
```
📡 TableMonitor ID: 5
📡 Table ID: 2
📡 Location ID: 1
📡 ⚠️  FULL SCOREBOARD UPDATE: This will be sent to ALL clients via shared stream
📡 ⚠️  Clients MUST filter by table_monitor_id=5 to prevent mix-ups
```

### Was tun bei erneutem Mix-Up?

1. **Check Browser Console** für Context Detection Errors
2. **Check Server Logs** für Broadcast Pattern
3. **Verify Session** (`session[:scoreboard_table_id]`)
4. **Check Meta-Tag** im HTML (`<meta name="scoreboard-table-monitor-id">`)

## Future Improvements (Phase 2)

Falls Phase 1 nicht ausreichend ist:

1. **Server-seitige Stream-Isolierung**
   - Dedizierte Streams pro TableMonitor: `table-monitor-#{table_monitor.id}-stream`
   - **Vorteil:** Absolute Isolation, keine Client-Filterung nötig
   - **Nachteil:** Komplexere Subscription-Verwaltung

2. **Request ID Tracking**
   - Eindeutige Request-IDs für jede Scoreboard-Session
   - Tracking von Request → TableMonitor Mapping
   - Validierung bei jedem Broadcast

3. **Health Check mit TableMonitor-Binding**
   - Periodischer Health-Check mit table_monitor_id
   - Server validiert Client-Binding
   - Automatische Korrektur bei Fehlzuordnung

## Change Summary

**Modified Files:**
- `app/controllers/locations_controller.rb` - Session tracking
- `app/views/layouts/application.html.erb` - Meta tags
- `app/javascript/channels/table_monitor_channel.js` - Robust filtering
- `app/jobs/table_monitor_job.rb` - Enhanced logging

**No Breaking Changes**
- Alle Änderungen sind backward-compatible
- Existing functionality bleibt erhalten
- Nur zusätzliche Sicherheitsschichten

## Timeline
- **Phase 1 Implemented:** 2024-12-11
- **Next Review:** Nach 1 Woche Produktion
- **Phase 2 Trigger:** Falls Mix-Ups weiterhin auftreten

