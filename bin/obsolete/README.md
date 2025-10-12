# Obsolete Scripts Archive

Diese Scripts wurden durch neuere Implementierungen ersetzt und werden zur Archivierung aufbewahrt.

**⚠️ NICHT IN PRODUKTION VERWENDEN!**

Diese Scripts sind veraltet und sollten nicht mehr verwendet werden. Sie werden aus historischen Gründen aufbewahrt, aber könnten in Zukunft vollständig entfernt werden.

## Ersetzungen

| Obsoletes Script | Ersetzt durch | Grund |
|-----------------|---------------|-------|
| **Legacy Deployment** | | |
| `deploy.sh` | `deploy-scenario.sh` | Altes Deployment-System ohne Scenario-Support, nicht mehr kompatibel mit neuem Workflow |
| `deploy-to-raspberry-pi.sh` | `deploy-scenario.sh` | Integriert in neues Scenario-System mit automatischem Service-Management |
| **Obsolete Database-Sync** | | |
| `api2_dev_from_api2_db.sh` | `scenarios.rake` Tasks | Alte DB-Sync-Logik, jetzt in Scenario-System integriert |
| `dev_from_api_dev.sh` | `scenario:prepare_development` | Scenario-basierte Development-Setup |
| `pj_from_dev.sh` | `scenario:prepare_development` | Scenario-basierte Development-Setup |
| **Obsolete RasPi** | | |
| `quick-start-raspberry-pi.sh` | `setup-raspberry-pi.sh` | Vollständig ersetzt durch strukturiertes Setup-Script |
| `auto-setup-raspberry-pi.sh` | `setup-raspberry-pi.sh` | Duplikat-Funktionalität, konsolidiert in ein Script |
| `start_scoreboard` | `start-scoreboard.sh` | Alte Version ohne .sh Extension, inkonsistent |
| `start_scoreboard_delayed` | `autostart-scoreboard.sh` | Delay-Logik jetzt in Autostart-Script integriert |
| **Obsolete Hosting** | | |
| `render-build.sh` | N/A | Render.com-Hosting nicht mehr verwendet |
| `puma-wrapper.sh` | `manage-puma.sh` | Veraltete Service-Management-Logik |
| **Obsolete Sync** | | |
| `sync-carambus-folders.sh` | Git-Workflow | Durch Git-basiertes Deployment ersetzt |

## Wann wurden diese Scripts obsolet?

- **2024-09**: Scenario Management System vollständig überarbeitet
- **2024-10**: Deployment-Workflow standardisiert mit `deploy-scenario.sh`
- **2024-10**: Lokale-Daten-Preservation automatisiert
- **2024-10**: Script-Cleanup und Dokumentation

## Was tun, wenn Sie eines dieser Scripts benötigen?

1. **Prüfen Sie die Ersetzung**: Verwenden Sie das neue Script aus der Tabelle oben
2. **Dokumentation lesen**: 
   - [Deployment Workflow](../docs/deployment_workflow.de.md)
   - [Scenario Management](../docs/scenario_management.de.md)
   - [Raspberry Pi Scripts](../docs/raspberry_pi_scripts.de.md)
   - [Server Management Scripts](../docs/server_management_scripts.de.md)
3. **Bei Problemen**: Kontaktieren Sie das Entwicklerteam

## Migration von alten Scripts

### deploy.sh → deploy-scenario.sh

**Alt**:
```bash
./bin/deploy.sh
```

**Neu**:
```bash
# Vollständiger Workflow
./bin/deploy-scenario.sh carambus_location_5101 -y

# Oder Schritt-für-Schritt
rake "scenario:prepare_development[carambus_location_5101,development]"
rake "scenario:prepare_deploy[carambus_location_5101]"
rake "scenario:deploy[carambus_location_5101]"
```

### dev_from_api_dev.sh → Scenario Tasks

**Alt**:
```bash
./bin/dev_from_api_dev.sh
```

**Neu**:
```bash
rake "scenario:prepare_development[carambus_location_5101,development]"
```

### start_scoreboard → start-scoreboard.sh

**Alt**:
```bash
./bin/start_scoreboard
```

**Neu**:
```bash
./bin/start-scoreboard.sh [url]
```

## History

| Datum | Aktion | Details |
|-------|--------|---------|
| 2024-10-12 | Archivierung | Phase 3: Scripts in obsolete/ verschoben |
| 2024-10-12 | Dokumentation | Phase 2: Neue Docs für RasPi und Server Scripts |
| 2024-10-12 | Analyse | Phase 1: Script Cleanup Analysis erstellt |
| 2024-09 | Refactoring | Scenario Management System überarbeitet |

---

**Stand**: 2024-10-12  
**Status**: Archiviert (nicht für Production verwenden)



