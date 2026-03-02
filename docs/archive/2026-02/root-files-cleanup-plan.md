# Root Files Cleanup Plan - 2026-03-02

## Analyse der .md und .rb Dateien im Root-Verzeichnis

Nach Durchsicht aller .md und .rb Dateien im Root-Verzeichnis wurde folgende Kategorisierung vorgenommen:

---

## 📚 BEHALTEN & IN OFFIZIELLE DOCS ÜBERTRAGEN

### Entwickler-Dokumentation (→ docs/developers/)

1. **SCENARIO_WORKFLOW.md** → `docs/developers/scenario-workflow.md`
   - ✅ Wichtig: Git-Workflow für Multi-Scenario-Setup
   - Langfristig relevant für alle Entwickler

2. **RUBYMINE_SETUP.md** → `docs/developers/rubymine-setup.md`
   - ✅ IDE Setup Guide
   - Hilfreich für neue Entwickler

3. **FIXTURE_SAMMLUNG_ANLEITUNG.md** → `docs/developers/testing/fixture-collection-guide.md`
   - ✅ Vollständige Anleitung für Test-Fixtures
   - Teil der Testing-Strategie

4. **TESTING.md** → `docs/developers/testing/testing-quickstart.md`
   - ✅ Test Quick Start Guide
   - Ergänzt bestehende Test-Dokumentation

### Deployment-Dokumentation (→ docs/developers/deployment/)

5. **UMB_SCRAPING_PLAN.md** → `docs/developers/umb-scraping-implementation.md`
   - ✅ Detaillierter Plan für UMB Historical Data Scraping
   - Aktuell in Entwicklung (letzte Änderung: 2026-03-02)
   - Wichtig für zukünftige Implementierung

6. **UMB_SCRAPING_METHODS.md** → `docs/developers/umb-scraping-methods.md`
   - ✅ Dokumentiert verschiedene Scraping-Ansätze
   - Technische Referenz

---

## 🗄️ ARCHIVIEREN (→ docs/archive/)

### Implementation Summaries (bereits abgeschlossen)

7. **VIDEO_SYSTEM_COMPLETE.md** → `docs/archive/2026-02/video-system-complete.md`
   - Status: ✅ Abgeschlossen (2026-02-22)
   - Dokumentiert abgeschlossene Video-System Implementation

8. **VIDEO_MIGRATION_COMPLETE.md** → `docs/archive/2026-02/video-migration-complete.md`
   - Status: ✅ Abgeschlossen
   - Migration von international_videos zu universal videos

9. **VIDEO_SYSTEM_REDESIGN.md** → `docs/archive/2026-02/video-system-redesign.md`
   - Status: ✅ Abgeschlossen
   - Design-Entscheidungen für Video-System

10. **VIDEO_TAGGING_SYSTEM.md** → `docs/archive/2026-02/video-tagging-system.md`
    - Status: ✅ Implementiert
    - Video Tagging Feature

11. **VIDEO_TAGGING_FRONTEND.md** → `docs/archive/2026-02/video-tagging-frontend.md`
    - Status: ✅ Implementiert
    - Frontend für Video Tags

12. **VIDEO_TAGGING_AND_LOGIC.md** → `docs/archive/2026-02/video-tagging-logic.md`
    - Status: ✅ Implementiert
    - Tag-Detection-Logik

13. **VIDEO_TRANSLATION_SETUP.md** → `docs/archive/2026-02/video-translation-setup.md`
    - Status: ✅ Implementiert
    - Video-Übersetzungs-Setup

### UMB Scraper Implementation

14. **UMB_MIGRATION_TO_STI_COMPLETE.md** → `docs/archive/2026-02/umb-migration-to-sti.md`
    - Status: ✅ Abgeschlossen

15. **UMB_SCRAPER_COMPLETE.md** → `docs/archive/2026-02/umb-scraper-complete.md`
    - Status: ✅ Abgeschlossen

16. **UMB_SCRAPER_READY.md** → `docs/archive/2026-02/umb-scraper-ready.md`
    - Status: ✅ Abgeschlossen

17. **UMB_SCRAPER_SUMMARY.md** → `docs/archive/2026-02/umb-scraper-summary.md`
    - Status: ✅ Abgeschlossen

18. **UMB_SCRAPER_IMPROVEMENTS.md** → `docs/archive/2026-02/umb-scraper-improvements.md`
    - Status: ✅ Abgeschlossen

19. **UMB_SCRAPER_AUTO_CREATE.md** → `docs/archive/2026-02/umb-scraper-auto-create.md`
    - Status: ✅ Abgeschlossen

20. **UMB_SEQUENTIAL_SCRAPING_COMPLETE.md** → `docs/archive/2026-02/umb-sequential-scraping.md`
    - Status: ✅ Abgeschlossen

