# Script Cleanup Analysis - Carambus Project

**Datum**: 2025-01-12  
**Zweck**: Inventarisierung und Aufräumplan für Scripts im Carambus-Projekt

## Überblick

Das Projekt enthält Scripts an verschiedenen Orten:
- `carambus_data/scripts/` - 8 Scripts (Legacy-Location)
- `carambus_data/` (root) - 5 Scripts (Test/Ad-hoc)
- `carambus_master/bin/` - 60+ Scripts (Aktueller Standard)
- `carambus_bcw/bin/` - 60+ Scripts (Kopie von master)

## Hauptempfehlungen

1. **Scenario Management Scripts** von `carambus_data/scripts/` nach `carambus_master/bin/` verschieben
2. **Test/Ad-hoc Scripts** in `carambus_data/` entweder integrieren oder löschen
3. **Obsolete Scripts** in `carambus_master/bin/` markieren und archivieren
4. **MkDocs-Dokumentation** für alle wichtigen Scripts aktualisieren

---

## 1. Scripts in carambus_data/scripts/ (LEGACY LOCATION)

| Script | Zweck | Status | Empfehlung | Aktion |
|--------|-------|--------|------------|--------|
| `check_database_sync.sh` | DB-Synchronisation prüfen (generisch, scenario-basiert) | ✅ Wichtig | **VERSCHOBEN** → `carambus_master/bin/check_database_sync.sh` | ✅ Bereits verschoben und dokumentiert |
| `backup_bcw_local_data.sh` | Local wrapper für BCW-Backup | ⚠️ Obsolet | **LÖSCHEN** - Funktionalität in `scenarios.rake` integriert | Löschen nach Bestätigung |
| `backup_local_data_remote.sh` | Remote-Backup-Script (id>50M) | ⚠️ Obsolet | **LÖSCHEN** - Funktionalität in `scenarios.rake` integriert | Löschen nach Bestätigung |
| `backup_local_data_remote_clean.sh` | Remote-Backup mit Cleanup | ⚠️ Obsolet | **LÖSCHEN** - Funktionalität in `scenarios.rake` integriert | Löschen nach Bestätigung |
| `backup_local_data_remote_v2.sh` | Remote-Backup v2 | ⚠️ Obsolet | **LÖSCHEN** - Funktionalität in `scenarios.rake` integriert | Löschen nach Bestätigung |
| `filter_local_data.sh` | SQL-Dump filtern (id>50M) | ⚠️ Obsolet | **LÖSCHEN** - Funktionalität in `scenarios.rake` integriert | Löschen nach Bestätigung |
| `restore_bcw_local_data.sh` | Local wrapper für BCW-Restore | ⚠️ Obsolet | **LÖSCHEN** - Funktionalität in `scenarios.rake` integriert | Löschen nach Bestätigung |
| `restore_local_data_remote.sh` | Remote-Restore-Script | ⚠️ Obsolet | **LÖSCHEN** - Funktionalität in `scenarios.rake` integriert | Löschen nach Bestätigung |

