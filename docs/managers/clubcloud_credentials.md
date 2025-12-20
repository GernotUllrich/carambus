# ClubCloud Credentials Setup

## Überblick

ClubCloud-Zugangsdaten werden **lokal und verschlüsselt** in Rails Credentials gespeichert, **NICHT** in der `region_ccs` Tabelle (die mit dem API-Server synchronisiert wird).

## Vorteile

- ✅ **Sicher**: Credentials sind verschlüsselt und lokal
- ✅ **Nicht synchronisiert**: Keine Verbreitung über API-Server
- ✅ **Pro-Environment**: Unterschiedliche Credentials für Development/Production
- ✅ **Versionskontrolle**: Key-File bleibt lokal (in `.gitignore`)

## Setup

### Development Environment

```bash
# 1. Credentials bearbeiten
EDITOR=nano rails credentials:edit --environment development

# 2. Folgendes hinzufügen:
clubcloud:
  nbv:
    username: "your-email@example.com"
    password: "your-password"
  # Weitere Regionen bei Bedarf:
  # dbu:
  #   username: "..."
  #   password: "..."

# 3. Speichern und schließen (Ctrl+O, Enter, Ctrl+X in nano)
```

### Production Environment

```bash
# Auf dem Production Server (z.B. bc-wedel.duckdns.org)
ssh -p 8910 www-data@bc-wedel.duckdns.org
cd /var/www/carambus_bcw/current

# Credentials bearbeiten
EDITOR=nano RAILS_ENV=production bundle exec rails credentials:edit --environment production

# Gleiche Struktur wie oben hinzufügen
```

## Datei-Struktur

Nach dem Setup existieren folgende Dateien:

```
config/
├── credentials/
│   ├── development.key          # Lokal, NICHT committen! (in .gitignore)
│   ├── development.yml.enc      # Verschlüsselt, kann committet werden
│   ├── production.key           # Auf Server, NICHT committen!
│   └── production.yml.enc       # Verschlüsselt, kann committet werden
```

## Verwendung im Code

```ruby
# Credentials werden automatisch geholt
credentials = Setting.get_cc_credentials("nbv")
# => { username: "...", password: "..." }

# Login verwendet automatisch die Credentials
Setting.login_to_cc
```

## Migration von RegionCc

Falls du bereits Credentials in `region_ccs.username` und `region_ccs.userpw` hast:

1. **Notiere die Werte**:
   ```ruby
   rc = RegionCc.find_by(context: "nbv")
   puts "Username: #{rc.username}"
   puts "Password: #{rc.userpw}"
   ```

2. **In Rails Credentials eintragen** (siehe Setup oben)

3. **RegionCc-Felder leeren** (optional, für Sicherheit):
   ```ruby
   rc = RegionCc.find_by(context: "nbv")
   rc.unprotected = true
   rc.username = nil
   rc.userpw = nil
   rc.save!
   ```

## Fallback-Mechanismus

Der Code unterstützt einen Fallback für Rückwärtskompatibilität:
1. **Primär**: Rails Credentials (`config/credentials/`)
2. **Fallback**: RegionCc-Tabelle (mit Warnung im Log)

## Troubleshooting

### "No ClubCloud credentials found"

**Problem**: Credentials sind nicht konfiguriert.

**Lösung**:
```bash
rails credentials:edit --environment development
# Füge clubcloud-Section hinzu (siehe Setup oben)
```

### "Key is missing or invalid"

**Problem**: Die `.key` Datei fehlt oder ist ungültig.

**Lösung Development**:
```bash
# Key-File neu generieren (ACHTUNG: Alte Credentials gehen verloren!)
rm config/credentials/development.key config/credentials/development.yml.enc
rails credentials:edit --environment development
```

**Lösung Production**:
```bash
# Key-File vom Backup wiederherstellen ODER
# Credentials neu anlegen (siehe oben)
```

### Key-File Backup

**Wichtig**: Sichere die `.key` Files!

```bash
# Development
cp config/credentials/development.key ~/carambus_credentials_backup/

# Production (auf Server)
cp config/credentials/production.key ~/carambus_credentials_backup/
```

## Sicherheit

- ✅ `.key` Files sind in `.gitignore` und werden **NICHT** committet
- ✅ `.yml.enc` Files sind verschlüsselt und können committet werden
- ✅ Credentials werden **NICHT** zwischen Servern synchronisiert
- ✅ Jedes Environment hat eigene Credentials
- ⚠️ **NIEMALS** `.key` Files in Git committen!
- ⚠️ **NIEMALS** `.key` Files per Email/Chat teilen!

## Weiterführende Links

- [Rails Credentials Guide](https://edgeguides.rubyonrails.org/security.html#custom-credentials)
- [Rails Encrypted Credentials](https://edgeapi.rubyonrails.org/classes/Rails/Application.html#method-i-credentials)

