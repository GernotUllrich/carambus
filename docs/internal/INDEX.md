# Internal Documentation - Index

**Status:** Archiv & Interne Notizen  
**Zielgruppe:** Entwickler-Team  
**Letzte Aktualisierung:** Februar 2026

## Übersicht

Dieses Verzeichnis enthält interne Entwicklungsnotizen, Bug-Fix-Dokumentation, Implementierungsdetails und historische Analysen.

**Hinweis:** Für aktuelle Entwickler-Dokumentation siehe: [`docs/developers/`](../developers/index.de.md)

## Struktur

```
internal/
├── bug-fixes/              # Bug-Fix-Dokumentation
├── implementation-notes/   # Feature-Implementierungsdetails
├── performance-analysis/   # Performance-Messungen & Analysen
└── archive/               # Historisches Archiv
    ├── 2026-01/          # Januar 2026
    ├── testing-2025/     # Test-Analysen aus 2025
    └── chat-status-docs-2025/  # Alte Chat-Status-Dokumentation
```

## Bug-Fixes

Detaillierte Dokumentation zu behobenen Bugs:

### Critical Fixes
- **[Parameter Migration Fix](bug-fixes/parameter-migration-fix.de.md)** - Boolean-Parameter konnten nicht auf `false` gesetzt werden
- **[Party Monitor Reflex Fix](bug-fixes/PARTY_MONITOR_REFLEX_FIX.md)** - Reflex-Fehler in Party Monitor
- **[Tournament Monitor Groups Fix](bug-fixes/TOURNAMENT_MONITOR_GROUPS_FIX.md)** - Gruppen-Anzeigefehler

### Action Cable & WebSocket
- **[ActionCable Redis Fix](bug-fixes/ACTIONCABLE_REDIS_FIX.md)** - Redis-Verbindungsprobleme
- **[Tournament Scores Broadcast Fix](bug-fixes/TOURNAMENT_SCORES_BROADCAST_FIX.md)** - Score-Update-Broadcasting
- **[Fast Path Score Update](bug-fixes/FAST_PATH_SCORE_UPDATE.md)** - Optimierung der Score-Updates

### UI & Scoreboard
- **[Blank Table Scores Bug Fix](bug-fixes/BLANK_TABLE_SCORES_BUG_FIX.md)** - Leere Tisch-Scores
- **[Game Protocol Modal Implementation](bug-fixes/GAME_PROTOCOL_MODAL_IMPLEMENTATION.md)** - Protokoll-Modal

### Server & Deployment
- **[API Server Cable Optimization](bug-fixes/API_SERVER_CABLE_OPTIMIZATION.md)** - Cable-Performance
- **[API Server Upcoming Tournaments](bug-fixes/API_SERVER_UPCOMING_TOURNAMENTS.md)** - Turnier-Anzeige
- **[Force Reload Tournament](bug-fixes/FORCE_RELOAD_TOURNAMENT.md)** - Turnier-Reload-Logik

### Analysis
- **[Empty String Job Analysis](bug-fixes/EMPTY_STRING_JOB_ANALYSIS.md)** - Analyse leerer Job-Parameter
- **[Client Console Capture](bug-fixes/CLIENT_CONSOLE_CAPTURE.md)** - Client-seitige Fehleranalyse

### Configuration
- **[Admin Settings Configuration](bug-fixes/ADMIN_SETTINGS_CONFIGURATION.md)** - Admin-Einstellungen
- **[Admin Settings Implementation Summary](bug-fixes/ADMIN_SETTINGS_IMPLEMENTATION_SUMMARY.md)** - Implementierungsübersicht

## Implementation Notes

Feature-Implementierungen und technische Details:

### Scoreboard & UI
- **[Scoreboard Documentation Complete](implementation-notes/SCOREBOARD_DOCUMENTATION_COMPLETE.md)** - Vollständige Scoreboard-Doku
- **[Scoreboard Mix-Up Fix](implementation-notes/SCOREBOARD_MIX_UP_FIX.md)** - Verwechslungsfehler
- **[Scoreboard User Guide Summary](implementation-notes/SCOREBOARD_USER_GUIDE_SUMMARY.md)** - Benutzerhandbuch

### Tournament Wizard
- **[Tournament Wizard Improvements Plan](implementation-notes/TOURNAMENT_WIZARD_IMPROVEMENTS_PLAN.md)** - Verbesserungsplan
- **[Tournament Wizard Review Schema](implementation-notes/TOURNAMENT_WIZARD_REVIEW_SCHEMA.md)** - Schema-Review
- **[Tournament Wizard Technical](implementation-notes/TOURNAMENT_WIZARD_TECHNICAL.md)** - Technische Details
- **[Tournament Wizard UI Test](implementation-notes/TOURNAMENT_WIZARD_UI_TEST.md)** - UI-Tests

### WebSocket & Real-time
- **[WebSocket Connection Health Monitoring](implementation-notes/WEBSOCKET_CONNECTION_HEALTH_MONITORING.md)** - Health Checks
- **[WebSocket Health Monitoring Summary](implementation-notes/WEBSOCKET_HEALTH_MONITORING_SUMMARY.md)** - Zusammenfassung
- **[WebSocket Lifecycle Analysis](implementation-notes/WEBSOCKET_LIFECYCLE_ANALYSIS.md)** - Lifecycle-Analyse