21. **UMB_PHASE2_COMPLETE.md** → `docs/archive/2026-02/umb-phase2-complete.md`
    - Status: ✅ Abgeschlossen

22. **UMB_STI_COMPLETE.md** → `docs/archive/2026-02/umb-sti-complete.md`
    - Status: ✅ Abgeschlossen

23. **UMB_STI_MIGRATION_SUCCESS.md** → `docs/archive/2026-02/umb-sti-migration-success.md`
    - Status: ✅ Abgeschlossen

24. **UMB_UPDATE_SUMMARY.md** → `docs/archive/2026-02/umb-update-summary.md`
    - Status: ✅ Abgeschlossen

25. **UMB_PDF_GAME_NOTES.md** → `docs/archive/2026-02/umb-pdf-game-notes.md`
    - Status: ✅ Notizen zu PDF-Handling

### International/STI Views Implementation

26. **INTERNATIONAL_STI_VIEWS_COMPLETE.md** → `docs/archive/2026-02/international-sti-views-complete.md`
    - Status: ✅ Abgeschlossen

27. **INTERNATIONAL_VIEWS_BUGFIXES.md** → `docs/archive/2026-02/international-views-bugfixes.md`
    - Status: ✅ Abgeschlossen

28. **INTERNATIONAL_VIEWS_FINAL_STATUS.md** → `docs/archive/2026-02/international-views-final.md`
    - Status: ✅ Abgeschlossen

29. **INTERNATIONAL_VIEWS_IMPROVEMENTS.md** → `docs/archive/2026-02/international-views-improvements.md`
    - Status: ✅ Abgeschlossen

30. **INTERNATIONAL_VIEWS_IMPROVEMENTS_COMPLETE.md** → `docs/archive/2026-02/international-views-improvements-complete.md`
    - Status: ✅ Abgeschlossen

31. **VIEWS_ANALYSIS_INTERNATIONAL_STI.md** → `docs/archive/2026-02/views-analysis-international-sti.md`
    - Status: ✅ Abgeschlossen

### Placeholder Records System

32. **PLACEHOLDER_FIRST_ISSUE_FIX.md** → `docs/archive/2026-02/placeholder-first-issue-fix.md`
    - Status: ✅ Bug fix dokumentiert

33. **PLACEHOLDER_RECORDS_SYSTEM.md** → `docs/archive/2026-02/placeholder-records-system.md`
    - Status: ✅ System dokumentiert

### Incomplete Records

34. **INCOMPLETE_RECORDS_IMPROVEMENTS.md** → `docs/archive/2026-02/incomplete-records-improvements.md`
    - Status: ✅ Abgeschlossen

### Monitoring & Testing

35. **MONITORING_SYSTEM.md** → `docs/archive/2026-02/monitoring-system.md`
    - Status: ✅ Monitoring implementiert

36. **MONITORING_DEPLOYMENT_SUMMARY.md** → `docs/archive/2026-02/monitoring-deployment.md`
    - Status: ✅ Deployment dokumentiert

37. **TEST_FINAL.md** → `docs/archive/2026-02/test-final.md`
    - Status: ✅ Test-Ergebnisse

38. **TEST_ERFOLG.md** → `docs/archive/2026-02/test-erfolg.md`
    - Status: ✅ Test-Erfolge dokumentiert

39. **TEST_SETUP_SUMMARY.md** → `docs/archive/2026-02/test-setup-summary.md`
    - Status: ✅ Test-Setup dokumentiert

40. **INSTALL_TESTS.md** → `docs/archive/2026-02/install-tests.md`
    - Status: ✅ Installation Tests

41. **QUICKSTART_TESTS.md** → `docs/archive/2026-02/quickstart-tests.md`
    - Status: ✅ Quick Start Tests

### Other Implementation Summaries

42. **ADMIN_INTERFACE_FIX.md** → `docs/archive/2026-02/admin-interface-fix.md`
    - Status: ✅ Bug fix dokumentiert

43. **IMPLEMENTATION_STATUS.md** → `docs/archive/2026-02/implementation-status.md`
    - Status: ✅ Status-Snapshot

44. **IMPLEMENTATION_SUMMARY.md** → `docs/archive/2026-02/implementation-summary.md`
    - Status: ✅ Zusammenfassung

45. **CREDENTIALS_INTEGRATION_COMPLETE.md** → `docs/archive/2026-02/credentials-integration.md`
    - Status: ✅ Abgeschlossen

46. **PRODUCTION_VIDEO_MIGRATION.md** → `docs/archive/2026-02/production-video-migration.md`
    - Status: ✅ Migration dokumentiert

