# Migration: Von table.number zu table_id

## Übersicht

Das Streaming-System wurde geändert, um `table_id` (Rails database ID) statt `table.number` (extrahierte Zahl aus dem Namen) zu verwenden. Dies macht das System eindeutig und vermeidet Verwirrung.

## Was hat sich geändert?

### Vorher (table.number):
- Service: `carambus-stream@7.service` (für "Tisch 7")
- Config: `/etc/carambus/stream-table-7.conf`
- Log: `/var/log/carambus/stream-table-7.log`

### Nachher (table_id):
- Service: `carambus-stream@3.service` (für table_id=3)
- Config: `/etc/carambus/stream-table-3.conf`
- Log: `/var/log/carambus/stream-table-3.log`

## Migration für bestehende Installationen

### Schritt 1: Alte Services stoppen

```bash
# Auf dem Raspberry Pi
sudo systemctl stop carambus-stream@7.service
sudo systemctl disable carambus-stream@7.service
```

### Schritt 2: Neue Konfiguration deployen

```bash
# Auf dem Local Server
cd /path/to/carambus_bcw
rake 'streaming:deploy[3]'
```

Dies erstellt die neue Config-Datei mit `table_id` (z.B. `stream-table-3.conf`).

### Schritt 3: Alte Dateien aufräumen (optional)

```bash
# Auf dem Raspberry Pi
sudo rm /etc/carambus/stream-table-7.conf  # Alte Config
sudo rm /var/log/carambus/stream-table-7.log  # Alte Logs (optional)
```

### Schritt 4: Service neu starten

```bash
# Auf dem Local Server
rails runner "StreamConfiguration.find_by(table_id: 3).start_streaming"
```

Oder manuell:

```bash
# Auf dem Raspberry Pi
sudo systemctl start carambus-stream@3.service
```

## Automatische Migration (Script)

```bash
#!/bin/bash
# migrate-streaming-to-table-id.sh

TABLE_ID=3
OLD_TABLE_NUMBER=7

echo "Migrating streaming setup from table number to table_id..."
echo "Table ID: $TABLE_ID"
echo "Old table number: $OLD_TABLE_NUMBER"

# Stop old service
sudo systemctl stop carambus-stream@${OLD_TABLE_NUMBER}.service
sudo systemctl disable carambus-stream@${OLD_TABLE_NUMBER}.service

# Backup old config
if [ -f "/etc/carambus/stream-table-${OLD_TABLE_NUMBER}.conf" ]; then
    sudo cp /etc/carambus/stream-table-${OLD_TABLE_NUMBER}.conf /etc/carambus/stream-table-${OLD_TABLE_NUMBER}.conf.backup
fi

# Deploy new config (from Local Server)
# This will create /etc/carambus/stream-table-${TABLE_ID}.conf

echo "✅ Migration complete!"
echo "New service: carambus-stream@${TABLE_ID}.service"
```

## Prüfen der Migration

```bash
# Auf dem Raspberry Pi
ls -la /etc/carambus/stream-table-*.conf
# Sollte zeigen: stream-table-3.conf (nicht mehr stream-table-7.conf)

sudo systemctl status carambus-stream@3.service
# Sollte den neuen Service zeigen
```

## Rollback (falls nötig)

Falls Sie zurückrollen müssen:

```bash
# Auf dem Raspberry Pi
sudo systemctl stop carambus-stream@3.service
sudo mv /etc/carambus/stream-table-7.conf.backup /etc/carambus/stream-table-7.conf
sudo systemctl start carambus-stream@7.service
```

## Vorteile der Änderung

1. **Eindeutigkeit**: `table_id` ist immer eindeutig, `table.number` kann mehrdeutig sein
2. **Konsistenz**: Verwendet die gleiche ID wie die Datenbank
3. **Keine Verwirrung**: Keine Frage mehr, ob es die Zahl aus dem Namen oder die ID ist
4. **Zukunftssicher**: Funktioniert auch wenn Tische anders benannt werden

## Weitere Informationen

- [Streaming Architecture](../developers/streaming-architecture.de.md)
- [Where to Run Tasks](./where-to-run-rake-tasks.md)

