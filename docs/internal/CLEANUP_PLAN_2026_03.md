# Dokumentations-Cleanup Plan - März 2026

## Ziel

Redundante und falsch platzierte UPPERCASE Dokumentations-Dateien aufräumen.

## Kategorisierung

### Kategorie A: Behalten (offizielle Docs)

Diese Dateien sind wichtig und bleiben (evtl. mit Umbenennung):

1. **`MKDOCS_DEVELOPMENT.md`** ✅ BEHALTEN
   - Haupt-Guide für MkDocs
   - Wurde gerade aktualisiert
   - Eventuell umbenennen zu `mkdocs-development.de.md`

2. **`README.de.md`** ✅ BEHALTEN
3. **`README.en.md`** ✅ BEHALTEN
   - Projekt-READMEs (wichtig für Übersicht)

### Kategorie B: Nach internal/ verschieben

Diese sind Implementation/Development Notes:

1. **`DATABASE_YML_TEST_SETUP.md`**
   → `internal/implementation-notes/database-yml-setup.md`

2. **`DOCUMENTATION_INDEX.md`**
   → `internal/archive/2026-03/documentation-index.md`

3. **`GOOGLE_CALENDAR_CREDENTIALS.md`**
   → `internal/implementation-notes/google-calendar-credentials.md`

4. **`INSTALL_WATCHDOG_BCW.md`**
   → `internal/implementation-notes/watchdog-bcw-install.md`

5. **`QUICK_START_BROWSER_WATCHDOG.md`**
   → `internal/implementation-notes/browser-watchdog-quickstart.md`

6. **`SCRAPING_MONITORING.md`**
   → `internal/implementation-notes/scraping-monitoring.md`

7. **`SCRAPING_MONITORING_QUICKSTART.md`**
   → `internal/implementation-notes/scraping-monitoring-quickstart.md`

8. **`UMB_PDF_PARSING.md`**
   → `internal/implementation-notes/umb-pdf-parsing.md`

### Kategorie C: In offizielle Docs integrieren (später)

Diese sollten in offizielle Dokumentation integriert werden:

1. **`GOOGLE_DOCS_ANLEITUNG.md`**
   → Inhalt integrieren in `administrators/external-tools.de.md` (neu)
   → Dann löschen

2. **`MONITORING_ARCHITECTURE.md`**
   → Inhalt integrieren in `developers/monitoring-architecture.de.md`
   → Mit EN Version
   → Dann löschen

### Kategorie D: Umbenennen (Naming Convention)

In Unterordnern:

1. **`reference/API.de.md`** → `reference/api.de.md`
2. **`reference/API.en.md`** → `reference/api.en.md`
3. **`changelog/CHANGELOG.de.md`** → `changelog/changelog.de.md`
4. **`changelog/CHANGELOG.en.md`** → `changelog/changelog.en.md`

### Kategorie E: README.md Dateien - BEHALTEN

Diese sind OK:
- `international/README.md` ✅
- `managers/AUTO_RESERVE_README.md` ✅
- `screenshots/README.md` ✅
- `studies/README.md` ✅
- `obsolete/README.md` ✅

---

## Ausführungsplan

### Phase 1: Nach internal/ verschieben (JETZT)

```bash
# Kategorie B: Development/Implementation Notes
mv docs/DATABASE_YML_TEST_SETUP.md docs/internal/implementation-notes/database-yml-setup.md
mv docs/DOCUMENTATION_INDEX.md docs/internal/archive/2026-03/documentation-index.md
mv docs/GOOGLE_CALENDAR_CREDENTIALS.md docs/internal/implementation-notes/google-calendar-credentials.md
mv docs/INSTALL_WATCHDOG_BCW.md docs/internal/implementation-notes/watchdog-bcw-install.md
mv docs/QUICK_START_BROWSER_WATCHDOG.md docs/internal/implementation-notes/browser-watchdog-quickstart.md
mv docs/SCRAPING_MONITORING.md docs/internal/implementation-notes/scraping-monitoring.md
mv docs/SCRAPING_MONITORING_QUICKSTART.md docs/internal/implementation-notes/scraping-monitoring-quickstart.md
mv docs/UMB_PDF_PARSING.md docs/internal/implementation-notes/umb-pdf-parsing.md
```

### Phase 2: Umbenennen (JETZT)

```bash
# Kategorie D: Naming Convention
mv docs/reference/API.de.md docs/reference/api.de.md
mv docs/reference/API.en.md docs/reference/api.en.md
mv docs/changelog/CHANGELOG.de.md docs/changelog/changelog.de.md
mv docs/changelog/CHANGELOG.en.md docs/changelog/changelog.en.md
```

### Phase 3: Links aktualisieren (NACH Phase 1+2)

```bash
# Links zu verschobenen Dateien finden und updaten
ruby bin/check-docs-links.rb --exclude-archives
```

### Phase 4: Integration vorbereiten (SPÄTER)

Für Kategorie C:
1. Content reviewen
2. In passende offizielle Docs integrieren
3. Original löschen

---

## Erwartete Ergebnisse

**Vorher:**
- 13 UPPERCASE .md Dateien in docs/ root
- Redundanz und Verwirrung
- Unklare Dokumentations-Struktur

**Nachher:**
- 3 UPPERCASE Dateien in docs/ root (nur READMEs + MKDOCS_DEVELOPMENT)
- Klare Struktur: Official vs Internal
- Naming Conventions eingehalten
- Weniger Redundanz

---

## Status

- [x] Phase 1: Nach internal/ verschieben ✅ **ERLEDIGT**
- [x] Phase 2: Umbenennen ✅ **ERLEDIGT**
- [x] Phase 3: Links aktualisieren ✅ **ERLEDIGT** (82 broken links in aktiven Docs)
- [ ] Phase 4: Integration (später) - **OPTIONAL**

---

## Finale Ergebnisse

**Vorher:** 13 UPPERCASE Dateien in docs/ root  
**Nachher:** 3 UPPERCASE Dateien in docs/ root (nur MKDOCS_DEVELOPMENT.md, README.de.md, README.en.md)

**Verbessert:**
- 10 Dateien nach internal/ verschoben
- 4 Dateien zu lowercase umbenannt
- 8 broken links weniger (90 → 82)
- 14 weniger aktive Dateien (bessere Struktur)

**Siehe:** `docs/internal/CLEANUP_SUMMARY_2026_03.md` für Details