47. **SCOREBOARD_MESSAGES_SUMMARY.md** → `docs/archive/2026-02/scoreboard-messages.md`
    - Status: ✅ Feature dokumentiert

48. **YOUTUBE_SCRAPER_SETUP.md** → `docs/archive/2026-02/youtube-scraper-setup.md`
    - Status: ✅ Setup dokumentiert

49. **MKDOCS_SETUP_SUMMARY.md** → `docs/archive/2026-02/mkdocs-setup.md`
    - Status: ✅ MkDocs Setup

50. **CHANGELOG_UMB_SCRAPER.md** → `docs/archive/2026-02/changelog-umb-scraper.md`
    - Status: ✅ Changelog für UMB Scraper

51. **OBS_STREAMING_SETUP.md** → `docs/archive/2026-02/obs-streaming-setup.md`
    - Status: ✅ OBS Setup (veraltet, neuere Docs in docs/administrators/)

### Next Steps / TODO Files

52. **NEXT_STEPS.md** → `docs/archive/2026-02/next-steps-2026-02.md`
    - Status: 📅 Zeitpunkt-spezifisch (Feb 2026)
    - Kann archiviert werden

53. **FRONTEND_MIGRATION_TODO.md** → `docs/developers/frontend-sti-migration.md`
    - Status: ⚠️ TEILWEISE - TODO für STI Frontend Migration
    - **Entscheidung:** Nach docs/developers/ als Arbeits-Dokumentation

54. **PULL_AND_TEST_ON_API.md** → `docs/archive/2026-02/pull-and-test-api.md`
    - Status: 📅 Zeitpunkt-spezifisch
    - Deployment-Notizen

---

## 🧪 TEST SCRIPTS (→ docs/testing/ oder scripts/testing/)

### Ad-hoc Test Scripts

55. **find_korean_channel.rb** → LÖSCHEN
    - ❌ Temporäres Test-Script für URL-Decoding
    - Keine langfristige Relevanz

56. **test_regex.rb** → LÖSCHEN
    - ❌ Temporäres Test-Script für Regex-Pattern
    - Keine langfristige Relevanz

57. **test_umb_organizer.rb** → LÖSCHEN
    - ❌ Temporäres Diagnostic-Script
    - Funktionalität jetzt in regulären Tests

58. **test_video_tagging.rb** → LÖSCHEN
    - ❌ Temporäres Test-Script
    - Funktionalität in regulären Tests

59. **import_cuesco.rb** → `scripts/import/import_cuesco.rb`
    - ✅ Import-Script für Cuesco Tournament Data
    - Könnte noch gebraucht werden für ähnliche Imports
    - **Entscheidung:** Nach scripts/import/ verschieben

---

## 🗑️ LÖSCHEN

### HTML Files (temporär)

60. **cuesco_202.html** → LÖSCHEN
    - ❌ Temporäre HTML-Datei für Import
    - Wird von import_cuesco.rb gelesen, aber nicht mehr benötigt

---

## 📊 STATISTIK

### Zu behalten (Root bleibt sauber)
- **CHANGELOG.md** ✅ Bleibt im Root (Standard-Datei)

### In docs/developers/ übertragen: 6 Dateien
- SCENARIO_WORKFLOW.md
- RUBYMINE_SETUP.md
- FIXTURE_SAMMLUNG_ANLEITUNG.md
- TESTING.md
- UMB_SCRAPING_PLAN.md
- UMB_SCRAPING_METHODS.md
- FRONTEND_MIGRATION_TODO.md (als Arbeits-Dokumentation)

### In docs/archive/2026-02/ archivieren: 48 Dateien
- Alle abgeschlossenen Implementation Summaries
- Alle abgeschlossenen Migration-Dokumente
- Zeitpunkt-spezifische Status-Dokumente

### In scripts/ verschieben: 1 Datei
- import_cuesco.rb → scripts/import/

### Zu löschen: 5 Dateien
- 4 temporäre Test-Scripts (.rb)
- 1 temporäre HTML-Datei

---

## 🎯 ZUSAMMENFASSUNG

| Kategorie | Anzahl | Aktion |
|-----------|--------|--------|
| Behalten im Root | 1 | CHANGELOG.md |
| → docs/developers/ | 7 | Übertragen |
| → docs/archive/2026-02/ | 48 | Archivieren |
| → scripts/ | 1 | Verschieben |
| Löschen | 5 | Entfernen |
| **GESAMT** | **62** | **Dateien** |

---

## ✅ NÄCHSTE SCHRITTE

1. Verzeichnis-Struktur erstellen
2. Dateien übertragen mit Git (mv)
3. Dateien löschen
4. mkdocs.yml aktualisieren
5. Git commit