**Zusammenfassung carambus_data/scripts/**:
- ✅ 1 Script verschoben → `carambus_master/bin/`
- ❌ 7 Scripts zu löschen (Funktionalität in `scenarios.rake` integriert)

---

## 2. Scripts in carambus_data/ (ROOT - TEST/AD-HOC)

| Script | Zweck | Status | Empfehlung | Aktion |
|--------|-------|--------|------------|--------|
| `check_database_states.sh` | DB-State-Verifikation für Tests | 🧪 Test | **ARCHIVIEREN** → `carambus_data/testing/` | Verschieben nach testing/ |
| `execute_sync_test.sh` | Sync-Workflow-Test | 🧪 Test | **ARCHIVIEREN** → `carambus_data/testing/` | Verschieben nach testing/ |
| `sync_api_production_to_development.sh` | API prod→dev sync | ⚠️ Ad-hoc | **INTEGRIEREN** - Funktionalität sollte in `scenarios.rake` sein | Prüfen und ggf. integrieren |
| `update_bcw_with_local_data_preservation.sh` | BCW-Update mit Local-Data-Preservation | ⚠️ Ad-hoc | **LÖSCHEN** - Durch `bin/deploy-scenario.sh` ersetzt | Löschen nach Bestätigung |
| `generate_scenario.rb` | Scenario-Generator (Ruby) | 🧪 Tool | **BEHALTEN** - Nützlich für neue Scenarios | Keine Aktion |

**Zusammenfassung carambus_data/ (root)**:
- 📁 2 Scripts nach `testing/` verschieben
- ❌ 2 Scripts zu löschen
- ✅ 1 Script behalten (Utility)

---

## 3. Scripts in carambus_master/bin/ - HAUPT-KATEGOR

ISierung

### 3.1 **Scenario Management** (Wichtig, dokumentiert)

| Script | Zweck | Dokumentiert | Status |
|--------|-------|--------------|--------|
| `deploy-scenario.sh` | Vollständiger Scenario-Deployment-Workflow | ✅ Ja (deployment_workflow.md) | ✅ Produktiv |
| `check_database_sync.sh` | DB-Synchronisation prüfen | ✅ Ja (database_syncing.md) | ✅ Produktiv |

### 3.2 **Raspberry Pi Management** (Wichtig, teilweise dokumentiert)

| Script | Zweck | Dokumentiert | Status |
|--------|-------|--------------|--------|
| `setup-raspberry-pi.sh` | RasPi komplett einrichten | ✅ Ja (client_only_installation.md) | ✅ Produktiv |
| `install-client-only.sh` | Client-Only-Installation | ✅ Ja (client_only_installation.md) | ✅ Produktiv |
| `install-scoreboard-client.sh` | Scoreboard-Client installieren | ⚠️ Teilweise | ✅ Produktiv |
| `setup-phillips-table-ssh.sh` | SSH für Phillips Table einrichten | ❌ Nein | ✅ Produktiv |
| `find-raspberry-pi.sh` | RasPi im Netzwerk finden | ❌ Nein | ✅ Utility |
| `test-raspberry-pi.sh` | RasPi-Tests | ❌ Nein | 🧪 Test |
| `test-raspberry-pi-restart.sh` | RasPi-Restart-Test | ❌ Nein | 🧪 Test |
| `quick-start-raspberry-pi.sh` | RasPi-Quick-Start | ❌ Nein | ⚠️ Obsolet? |
| `auto-setup-raspberry-pi.sh` | RasPi-Auto-Setup | ❌ Nein | ⚠️ Obsolet? |
| `prepare-sd-card.sh` | SD-Karte vorbereiten | ❌ Nein | ✅ Utility |

### 3.3 **Server Management** (Development/Production)

| Script | Zweck | Dokumentiert | Status |
|--------|-------|--------------|--------|
| `start-api-server.sh` | API-Server starten | ❌ Nein | ✅ Dev |
| `start-local-server.sh` | Local-Server starten | ❌ Nein | ✅ Dev |
| `start-both-servers.sh` | Beide Server starten | ❌ Nein | ✅ Dev |
| `manage-puma.sh` | Puma-Service managen | ⚠️ Intern | ✅ Produktiv |
| `manage-puma-api.sh` | Puma-API-Service managen | ⚠️ Intern | ✅ Produktiv |
| `restart-carambus.sh` | Carambus neustarten | ❌ Nein | ✅ Utility |
| `console-api.sh` | Rails Console (API) | ❌ Nein | ✅ Dev |
| `console-local.sh` | Rails Console (Local) | ❌ Nein | ✅ Dev |
| `console-production.sh` | Rails Console (Production) | ❌ Nein | ✅ Dev |
| `debug-production.sh` | Production debuggen | ❌ Nein | 🧪 Debug |

### 3.4 **Scoreboard/Kiosk** (Client-seitig)

| Script | Zweck | Dokumentiert | Status |
|--------|-------|--------------|--------|
| `start-scoreboard.sh` | Scoreboard starten | ❌ Nein | ✅ Produktiv |
| `autostart-scoreboard.sh` | Scoreboard Autostart | ✅ Ja (scoreboard_autostart_setup.md) | ✅ Produktiv |
| `restart-scoreboard.sh` | Scoreboard neustarten | ❌ Nein | ✅ Utility |
| `exit-scoreboard.sh` | Scoreboard beenden | ❌ Nein | ✅ Utility |
| `cleanup-chromium.sh` | Chromium-Cache bereinigen | ❌ Nein | ✅ Utility |
| `start_scoreboard` | Scoreboard starten (alt) | ❌ Nein | ⚠️ Obsolet? |
| `start_scoreboard_delayed` | Scoreboard mit Verzögerung | ❌ Nein | ⚠️ Obsolet? |

### 3.5 **Asset/Build Management**

| Script | Zweck | Dokumentiert | Status |
|--------|-------|--------------|--------|
| `rebuild_js.sh` | JavaScript neu bauen | ❌ Nein | ✅ Dev |
| `cleanup_rails.sh` | Rails-Cache bereinigen | ❌ Nein | ✅ Dev |
| `cleanup_versions.sh` | Versionen bereinigen | ❌ Nein | ⚠️ Spezial |

### 3.6 **Database/Sync** (Development-Tools)

| Script | Zweck | Dokumentiert | Status |
|--------|-------|--------------|--------|
| `api2_dev_from_api2_db.sh` | API2 dev von api2 DB | ❌ Nein | ⚠️ Obsolet? |
| `dev_from_api_dev.sh` | Dev von API dev | ❌ Nein | ⚠️ Obsolet? |
| `pj_from_dev.sh` | PJ von dev | ❌ Nein | ⚠️ Obsolet? |
| `get_versions.sh` | Versionen abrufen | ❌ Nein | 🧪 Debug |

### 3.7 **Deployment (Legacy/Spezial)**

| Script | Zweck | Dokumentiert | Status |
|--------|-------|--------------|--------|
| `deploy.sh` | Altes Deployment-Script | ❌ Nein | ⚠️ Obsolet (durch deploy-scenario.sh ersetzt) |
| `deploy-carambus_api-complete.sh` | API-Complete-Deployment | ❌ Nein | ⚠️ Spezial |
| `deploy-to-raspberry-pi.sh` | RasPi-Deployment | ❌ Nein | ⚠️ Obsolet? |
| `deploy-docs.sh` | Docs deployen (MkDocs) | ❌ Nein | ✅ Produktiv |

### 3.8 **Docker** (Optional/Trial)

| Script | Zweck | Dokumentiert | Status |
|--------|-------|--------------|--------|
| `build-docker-image.sh` | Docker-Image bauen | ❌ Nein | 🐳 Optional |
| `docker-examples.sh` | Docker-Beispiele | ❌ Nein | 🐳 Optional |
| `docker-entrypoint` | Docker-Entrypoint | ❌ Nein | 🐳 Optional |

### 3.9 **Utilities/Setup**

| Script | Zweck | Dokumentiert | Status |
|--------|-------|--------------|--------|
| `carambus-install.sh` | Carambus installieren | ❌ Nein | ✅ Setup |
| `setup-local-dev.sh` | Lokale Dev-Umgebung | ❌ Nein | ✅ Dev |
| `sync-carambus-folders.sh` | Carambus-Ordner syncen | ❌ Nein | ⚠️ Obsolet? |
| `test-startup.sh` | Startup testen | ❌ Nein | 🧪 Test |
| `generate-ssl-cert.sh` | SSL-Zertifikate generieren | ❌ Nein | ✅ Setup |
| `check-ip-literals.sh` | IP-Literals prüfen | ❌ Nein | 🧪 Dev |
| `backup-localization.sh` | I18n-Backup | ❌ Nein | ✅ Utility |
| `restore-localization.sh` | I18n-Restore | ❌ Nein | ✅ Utility |

### 3.10 **Rails Standard** (Von Rails generiert)

| Script | Status |
|--------|--------|
| `bundle`, `rails`, `rake`, `yarn`, `importmap`, `dev`, `update`, `kamal`, `brakeman`, `rubocop` | ✅ Standard (behalten) |

### 3.11 **Legacy/Render** (Hosting-spezifisch)

| Script | Status |
|--------|--------|
| `render-build.sh` | ⚠️ Obsolet (Render.com nicht mehr verwendet) |
| `puma-wrapper.sh` | ⚠️ Obsolet? (durch manage-puma.sh ersetzt) |

---

## Aktionsplan

### Phase 1: Sofort (Kritische Bereinigung)

1. **Scripts aus carambus_data/scripts/ löschen** (7 obsolete Scripts)
   ```bash
   cd carambus_data/scripts
   rm backup_bcw_local_data.sh
   rm backup_local_data_remote*.sh
   rm filter_local_data.sh
   rm restore_*_local_data*.sh
   ```

2. **Test-Scripts aus carambus_data/ verschieben**
   ```bash
   mkdir -p carambus_data/testing
   mv carambus_data/check_database_states.sh carambus_data/testing/
   mv carambus_data/execute_sync_test.sh carambus_data/testing/
   ```

3. **Ad-hoc Scripts aus carambus_data/ löschen**
   ```bash
   rm carambus_data/sync_api_production_to_development.sh
   rm carambus_data/update_bcw_with_local_data_preservation.sh
   ```

### Phase 2: Dokumentation (Hoch-Priorität)

**Zu dokumentieren in MkDocs:**

1. **Scenario Management** (Ergänzungen zu bestehenden Docs)
   - `bin/check_database_sync.sh` - ✅ Bereits dokumentiert (database_syncing.md)
   - `bin/deploy-scenario.sh` - ✅ Bereits dokumentiert (deployment_workflow.md)

2. **Raspberry Pi Management** (Neue Doku-Sektion)
   - Dokument erstellen: `docs/raspberry_pi_scripts.de.md`
   - Scripts: `setup-raspberry-pi.sh`, `install-client-only.sh`, `setup-phillips-table-ssh.sh`, `find-raspberry-pi.sh`

3. **Server Management** (Neue Doku-Sektion)
   - Dokument erstellen: `docs/server_management_scripts.de.md`
   - Scripts: `start-api-server.sh`, `start-local-server.sh`, `manage-puma.sh`, `console-*.sh`

4. **Scoreboard/Kiosk** (Ergänzung zu bestehenden Docs)
   - Erweitern: `docs/scoreboard_autostart_setup.de.md`
   - Scripts: `start-scoreboard.sh`, `restart-scoreboard.sh`, `exit-scoreboard.sh`

### Phase 3: Archivierung (Mittel-Priorität)

**Obsolete Scripts in carambus_master/bin/ markieren:**

1. Ordner erstellen:
   ```bash
   mkdir -p carambus_master/bin/obsolete
   ```

2. Verschieben:
   ```bash
   # Legacy Deployment
   mv bin/deploy.sh bin/obsolete/
   mv bin/deploy-to-raspberry-pi.sh bin/obsolete/
   
   # Obsolete Database-Sync
   mv bin/api2_dev_from_api2_db.sh bin/obsolete/
   mv bin/dev_from_api_dev.sh bin/obsolete/
   mv bin/pj_from_dev.sh bin/obsolete/
   
   # Obsolete RasPi
   mv bin/quick-start-raspberry-pi.sh bin/obsolete/
   mv bin/auto-setup-raspberry-pi.sh bin/obsolete/
   mv bin/start_scoreboard bin/obsolete/
   mv bin/start_scoreboard_delayed bin/obsolete/
   
   # Obsolete Hosting
   mv bin/render-build.sh bin/obsolete/
   mv bin/puma-wrapper.sh bin/obsolete/
   
   # Obsolete Sync
   mv bin/sync-carambus-folders.sh bin/obsolete/
   ```

3. README erstellen:
   ```bash
   cat > bin/obsolete/README.md << 'EOF'
   # Obsolete Scripts
   
   Diese Scripts wurden durch neuere Implementierungen ersetzt
   und werden zur Archivierung aufbewahrt.
   
   **NICHT IN PRODUKTION VERWENDEN!**
   
   | Script | Ersetzt durch |
   |--------|---------------|
   | deploy.sh | deploy-scenario.sh |
   | deploy-to-raspberry-pi.sh | deploy-scenario.sh |
   | puma-wrapper.sh | manage-puma.sh |
   | render-build.sh | N/A (Render.com nicht mehr verwendet) |
   | *_from_*.sh | scenarios.rake tasks |
   EOF
   ```

### Phase 4: Langfristig (Nice-to-have)

1. **Script-Kategorisierung in bin/**
   ```bash
   bin/
   ├── scenario/       # Scenario Management
   ├── raspberry_pi/   # RasPi-spezifisch
   ├── server/         # Server Management
   ├── scoreboard/     # Scoreboard/Kiosk
   ├── dev/            # Development-Tools
   └── obsolete/       # Archiv
   ```

2. **Master-README** erstellen (`bin/README.md`) mit Kategorien und kurzen Beschreibungen

3. **Alias-System** für häufige Befehle in `~/.bashrc`:
   ```bash
   alias cdeploy="carambus_master/bin/deploy-scenario.sh"
   alias ccheck="carambus_master/bin/check_database_sync.sh"
   alias csetup="carambus_master/bin/setup-raspberry-pi.sh"
   ```

---

## MkDocs Navigation Updates

**Neue Dokumente hinzufügen zu `mkdocs.yml`:**

```yaml
nav:
  - Scripts:
    - Scenario Management: 'scenario_management.de.md'
    - Database Syncing: 'database_syncing.de.md'
    - Deployment Workflow: 'deployment_workflow.de.md'
    - Raspberry Pi Scripts: 'raspberry_pi_scripts.de.md'  # NEU
    - Server Management Scripts: 'server_management_scripts.de.md'  # NEU
    - Scoreboard Autostart: 'scoreboard_autostart_setup.de.md'
```

---

## Zusammenfassung

### Scripts-Status

| Kategorie | Anzahl | Status |
|-----------|--------|--------|
| **carambus_data/scripts/** | 8 | 1 verschoben, 7 zu löschen |
| **carambus_data/ (root)** | 5 | 2 archivieren, 2 löschen, 1 behalten |
| **carambus_master/bin/ (produktiv)** | ~30 | Dokumentieren |
| **carambus_master/bin/ (obsolet)** | ~15 | Nach bin/obsolete/ |
| **carambus_master/bin/ (Rails Standard)** | ~10 | Behalten |

### Dokumentations-Lücken

| Priorität | Scripts | Aktion |
|-----------|---------|--------|
| ✅ Fertig | `deploy-scenario.sh`, `check_database_sync.sh` | Bereits dokumentiert |
| 🔴 Hoch | RasPi Management (10 Scripts) | Neue Doku erstellen |
| 🟡 Mittel | Server Management (10 Scripts) | Neue Doku erstellen |
| 🟢 Niedrig | Utilities (5 Scripts) | Optional dokumentieren |

### Nächste Schritte

1. ✅ **Sofort**: Obsolete Scripts aus `carambus_data/` löschen (dieser PR)
2. 📝 **Diese Woche**: RasPi-Doku und Server-Management-Doku erstellen
3. 📁 **Nächste Woche**: `bin/obsolete/` einrichten und Scripts verschieben
4. 🔄 **Monatlich**: Dokumentation aktuell halten

---

**Erstellt**: 2025-01-12  
**Letztes Update**: 2025-01-12  
**Status**: 🟡 In Arbeit - Phase 1 vorbereitet






