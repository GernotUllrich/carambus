# Streaming Quick Reference

## Übersicht

Kurze Referenz für die häufigsten Streaming-Aufgaben.

## Wichtig: Wo ausführen?

**Alle Tasks müssen auf dem Local Server (192.168.2.210) ausgeführt werden!**

```bash
ssh user@192.168.2.210
cd /path/to/carambus_bcw
```

## Table 3 (Tisch 7) - Schnellzugriff

### SSH-Verbindung prüfen
```bash
rake 'streaming:ssh_test[3]'
```

### Kameraeinstellungen

**Aktuelle Werte anzeigen:**
```bash
rake 'streaming:camera_calibrate[3]'
```

**Werte setzen:**
```bash
rake 'streaming:camera_set[3,focus_automatic_continuous,0]'
rake 'streaming:camera_set[3,auto_exposure,1]'
rake 'streaming:camera_set[3,focus_absolute,125]'
```

**Werte speichern:**
```bash
rake 'streaming:camera_save[3]'
```

### Trapezkorrektur

**Interaktiv kalibrieren:**
```bash
rake 'streaming:perspective_calibrate[3]'
```

**Direkt setzen:**
```bash
rake 'streaming:perspective_set[3,50:20:W-50:20:W-30:H-30:30:H-30]'
```

### Konfiguration deployen

```bash
rake 'streaming:deploy[3]'
```

### Stream steuern

**Start/Stop/Restart:**
```bash
rails runner "StreamConfiguration.find_by(table_id: 3).start_streaming"
rails runner "StreamConfiguration.find_by(table_id: 3).stop_streaming"
rails runner "StreamConfiguration.find_by(table_id: 3).restart_streaming"
```

**Status prüfen:**
```bash
rails runner "
config = StreamConfiguration.find_by(table_id: 3)
puts \"Status: #{config.status}\"
puts \"Active: #{config.active?}\"
"
```

## Typischer Workflow

### 1. Nach Code-Änderungen

```bash
# Auf MacBook: Code ändern, commit, push
cd carambus_bcw
git add -A
git commit -m "Changes"
git push

# Auf Local Server: Pull und deployen
ssh user@192.168.2.210
cd /path/to/carambus_bcw
git pull
rake 'streaming:deploy[3]'
```

### 2. Kameraeinstellungen anpassen

```bash
# Auf Local Server
rake 'streaming:camera_calibrate[3]'
# Werte anpassen...
rake 'streaming:camera_save[3]'
rake 'streaming:deploy[3]'
rails runner "StreamConfiguration.find_by(table_id: 3).restart_streaming"
```

### 3. Trapezkorrektur anpassen

```bash
# Auf Local Server
rake 'streaming:perspective_calibrate[3]'
# Interaktiv anpassen...
rake 'streaming:deploy[3]'
rails runner "StreamConfiguration.find_by(table_id: 3).restart_streaming"
```

## Häufige Probleme

### "Authentication failed"
- SSH-Key nicht eingetragen → `rake streaming:ssh_test[3]`

### "Could not find table"
- Falsche Datenbank → Tasks auf Local Server ausführen

### "Connection refused"
- Stream läuft nicht → Status prüfen, neu starten

## Weitere Dokumentation

- [SSH Setup](./ssh-setup-for-streaming.md)
- [Where to Run Tasks](./where-to-run-rake-tasks.md)
- [Camera Calibration](./camera-calibration.md)
- [Perspective Correction](./perspective-correction.md)
- [Stream Control](./stream-control.md)