### Data Management
- **[Seeding List Auto-Extraction](implementation-notes/SEEDING_LIST_AUTO_EXTRACTION.md)** - Automatische Setzlisten

### Cleanup & Maintenance
- **[Script Cleanup Analysis](implementation-notes/SCRIPT_CLEANUP_ANALYSIS.md)** - Script-Aufräumung

### Feature Implementations
- **[Automatische Tischreservierung](implementation-notes/auto-table-reservation.de.md)** - Tischreservierungs-Feature
- **[Tournament Wizard Scroll Position](implementation-notes/TOURNAMENT_WIZARD_SCROLL_POSITION.md)** - Scroll-Position speichern

## Performance Analysis

Performance-Messungen und Optimierungsanalysen:

- **[Performance Measurement Guide](performance-analysis/PERFORMANCE_MEASUREMENT_GUIDE.md)** - Anleitung zum Messen
- **[Raspberry Pi Connection Testing Guide](performance-analysis/RASPI_CONNECTION_TESTING_GUIDE.md)** - RasPi-Tests
- **[Scoreboard Architecture](performance-analysis/SCOREBOARD_ARCHITECTURE.md)** - Scoreboard-Architektur

## Archive

### 2026-01 (Januar 2026)

Email-Konfiguration (konsolidiert in [`docs/developers/setup/email-configuration.de.md`](../developers/setup/email-configuration.de.md)):
- `EMAIL_CONFIGURATION_FIX.md` - Original Fix-Dokumentation
- `QUICK_FIX_EMAIL.md` - Quick-Fix-Anleitung
- `GMAIL_SETUP_SUMMARY.md` - Gmail-Setup-Zusammenfassung
- `changes-summary-2026-01.md` - Änderungszusammenfassung

### testing-2025 (Test-Analysen 2025)

Test-Pläne, Analysen und Zusammenfassungen aus 2025:

**Analysis:**
- `ISSUE_ANALYSIS.md` - Issue-Analysen
- `REDUNDANT_FILES_TO_DELETE.md` - Redundante Dateien

**Plans:**
- `TEST_PLAN_ID_BASED_FILTERING.md` - ID-basiertes Filtering

**Summaries:**
- `duplicate_leagues_summary.md` - Liga-Duplikate
- `FIX_SUMMARY.md` - Fix-Zusammenfassung
- `league_scraping_fix_summary.md` - Liga-Scraping-Fixes
- `TESTING_SUMMARY.md` - Test-Zusammenfassung

### chat-status-docs-2025 (Alte Chat-Dokumentation)

Historische Chat-Status-Dokumentation aus 2025:
- `BROWSER_TESTING_GUIDE.md`
- `CONTRIBUTING.md`
- `CURRENT_STATE_ANALYSIS.md`
- `DEPLOYMENT.md`
- `DEPLOYMENT_ARCHITECTURE_PLAN.md`
- `DOCUMENTATION_CLEANUP_PLAN.md`
- `FRESH_SD_TEST_CHECKLIST.md`
- `IMPLEMENTATION_LESSONS.md`
- `IMPLEMENTATION_STATUS.md`
- `INTEGRATED_DOCUMENTATION_README.md`
- `ITERATIVE_DEVELOPMENT_WORKFLOW.md`
- `MKDOCS_SETUP_STATUS.md`
- `PROJECT_STRUCTURE.md`
- `README.de.md`
- `README.md`
- `SCENARIO_SYSTEM_IMPLEMENTATION.md`
- `SCENARIO_SYSTEM_SUMMARY.md`
- `SCOREBOARD_DEBUGGING_GUIDE.md`
- `SERVER_SETUP_NOTE.md`
- `TODO.md`

## Verwendung

### Für aktuelle Entwicklung

Verwende die organisierte Dokumentation in `docs/developers/`:
- **Setup:** [`docs/developers/setup/`](../developers/setup/)
- **Debugging:** [`docs/developers/debugging/`](../developers/debugging/)
- **Testing:** [`docs/developers/testing/`](../developers/testing/)
- **Operations:** [`docs/developers/operations/`](../developers/operations/)

### Für historischen Kontext

Dieses `internal/`-Verzeichnis bietet:
- **Bug-Fix-Details** für spätere Referenz
- **Implementierungsnotizen** für Feature-Hintergrund
- **Performance-Analysen** für Optimierungen
- **Archiv** für historischen Kontext

## Siehe auch

- [Developer Documentation](../developers/index.de.md) - Aktuelle Entwickler-Doku
- [Administrator Documentation](../administrators/index.de.md) - Admin-Dokumentation
- [Changelog](../../CHANGELOG.md) - Öffentliches Changelog

---

**Hinweis:** Dieses Verzeichnis ist für interne Zwecke. Öffentliche Dokumentation gehört in die entsprechenden Zielgruppen-Verzeichnisse (`developers/`, `administrators/`, etc.).
