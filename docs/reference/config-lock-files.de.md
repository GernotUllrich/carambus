# Config Lock Files

## Übersicht

Mit dem Lock-File-Mechanismus können Sie Konfigurationsdateien auf einem Produktionsserver vor Überschreibung schützen, auch wenn `bin/deploy_scenario.sh [scenario_name]` ausgeführt wird.

## Funktionsweise

Wenn eine Datei `.lock` neben einer Konfigurationsdatei existiert, wird diese Konfigurationsdatei während des Deployments NICHT überschrieben.

### Beispiel

Auf dem Produktionsserver:
```bash
# Konfigurationsdatei vor Überschreibung schützen
touch /var/www/carambus_location_2459/shared/config/carambus.yml.lock
```

Beim nächsten Deployment wird `carambus.yml` übersprungen:
```
📤 Uploading configuration files to server...
   💡 Tip: Create a .lock file on server to prevent overwriting (e.g., carambus.yml.lock)
   ✅ Uploaded database.yml
   🔒 Skipped carambus.yml (locked on server)
   ✅ Uploaded nginx.conf
   ...
```

## Unterstützte Konfigurationsdateien

Der Lock-Mechanismus funktioniert für alle folgenden Dateien:

### Hauptkonfiguration
- `database.yml` → `database.yml.lock`
- `carambus.yml` → `carambus.yml.lock`
- `nginx.conf` → `nginx.conf.lock`
- `env.production` → `env.production.lock`

### Puma/Service-Konfiguration
- `puma.service` → `puma.service.lock`
- `puma.rb` → `puma.rb.lock`
- `production.rb` → `production.rb.lock`

### Credentials
- `credentials/production.yml.enc` → `credentials/production.yml.enc.lock`
- `credentials/production.key` → `credentials/production.key.lock`

## Verwendung

### Lock-Datei erstellen

Auf dem Produktionsserver als www-data:
```bash
# Einzelne Datei sperren
touch /var/www/[basename]/shared/config/carambus.yml.lock

# Mehrere Dateien sperren
cd /var/www/[basename]/shared/config
touch carambus.yml.lock database.yml.lock
```

### Lock-Datei entfernen

```bash
# Lock wieder entfernen
rm /var/www/[basename]/shared/config/carambus.yml.lock
```

### Lock-Status prüfen

```bash
# Alle Locks anzeigen
ls -la /var/www/[basename]/shared/config/*.lock
```

## Anwendungsfälle

### 1. Angepasste Produktionskonfiguration beibehalten
Sie haben `carambus.yml` auf dem Produktionsserver manuell angepasst (z.B. spezielle Einstellungen für diesen Server):
```bash
# Datei vor Überschreibung schützen
touch /var/www/carambus_location_2459/shared/config/carambus.yml.lock
```

### 2. Temporäre Test-Konfiguration
Sie testen eine neue Konfiguration und möchten nicht, dass sie beim nächsten Deploy überschrieben wird:
```bash
# Lock während der Testphase
touch /var/www/carambus_bcw/shared/config/database.yml.lock

# Nach erfolgreichem Test: Lock entfernen und normal deployen
rm /var/www/carambus_bcw/shared/config/database.yml.lock
```

### 3. Server-spezifische Credentials
Sie verwenden unterschiedliche Credentials auf verschiedenen Servern:
```bash
# Credentials nur einmal manuell kopieren und dann sperren
touch /var/www/carambus_location_2459/shared/config/credentials/production.key.lock
```

## Wichtige Hinweise

⚠️ **Wartung**: Lock-Dateien müssen manuell verwaltet werden. Das System entfernt sie NICHT automatisch.

⚠️ **Versionskontrolle**: Lock-Dateien werden NICHT ins Git-Repository eingecheckt. Sie existieren nur auf dem Produktionsserver.

⚠️ **Backup**: Gesperrte Konfigurationsdateien sollten separat gesichert werden, da sie nicht mehr Teil des Standard-Deployment-Prozesses sind.

💡 **Best Practice**: Dokumentieren Sie, welche Dateien auf welchen Servern gesperrt sind und warum.

## Technische Details

### Implementierung

Die Prüfung erfolgt in `lib/tasks/scenarios.rake`:

1. **Helper-Funktion `config_file_locked?`**: Prüft, ob eine `.lock`-Datei existiert
2. **Helper-Funktion `upload_config_file`**: Upload mit Lock-Check
3. **Upload-Prozess**: Alle Config-Files werden durch `upload_config_file` hochgeladen

### SSH-Kommandos

Der Lock-Check verwendet:
```ruby
ssh -p [port] www-data@[host] 'test -f [path].lock && echo locked || echo unlocked'
```

## Troubleshooting

### Lock wird nicht erkannt

```bash
# Prüfen, ob Lock-Datei existiert und richtige Permissions hat
ls -la /var/www/[basename]/shared/config/*.lock

# Lock-Datei sollte www-data gehören
sudo chown www-data:www-data /var/www/[basename]/shared/config/carambus.yml.lock
```

### Datei trotz Lock überschrieben

Prüfen Sie:
1. Ist die Lock-Datei am richtigen Ort?
2. Hat die Lock-Datei den exakt richtigen Namen? (muss `.lock` Suffix haben)
3. Sind SSH-Verbindung und Permissions korrekt?

## Siehe auch

- [Deployment-Prozess](DEPLOYMENT.md)
- [Szenario-Verwaltung](SCENARIOS.md)
- [Produktions-Setup](PRODUCTION_SETUP.md)

