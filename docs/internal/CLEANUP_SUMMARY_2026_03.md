# Dokumentations-Cleanup - Zusammenfassung März 2026

**Datum:** 17. März 2026  
**Status:** ✅ Abgeschlossen  
**Ziel:** Redundante UPPERCASE Dateien aufräumen und Dokumentations-Regeln etablieren

---

## Was wurde gemacht

### 1. Neue Regel erstellt ✅

**Datei:** `.cursor/rules/documentation-management.md`

**Inhalt:**
- ❌ Keine neuen UPPERCASE .md Dateien in docs/ (außer internal/)
- ❌ Keine Dokumentation in Rails.root
- ✅ Work-in-Progress → docs/internal/
- ✅ Nach Testing → Offizielle Docs aktualisieren
- ✅ Naming: lowercase-with-dashes.LANG.md

### 2. Tools erstellt ✅

1. **`bin/check-docs-links.rb`** - Link Checker
   - Option: `--exclude-archives`
   - Findet broken links
   - Macht Vorschläge

2. **`bin/fix-docs-links.rb`** - Automatischer Fixer
   - 16 automatische Fixes
   - Dry-run Mode

3. **`bin/test-docs-structure.sh`** - Strukturtests
   - 17 Tests
   - Alle passing ✅

### 3. Dateien verschoben ✅

**Phase 1: Nach internal/ verschoben (10 Dateien)**

```bash
docs/DATABASE_YML_TEST_SETUP.md           → internal/implementation-notes/database-yml-setup.md
docs/DOCUMENTATION_INDEX.md               → internal/archive/2026-03/documentation-index.md
docs/DOCUMENTATION_SYSTEM.md              → internal/link-checking/documentation-system-notes.md
docs/FIXING_DOCUMENTATION_LINKS.md        → internal/link-checking/fixing-links-guide.md
docs/GOOGLE_CALENDAR_CREDENTIALS.md       → internal/implementation-notes/google-calendar-credentials.md
docs/GOOGLE_DOCS_ANLEITUNG.md             → internal/implementation-notes/google-docs-anleitung.md
docs/INSTALL_WATCHDOG_BCW.md              → internal/implementation-notes/watchdog-bcw-install.md
docs/MONITORING_ARCHITECTURE.md           → internal/implementation-notes/monitoring-architecture.md
docs/QUICK_START_BROWSER_WATCHDOG.md      → internal/implementation-notes/browser-watchdog-quickstart.md
docs/SCRAPING_MONITORING.md               → internal/implementation-notes/scraping-monitoring.md
docs/SCRAPING_MONITORING_QUICKSTART.md    → internal/implementation-notes/scraping-monitoring-quickstart.md
docs/UMB_PDF_PARSING.md                   → internal/implementation-notes/umb-pdf-parsing.md
```

**Phase 2: Umbenannt zu lowercase (4 Dateien)**

```bash
docs/reference/API.de.md          → docs/reference/api.de.md
docs/reference/API.en.md          → docs/reference/api.en.md
docs/changelog/CHANGELOG.de.md    → docs/changelog/changelog.de.md
docs/changelog/CHANGELOG.en.md    → docs/changelog/changelog.en.md
```

### 4. Dokumentation aktualisiert ✅

**Neue Docs:**
- `docs/internal/README.md` - Guide für internal/ Ordner
- `docs/internal/link-checking/README.md` - Implementation Notes
- `docs/internal/CLEANUP_PLAN_2026_03.md` - Dieser Plan
- `docs/internal/CLEANUP_SUMMARY_2026_03.md` - Diese Zusammenfassung

**Aktualisiert:**
- `docs/MKDOCS_DEVELOPMENT.md` - Neue Regeln Sektion hinzugefügt
- `mkdocs.yml` - API.md → api.md

### 5. View-Dateien gefixt ✅

**Datei:** `app/views/static/docs_page.html.erb`
- GitHub Pages Links → lokale `/docs/` Links
- Trailing slashes entfernt
- Falsche Pfade korrigiert (scoreboard_autostart_setup → scoreboard-autostart)

**Datei:** `app/helpers/application_helper.rb`
- `mkdocs_link` Helper aktualisiert für lokale Links

---

## Ergebnisse

### Vorher (Start)

```
docs/ root:
  13 UPPERCASE .md Dateien
  Viele redundante Docs
  Unklare Struktur
  
Link Status:
  323 Dateien
  124 broken links (all)
  117 broken links (original count)
```

### Nachher (Jetzt)

