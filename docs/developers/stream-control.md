# Stream-Steuerung vom MacBook

## Übersicht

Sie können Streams direkt vom MacBook aus starten, stoppen und neu starten, ohne das Admin-Interface zu verwenden.

## Methoden

### 1. Rails Console (Empfohlen)

Die einfachste Methode ist die Rails Console:

```bash
cd carambus_bcw
rails console
```

Dann in der Console:

```ruby
# Stream-Konfiguration finden (z.B. für Tisch 7, table_id = 3)
config = StreamConfiguration.find_by(table_id: 3)

# Stream starten
config.start_streaming

# Stream stoppen
config.stop_streaming

# Stream neu starten
config.restart_streaming

# Status prüfen
config.status
config.active?
```

### 2. Rails Runner (Einzeiler)

Für schnelle Befehle ohne Console:

```bash
cd carambus_bcw

# Stream starten
rails runner "StreamConfiguration.find_by(table_id: 3).start_streaming"

# Stream stoppen
rails runner "StreamConfiguration.find_by(table_id: 3).stop_streaming"

# Stream neu starten
rails runner "StreamConfiguration.find_by(table_id: 3).restart_streaming"

# Status anzeigen
rails runner "config = StreamConfiguration.find_by(table_id: 3); puts \"Status: #{config.status}\"; puts \"Active: #{config.active?}\""
```

### 3. Direkt über SSH (Alternative)

Falls Sie direkten Zugriff auf den Raspberry Pi haben:

```bash
# Stream starten
ssh pi@192.168.2.217 "sudo systemctl start carambus-stream@7.service"

# Stream stoppen
ssh pi@192.168.2.217 "sudo systemctl stop carambus-stream@7.service"

# Stream neu starten
ssh pi@192.168.2.217 "sudo systemctl restart carambus-stream@7.service"

# Status prüfen
ssh pi@192.168.2.217 "sudo systemctl status carambus-stream@7.service"
```

## Häufige Workflows

### Stream neu starten nach Konfigurationsänderung

```bash
cd carambus_bcw

# 1. Konfiguration deployen
rake 'streaming:deploy[3]'

# 2. Stream neu starten
rails runner "
config = StreamConfiguration.find_by(table_id: 3)
config.stop_streaming
sleep 3
config.start_streaming
puts '✅ Stream neu gestartet'
"
```

### Stream mit neuen Kameraeinstellungen neu starten

```bash
cd carambus_bcw

# 1. Kameraeinstellungen speichern (falls geändert)
rake 'streaming:camera_save[3]'

# 2. Konfiguration deployen
rake 'streaming:deploy[3]'

# 3. Stream neu starten
rails runner "
config = StreamConfiguration.find_by(table_id: 3)
config.restart_streaming
puts '✅ Stream mit neuen Kameraeinstellungen neu gestartet'
"
```

### Stream mit Trapezkorrektur neu starten

```bash
cd carambus_bcw

# 1. Trapezkorrektur setzen (falls geändert)
rake 'streaming:perspective_set[3,50:20:W-50:20:W-30:H-30:30:H-30]'

# 2. Konfiguration deployen
rake 'streaming:deploy[3]'

# 3. Stream neu starten
rails runner "
config = StreamConfiguration.find_by(table_id: 3)
config.restart_streaming
puts '✅ Stream mit Trapezkorrektur neu gestartet'
"
```

## Status prüfen

### In Rails Console

```ruby
config = StreamConfiguration.find_by(table_id: 3)

# Status
puts "Status: #{config.status}"
puts "Active: #{config.active?}"
puts "Uptime: #{config.uptime_humanized}"

# Letzte Aktivität
puts "Last started: #{config.last_started_at}"
puts "Last stopped: #{config.last_stopped_at}"

# Fehler
if config.error?
  puts "Error: #{config.error_message}"
end
```

### Über SSH

```bash
# Service-Status
ssh pi@192.168.2.217 "sudo systemctl status carambus-stream@7.service"

# Logs anzeigen
ssh pi@192.168.2.217 "tail -50 /var/log/carambus/stream-table-7.log"
```

## Troubleshooting

### Stream startet nicht

1. **Prüfen Sie den Status:**
   ```ruby
   config = StreamConfiguration.find_by(table_id: 3)
   puts config.status
   puts config.error_message
   ```

2. **Prüfen Sie die Logs auf dem Raspberry Pi:**
   ```bash
   ssh pi@192.168.2.217 "tail -100 /var/log/carambus/stream-table-7.log"
   ```

3. **Prüfen Sie, ob der Service läuft:**
   ```bash
   ssh pi@192.168.2.217 "sudo systemctl status carambus-stream@7.service"
   ```

### Stream stoppt nicht

Falls `stop_streaming` nicht funktioniert, können Sie den Service direkt stoppen:

```bash
ssh pi@192.168.2.217 "sudo systemctl stop carambus-stream@7.service"
```

Dann in Rails Console den Status zurücksetzen:

```ruby
config = StreamConfiguration.find_by(table_id: 3)
config.mark_stopped!
```

### Stream hängt im "starting" Status

Manchmal bleibt der Stream im "starting" Status hängen. Sie können ihn zurücksetzen:

```ruby
config = StreamConfiguration.find_by(table_id: 3)
config.mark_stopped!
config.start_streaming
```

## Tipps

1. **Warten zwischen Stop und Start:**
   - Nach `stop_streaming` sollten Sie 2-3 Sekunden warten, bevor Sie `start_streaming` aufrufen
   - Dies gibt dem System Zeit, den Service sauber zu beenden

2. **Status prüfen:**
   - Prüfen Sie immer den Status, bevor Sie Aktionen ausführen
   - `config.active?` zeigt, ob der Stream läuft

3. **Logs beobachten:**
   - Beobachten Sie die Logs während Sie den Stream starten/stoppen
   - Dies hilft bei der Fehlersuche

## Beispiel-Script

Hier ist ein vollständiges Beispiel-Script für den Neustart:

```ruby
# In Rails Console oder als rails runner Script

config = StreamConfiguration.find_by(table_id: 3)

puts "📊 Aktueller Status: #{config.status}"

if config.active?
  puts "🛑 Stoppe Stream..."
  config.stop_streaming
  sleep 3
end

puts "🚀 Starte Stream..."
config.start_streaming

sleep 2

puts "📊 Neuer Status: #{config.status}"
puts "✅ Stream gestartet!" if config.starting? || config.active?
```

## Weitere Informationen

- [Camera Calibration](./camera-calibration.md)
- [Perspective Correction](./perspective-correction.md)
- [Streaming Architecture](../developers/streaming-architecture.md)

