# Dokumentations-Index: Internationale Turniere & UMB Integration

**Letzte Aktualisierung:** 19. Februar 2026  
**Szenario:** carambus_api (Development)

---

## 📚 Aktuelle Dokumentation

### 🎯 Haupt-Dokumente (Start hier)

| Dokument | Zweck | Status |
|----------|-------|--------|
| **INTERNATIONAL_VIEWS_IMPROVEMENTS_COMPLETE.md** | ✅ **AKTUELL** - View-Verbesserungen (Table, Filter, Disziplinen) | ✅ Fertig |
| **INTERNATIONAL_STI_VIEWS_COMPLETE.md** | ✅ Finaler Status nach View-Überarbeitung | ✅ Fertig |
| **VIEWS_ANALYSIS_INTERNATIONAL_STI.md** | Detaillierte View-Analyse, Probleme und Fixes | ✅ Referenz |

### 🏗️ STI-Migration

| Dokument | Zweck | Status |
|----------|-------|--------|
| **UMB_STI_MIGRATION_SUCCESS.md** | Erfolgreicher Abschluss der STI-Migration | ✅ Historie |
| **UMB_MIGRATION_TO_STI_COMPLETE.md** | Details zur STI-Implementierung | ✅ Historie |
| **UMB_STI_COMPLETE.md** | STI-Migrations-Zusammenfassung | ✅ Historie |

### 📄 PDF Parsing & Scraping

| Dokument | Zweck | Status |
|----------|-------|--------|
| **UMB_PDF_PARSING.md** | **WICHTIG** - PDF Parsing Referenz (GroupResults → Games) | ✅ Aktiv |
| UMB_SCRAPER_COMPLETE.md | Scraper-Abschluss | ⚠️ Überprüfen |
| UMB_SCRAPER_READY.md | Scraper bereit für Einsatz | ⚠️ Überprüfen |
| UMB_SCRAPER_SUMMARY.md | Scraper-Übersicht | ⚠️ Überprüfen |
| UMB_SCRAPING_PLAN.md | Scraping-Plan | 📦 Evtl. archivieren |
| UMB_SCRAPING_STATUS.md | Scraping-Status | 📦 Evtl. archivieren |
| UMB_SEQUENTIAL_SCRAPING_COMPLETE.md | Sequential Scraping | ⚠️ Überprüfen |
| UMB_PHASE2_COMPLETE.md | Phase 2 abgeschlossen | ⚠️ Überprüfen |
| UMB_PDF_GAME_NOTES.md | Notizen zum PDF Game Parsing | ⚠️ Überprüfen |

### 🎥 Video-System

| Dokument | Zweck | Status |
|----------|-------|--------|
| **VIDEO_SYSTEM_COMPLETE.md** | **WICHTIG** - Polymorphes Video-System Referenz | ✅ Aktiv |
| VIDEO_SYSTEM_REDESIGN.md | Video-System Redesign | ⚠️ Überprüfen |
| VIDEO_MIGRATION_COMPLETE.md | Video-Migration | ⚠️ Überprüfen |
| VIDEO_TRANSLATION_SETUP.md | Video-Übersetzungen | ⚠️ Überprüfen |
| PRODUCTION_VIDEO_MIGRATION.md | Production Migration | ⚠️ Überprüfen |

### 🚀 Deployment

| Dokument | Zweck | Status |
|----------|-------|--------|
| UMB_DEPLOYMENT_CHECKLIST.md | Deployment-Checkliste | ⚠️ Überprüfen |

---

## 📦 Archivierte Dokumente

### Veraltete Planungs-Dokumente

**Speicherort:** `docs/archive/2026-02-pre-sti/`

| Dokument | Grund | Archiviert am |
|----------|-------|---------------|
| INTERNATIONAL_TO_STI_MIGRATION_PLAN.md | Plan umgesetzt, Migration abgeschlossen | 19.02.2026 |
| INTERNATIONAL_EXTENSION_COMPLETE.md | Beschreibt altes System vor STI | 19.02.2026 |

**Siehe:** `docs/archive/2026-02-pre-sti/README.md` für Details

---

## 🗺️ Schnellnavigation