```
docs/ root:
  3 UPPERCASE .md Dateien (nur wichtige: MKDOCS_DEVELOPMENT, README.de, README.en)
  Klare Struktur
  Dokumentations-Regeln etabliert
  
Link Status:
  177 aktive Dateien (14 weniger durch cleanup)
  82 broken links (8 weniger!)
  
Struktur Tests:
  17/17 passed ✅
```

### Verbesserungen

| Metrik | Vorher | Nachher | Änderung |
|--------|--------|---------|----------|
| UPPERCASE in docs/ root | 13 | 3 | -10 (-77%) ✅ |
| Aktive Dateien | 191 | 177 | -14 ✅ |
| Broken Links (aktiv) | 90 | 82 | -8 (-9%) ✅ |
| Dokumentations-Regeln | 0 | 1 | +1 ✅ |
| Cleanup Tools | 0 | 3 | +3 ✅ |

---

## Verbleibende Arbeit

### Sofort (empfohlen)

1. **Automatische Link-Fixes anwenden**
   ```bash
   ruby bin/fix-docs-links.rb --live
   ```
   → Fixt weitere ~16 Links

2. **MkDocs neu bauen**
   ```bash
   bundle exec rake mkdocs:deploy
   ```

### Mittelfristig

1. **Restliche 66 broken Links manuell fixen**
   - Guide: `docs/internal/link-checking/fixing-links-guide.md`
   - Priorität: players/ (34 links), developers/ (23 links)

2. **Screenshots hinzufügen**
   - Viele Links zu fehlenden Screenshots
   - In entsprechende Ordner committen

3. **Internal/ weiter aufräumen**
   - Alte UPPERCASE Dateien in internal/implementation-notes/
   - Nach archive/ verschieben oder löschen

### Optional

1. **MKDOCS_DEVELOPMENT.md umbenennen**
   ```bash
   mv docs/MKDOCS_DEVELOPMENT.md docs/mkdocs-development.de.md
   # + EN Version erstellen
   ```

2. **Integration Kategorie C**
   - MONITORING_ARCHITECTURE → developers/monitoring-architecture.de.md
   - GOOGLE_DOCS_ANLEITUNG → administrators/external-tools.de.md

---

## Lessons Learned

### ✅ Was funktioniert hat

1. **Systematischer Ansatz**
   - Erst analysieren, dann kategorisieren, dann ausführen
   - Tools bauen für Automatisierung

2. **Klare Regeln**
   - .cursor/rules/ für dauerhafte Richtlinien
   - Dokumentiert und nachvollziehbar

3. **Internal/ Konzept**
   - Klare Trennung: Work-in-Progress vs Official
   - Erlaubt schnelle Notizen während Entwicklung
   - Integration später

### ❌ Was zu vermeiden ist

1. **Neue Docs ohne Check**
   - Immer erst existierende Docs prüfen
   - Fragen ob Update besser ist

2. **UPPERCASE in docs/**
   - Nur in internal/ erlaubt
   - Official docs: lowercase-with-dashes

3. **Redundanz**
   - Ein Thema = Ein offizielles Dokument
   - Updates statt neue Dateien

---

## Nächste Schritte

```bash
# 1. Links automatisch fixen
ruby bin/fix-docs-links.rb --live

# 2. Prüfen
ruby bin/check-docs-links.rb --exclude-archives

# 3. Neu bauen
bundle exec rake mkdocs:deploy

# 4. Testen
./bin/test-docs-structure.sh

# 5. Committen
git status
git add .
git commit -m "docs: Cleanup UPPERCASE files and establish documentation rules

- Moved 10 UPPERCASE files from docs/ to docs/internal/
- Renamed 4 files to lowercase (api, changelog)
- Created documentation management rules in .cursor/rules/
- Updated MKDOCS_DEVELOPMENT.md with new workflow
- Created link checking tools (check/fix/test)
- Reduced broken links from 90 to 82 in active docs

See: docs/internal/CLEANUP_SUMMARY_2026_03.md
"
```

---

## Dateien zum Review

**Neue Regeln:**
- `.cursor/rules/documentation-management.md`

**Aktualisierte Guides:**
- `docs/MKDOCS_DEVELOPMENT.md`
- `docs/internal/README.md`

**Implementation Notes:**
- `docs/internal/CLEANUP_PLAN_2026_03.md`
- `docs/internal/CLEANUP_SUMMARY_2026_03.md` (diese Datei)
- `docs/internal/link-checking/README.md`

**Tools:**
- `bin/check-docs-links.rb`
- `bin/fix-docs-links.rb`
- `bin/test-docs-structure.sh`

---

**Status:** ✅ Cleanup erfolgreich durchgeführt  
**Impact:** Sauberere Struktur, weniger Redundanz, klare Regeln  
**Maintenance:** Wesentlich einfacher durch Tools und Guidelines
