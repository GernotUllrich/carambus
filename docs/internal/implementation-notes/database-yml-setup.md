# Test-Datenbank Konfiguration für alle Carambus-Instanzen

## Problem

Die `config/database.yml` Dateien haben keine Test-Umgebung konfiguriert, was zu diesem Fehler führt:

```
ActiveRecord::AdapterNotSpecified: The `test` database is not configured for the `test` environment.
```

## Lösung

Fügen Sie die Test-Konfiguration zu jeder `database.yml` hinzu.

## Für jede Carambus-Instanz:

### carambus_master

**Datei:** `carambus_master/config/database.yml`

```yaml
---
default: &default
  adapter: postgresql
  encoding: unicode
  pool: 5

development:
  <<: *default
  database: carambus_bcw_development

test:
  <<: *default
  database: carambus_bcw_test
```

### carambus_bcw

**Datei:** `carambus_bcw/config/database.yml`

```yaml
---
default: &default
  adapter: postgresql
  encoding: unicode
  pool: 5

development:
  <<: *default
  database: carambus_bcw_development

test:
  <<: *default
  database: carambus_bcw_test
```

### carambus_api

**Datei:** `carambus_api/config/database.yml`

```yaml
---
default: &default
  adapter: postgresql
  encoding: unicode
  pool: 5

development:
  <<: *default
  database: carambus_api_development

test:
  <<: *default
  database: carambus_api_test
```

### carambus_pbv

**Datei:** `carambus_pbv/config/database.yml`

```yaml
---
default: &default
  adapter: postgresql
  encoding: unicode
  pool: 5

development:
  <<: *default
  database: carambus_pbv_development

test:
  <<: *default
  database: carambus_pbv_test
```

### carambus_phat

**Datei:** `carambus_phat/config/database.yml`

```yaml
---
default: &default
  adapter: postgresql
  encoding: unicode
  pool: 5

development:
  <<: *default
  database: carambus_phat_development

test:
  <<: *default
  database: carambus_phat_test
```

## Schnell-Anleitung

Für jede Instanz, fügen Sie diese Zeilen nach dem `development:` Block hinzu:

```yaml
test:
  <<: *default
  database: carambus_[INSTANZ]_test
```

Ersetzen Sie `[INSTANZ]` mit:
- `bcw` für carambus_master und carambus_bcw
- `api` für carambus_api
- `pbv` für carambus_pbv
- `phat` für carambus_phat

## Nach der Änderung

1. **Test-Datenbank erstellen:**
   ```bash
   cd carambus_master  # oder andere Instanz
   RAILS_ENV=test bundle exec rails db:create
   RAILS_ENV=test bundle exec rails db:schema:load
   ```

2. **Tests ausführen:**
   ```bash
   RAILS_ENV=test bundle exec rails test test/models/tournament_auto_reserve_test.rb
   RAILS_ENV=test bundle exec rails test test/tasks/auto_reserve_tables_test.rb
   ```

## Warum ist database.yml in .gitignore?

Die `config/database.yml` Datei ist absichtlich in `.gitignore`, da sie:
- Lokale Datenbankverbindungen enthält
- Potenziell sensible Credentials enthalten kann
- Auf jedem System unterschiedlich sein kann

**Wichtig:** Diese Änderungen müssen auf **jedem System separat** vorgenommen werden!

## Alternative: database.yml.example

Sie können eine Beispiel-Datei erstellen:

```bash
# In jedem Carambus-Verzeichnis
cp config/database.yml config/database.yml.example
git add config/database.yml.example
git commit -m "Add database.yml.example with test configuration"
```

Dann kann jeder Entwickler:
```bash
cp config/database.yml.example config/database.yml
# Anpassen für lokale Umgebung
```

---

**Version:** 1.0  
**Datum:** 19. Januar 2026  
**Gilt für:** Alle Carambus-Instanzen