### Ich möchte wissen wie...

#### ...internationale Turniere funktionieren (STI)
→ **INTERNATIONAL_STI_VIEWS_COMPLETE.md** - Kompletter Überblick

#### ...PDFs geparst werden
→ **docs/UMB_PDF_PARSING.md** - Parsing-Referenz

#### ...das Video-System funktioniert
→ **VIDEO_SYSTEM_COMPLETE.md** - Polymorphe Videos

#### ...die Views aufgebaut sind
→ **VIEWS_ANALYSIS_INTERNATIONAL_STI.md** - View-Analyse

#### ...die Migration durchgeführt wurde
→ **UMB_STI_MIGRATION_SUCCESS.md** - Migrations-Historie

---

## 📝 Dokumentations-Richtlinien

### Status-Labels

| Label | Bedeutung |
|-------|-----------|
| ✅ Aktiv | Aktuelles, gültiges Dokument |
| ✅ Fertig | Abgeschlossene Arbeit, finale Version |
| ✅ Referenz | Wichtige Referenz-Dokumentation |
| ✅ Historie | Historisches Dokument (für Nachvollziehbarkeit) |
| ⚠️ Überprüfen | Sollte überprüft/aktualisiert werden |
| 📦 Archivieren | Kann archiviert werden (veraltet) |

### Namenskonventionen

- `*_COMPLETE.md` - Abschluss-Dokumente (Feature fertig)
- `*_PLAN.md` - Planungs-Dokumente (vor Umsetzung)
- `*_STATUS.md` - Status-Updates (laufende Arbeiten)
- `*_ANALYSIS.md` - Analyse-Dokumente
- `*_SUMMARY.md` - Zusammenfassungen

---

## 🧹 Aufräum-Empfehlungen

### Nächste Schritte:

1. **UMB_SCRAPER_* Dokumente prüfen:**
   - Sind diese noch aktuell nach STI-Migration?
   - Ggf. zu einem "UMB_SCRAPING_COMPLETE.md" konsolidieren?

2. **VIDEO_* Dokumente prüfen:**
   - Sind REDESIGN und MIGRATION noch relevant?
   - Ggf. archivieren, nur SYSTEM_COMPLETE behalten?

3. **PLAN/STATUS Dokumente:**
   - UMB_SCRAPING_PLAN.md → archivieren?
   - UMB_SCRAPING_STATUS.md → archivieren?

4. **Neue Master-Dokumente erstellen:**
   - `UMB_INTEGRATION_GUIDE.md` - Kompletter Guide
   - `INTERNATIONAL_TOURNAMENTS_README.md` - Entwickler-Guide

---

## 💡 Empfohlene Lese-Reihenfolge (für neue Entwickler)

1. **INTERNATIONAL_STI_VIEWS_COMPLETE.md** - Start hier! Kompletter Überblick
2. **docs/UMB_PDF_PARSING.md** - Wie PDFs geparst werden
3. **VIDEO_SYSTEM_COMPLETE.md** - Wie Videos funktionieren
4. **VIEWS_ANALYSIS_INTERNATIONAL_STI.md** - View-Details
5. **UMB_STI_MIGRATION_SUCCESS.md** - Historischer Kontext

---

## 📞 Weitere Ressourcen

### Code-Referenzen:

```
app/models/international_tournament.rb       # STI Model
app/controllers/international/               # Controller
app/views/international/                     # Views
app/services/umb_scraper_v2.rb              # Scraper
```

### Tests:

```bash
# Start Server
rails server

# Test URLs
http://localhost:3000/international
http://localhost:3000/international/tournaments
http://localhost:3000/international/tournaments/:id
http://localhost:3000/international/videos
```

### Rails Console:

```ruby
# Tournaments prüfen
Tournament.international.count
Tournament.international.official_umb.count

# Videos prüfen
Video.youtube.count
Video.for_tournaments.count

# Games prüfen
Game.where(tournament_type: 'InternationalTournament').count
```

---

**Zuletzt aktualisiert:** 19. Februar 2026  
**Verantwortlich:** Development Team  
**Fragen?** Siehe Haupt-Dokumente oben
