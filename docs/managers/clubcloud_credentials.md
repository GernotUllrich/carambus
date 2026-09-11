# ClubCloud Credentials Setup (geteilter Region-Admin-Zugang)

> **Abgrenzung:** Dieses Dokument beschreibt den **geteilten, region-weiten**
> Admin-Zugang (`clubcloud.<context>` in Rails Credentials). Den **persönlichen,
> per-User**-ClubCloud-Zugang (v1.1, hinterlegt im Profil) beschreiben:
> [`clubcloud-eigener-zugang.de.md`](clubcloud-eigener-zugang.de.md) (Endnutzer) ·
> [`../developers/per-user-cc-identitaet.de.md`](../developers/per-user-cc-identitaet.de.md) (Technik).

## Überblick

ClubCloud-Zugangsdaten werden **lokal und verschlüsselt** in Rails Credentials gespeichert, **NICHT** in der `region_ccs` Tabelle (die mit dem API-Server synchronisiert wird).

## Vorteile

- ✅ **Sicher**: Credentials sind verschlüsselt und lokal
- ✅ **Nicht synchronisiert**: Keine Verbreitung über API-Server
- ✅ **Pro-Environment**: Unterschiedliche Credentials für Development/Production
- ✅ **Versionskontrolle**: weder `.key` noch `.yml.enc` liegen im Repo (beide in `.gitignore`); die Produktions-Dateien kommen aus `carambus_data/scenarios/<szenario>/production/credentials/`

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

In Produktion werden die Credentials **nicht auf dem Server editiert**. `prepare_deploy` lädt
`production.key` und `production.yml.enc` aus `carambus_data/scenarios/<szenario>/production/credentials/`
hoch und überschreibt dabei Änderungen am Server.

1. ClubCloud-Login in `carambus_data/secrets.yml` eintragen (nicht versioniert), Kontext kleingeschrieben:
   ```yaml
   shared:
     clubcloud:
       nbv:
         username: "your-email@example.com"
         password: "your-password"
   # oder nur für ein Szenario: per_scenario: { <szenario>: { clubcloud: { nbv: { ... } } } }
   ```
2. In `carambus_data/scenarios/<szenario>/config.yml` das Feature freischalten:
   ```yaml
   scenario:
     credentials:
       features: [ai, translation, clubcloud]
       clubcloud_context: NBV
   ```
3. Credentials erzeugen und ausrollen (aus einem carambus-Checkout):
   ```bash
   # Probelauf (zeigt nur die Key-Struktur), dann schreiben
   bin/rails "scenario:generate_credentials[<szenario>,production]"
   WRITE=true bin/rails "scenario:generate_credentials[<szenario>,production]"

   # auf den Server bringen: beim nächsten prepare_deploy, oder gezielt
   WRITE=true RESTART=true bin/rails "scenario:push_credentials[<szenario>]"
   ```

`generate_credentials` setzt voraus, dass `production.key` bereits existiert.

!!! warning "Herkunft von `production.key` für ein neues Szenario"
    Kein Task erzeugt den Schlüssel, und `carambus_data` versioniert `scenarios/*/production/` nicht.
    Woher ein neuer Verein seinen `production.key` bekommt, ist noch nicht geregelt; siehe
    [Installations-Übersicht](../administrators/installation-overview.md#voraussetzungen).

## Datei-Struktur

Nach dem Setup existieren folgende Dateien:

```
config/credentials/                       # im Checkout (Development)
├── development.key          # lokal, NICHT committen (in .gitignore)
└── development.yml.enc      # verschlüsselt, ebenfalls NICHT committen (in .gitignore)

carambus_data/scenarios/<szenario>/production/credentials/   # Quelle für Produktion (nicht versioniert)
├── production.key
└── production.yml.enc

/var/www/<basename>/shared/config/credentials/               # auf dem Server, von prepare_deploy hochgeladen
├── production.key
└── production.yml.enc
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
Den passenden `production.key` nach `carambus_data/scenarios/<szenario>/production/credentials/` legen
(aus dem Backup) und `prepare_deploy` erneut ausführen. Ein neu erzeugter Key kann die vorhandene
`production.yml.enc` nicht mehr lesen.

### Key-File Backup

**Wichtig**: Sichere die `.key` Files!

```bash
# Development
cp config/credentials/development.key ~/carambus_credentials_backup/

# Production (Quelle auf dem Admin-Rechner)
cp ~/DEV/carambus/carambus_data/scenarios/<szenario>/production/credentials/production.key ~/carambus_credentials_backup/
```

## Sicherheit

- ✅ `.key` Files sind in `.gitignore` und werden **NICHT** committet
- ✅ `.yml.enc` Files sind ebenfalls in `.gitignore` (seit `6260afa6`) und werden **NICHT** committet
- ✅ Credentials werden **NICHT** zwischen Servern synchronisiert
- ✅ Jedes Environment hat eigene Credentials
- ⚠️ **NIEMALS** `.key` Files in Git committen!
- ⚠️ **NIEMALS** `.key` Files per Email/Chat teilen!

## Weiterführende Links

- [Rails Credentials Guide](https://edgeguides.rubyonrails.org/security.html#custom-credentials)
- [Rails Encrypted Credentials](https://edgeapi.rubyonrails.org/classes/Rails/Application.html#method-i-credentials)

