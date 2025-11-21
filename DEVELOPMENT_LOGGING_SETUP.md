# Development Logging Setup - Log to File AND Console

**Problem**: RubyMine zeigt Logs nur in Console, nicht in File → `grep` funktioniert nicht!

**Lösung**: Konfiguriere Rails Logger für BEIDE Ausgaben.

---

## Änderung in `config/environments/development.rb`

### Original (nur Console):

```ruby
# Log to STDOUT for development
config.logger = ActiveSupport::Logger.new($stdout)
  .tap { |logger| logger.formatter = ::Logger::Formatter.new }
  .then { |logger| ActiveSupport::TaggedLogging.new(logger) }
```

### Neu (Console UND File):

```ruby
# Log to BOTH STDOUT (for RubyMine console) AND file (for grep/tail)
# This allows viewing logs in RubyMine console while also enabling:
# tail -f log/development.log | grep -E "(🔔|📡|📥|🔌)"
stdout_logger = ActiveSupport::Logger.new($stdout)
file_logger = ActiveSupport::Logger.new(Rails.root.join("log", "development.log"))

# Broadcast to both loggers
config.logger = ActiveSupport::BroadcastLogger.new(stdout_logger, file_logger)
config.logger.formatter = ::Logger::Formatter.new
```

---

## Änderung anwenden

**In BEIDEN Verzeichnissen:**

```bash
# carambus_bcw
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
# Editiere config/environments/development.rb (Zeile 13-16)

# carambus_master  
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
# Editiere config/environments/development.rb (Zeile 13-16)
```

**WICHTIG:** Die Datei ist in `.gitignore`, daher:
1. Änderung manuell in JEDEM Workspace machen
2. Nicht committen (wird ignoriert)
3. Bei neuem Clone: Änderung erneut machen

---

## Nach dem Ändern: Rails Server neu starten

```bash
# In RubyMine: Stop Server
# Dann: Start Server

# ODER via Terminal:
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
bin/rails restart
```

---

## Logs beobachten

### In separatem Terminal:

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw

# Alle Logs mit Emojis
tail -f log/development.log | grep -E "(🔔|📡|📥|🔌)"

# Oder: Nur TableMonitor-relevante Logs
tail -f log/development.log | grep -E "(TableMonitor|after_update_commit|CableReady)"

# Oder: Nur Job-Logs
tail -f log/development.log | grep "📡"

# Oder: Nur Callback-Logs
tail -f log/development.log | grep "🔔"

# Oder: Nur Browser-Channel-Logs (müssen Sie in Browser Console sehen)
# Diese werden nicht ins Server-Log geschrieben!
```

---

## Vorteile

**Vorher (nur STDOUT):**
- ✅ Logs in RubyMine Console sichtbar
- ❌ Kein `tail -f` oder `grep` möglich
- ❌ Logs verschwinden beim Console-Clear
- ❌ Schwer, bestimmte Events zu finden

**Nachher (STDOUT + File):**
- ✅ Logs in RubyMine Console sichtbar
- ✅ `tail -f log/development.log` funktioniert
- ✅ `grep` für Filtering
- ✅ Log-History bleibt erhalten
- ✅ Zwei Terminals parallel: Code + Logs

---

## Alternative: Nur File Logging (nicht empfohlen)

Wenn Sie NICHT die RubyMine Console brauchen:

```ruby
# Nur File
config.logger = ActiveSupport::Logger.new(Rails.root.join("log", "development.log"))
config.logger.formatter = ::Logger::Formatter.new
```

**Nachteil:** Nichts in RubyMine Console sichtbar!

---

## Troubleshooting

### Problem: Nach Änderung keine Logs im File

**Lösung:**
1. Rails Server komplett stoppen
2. `log/development.log` löschen: `rm log/development.log`
3. Rails Server neu starten
4. File wird neu angelegt mit beiden Loggern

### Problem: Logs nur in Console, nicht in File

**Lösung:**
1. Überprüfen: Ist `BroadcastLogger` richtig konfiguriert?
2. Checken: `ls -la log/development.log` - existiert die Datei?
3. Permissions: `chmod 644 log/development.log`

### Problem: File-Logger schreibt nicht sofort

**Lösung:** File-Auto-Flush aktivieren:

```ruby
file_logger = ActiveSupport::Logger.new(Rails.root.join("log", "development.log"))
file_logger.instance_variable_get(:@logdev).dev.sync = true  # Auto-flush
```

---

## Verwendung mit dem Debug-Logging

### Server-Logs beobachten:

```bash
# Terminal 1: Rails Server (läuft in RubyMine)

# Terminal 2: Log monitoring
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
tail -f log/development.log | grep -E "(🔔|📡|📥|🔌)"
```

### Browser Console öffnen:

```javascript
// Chrome DevTools → Console
// Hier erscheinen die Client-Side Logs:
🔌 TableMonitor Channel initialized
🔌 TableMonitor Channel connected
📥 TableMonitor Channel received: {...}
✅ CableReady operations performed
```

### Erwartetes Verhalten nach Spiel-Update:

**In `log/development.log`:**
```
🔔 ========== after_update_commit TRIGGERED ==========
🔔 TableMonitor ID: 50000001
🔔 Previous changes: {"state"=>["playing", "finished"]}
🔔 Relevant keys: ["state"]
🔔 Enqueuing: table_scores job (relevant_keys present)
🔔 ========== after_update_commit END ==========

📡 ========== TableMonitorJob START ==========
📡 TableMonitor ID: 50000001
📡 Operation Type: table_scores
📡 Stream: table-monitor-stream
📡 Calling cable_ready.broadcast...
📡 Broadcast complete!
📡 ========== TableMonitorJob END ==========
```

**In Browser Console:**
```
📥 TableMonitor Channel received: {timestamp: "...", hasCableReady: true, ...}
📥 CableReady operation #1: {type: "innerHTML", selector: "#table_scores", ...}
✅ CableReady operations performed
```

---

## Zusammenfassung

1. **Änderung machen**: `config/environments/development.rb` editieren
2. **Server neu starten**: Damit Änderung wirksam wird
3. **Logs beobachten**: `tail -f log/development.log | grep -E "(🔔|📡)"`
4. **Action auslösen**: Z.B. Score update, Spiel schließen
5. **Beide Logs prüfen**: Server-Log (File) + Browser Console

**Jetzt können Sie systematisch debuggen!** 🎯

