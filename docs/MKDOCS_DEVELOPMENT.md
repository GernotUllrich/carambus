# MkDocs Development Guide

Aktualisiert: März 2026

## 🎯 Quick Start

### Lokale Vorschau (empfohlen)

```bash
# Live-Preview starten (kein site/ Verzeichnis wird generiert)
mkdocs serve

# ODER via Rails Rake Task
bundle exec rake mkdocs:serve

# Browser öffnen
open http://127.0.0.1:8000
```

**Vorteile:**
- ✅ Änderungen werden sofort sichtbar (Live-Reload)
- ✅ Kein `site/` Verzeichnis auf der Festplatte
- ✅ Schnell und effizient

---

## 🏗️ Dokumentations-Architektur

Carambus hat **zwei Dokumentationssysteme**, die zusammenarbeiten:

### 1. MkDocs Static Site (`/docs/*`)
- Vollständige MkDocs-Website mit Theme, Suche und Navigation
- Gebaut aus `docs/` → `site/` → `public/docs/`
- Erreichbar unter: `/docs/` oder `https://gernotullrich.github.io/carambus`
- Verwendet Material Theme

### 2. Rails-Rendered Docs (`/docs_page/*`)
- Markdown mit Rails-Layout integriert
- Direkt aus `docs/`-Dateien gerendert
- Erreichbar unter: `/docs_page/index`
- Gleicher Inhalt, anderes Layout

**Workflow:**
```
docs/*.md (Quelle)
    ↓
├─→ MkDocs Build → public/docs/ (HTML)
└─→ Rails Controller → Direkt als Markdown
```

---

## 📦 Setup (einmalig)

### 1. Python & Dependencies installieren

```bash
# Python 3.11+ erforderlich
python3 --version

# Dependencies installieren
pip install -r requirements.txt
```

### 2. requirements.txt (bereits vorhanden)

```txt
mkdocs-material>=9.5.0
mkdocs-static-i18n>=1.0.0
pymdown-extensions>=10.0.0
```

---

## 🚀 Workflow

### Lokale Entwicklung

```bash
# 1. Live-Preview starten
mkdocs serve
# Oder: bundle exec rake mkdocs:serve

# 2. Dokumentation bearbeiten
vim docs/developers/my-doc.de.md

# 3. Browser aktualisiert automatisch
```

### Build & Deploy (lokal)

```bash
# Dokumentation bauen und in public/docs/ kopieren
bundle exec rake mkdocs:build

# ODER: Kompletter Deploy (clean + build)
bundle exec rake mkdocs:deploy

# ODER: Nur aufräumen
bundle exec rake mkdocs:clean
```

**Was passiert:**
1. `mkdocs build` → Generiert `site/`
2. Kopiert `site/` → `public/docs/`
3. Jetzt via Rails verfügbar unter `/docs/`

### Deployment (automatisch via GitHub)

```bash
# 1. Änderungen committen
git add docs/
git commit -m "Update documentation"
git push origin master

# 2. GitHub Actions buildet & deployed automatisch
# Siehe: .github/workflows/build-docs.yml

# 3. Nach ~2 Minuten verfügbar unter:
# https://GernotUllrich.github.io/carambus
```

---

## 🔍 Link-Checking (NEU!)

Nach der Reorganisation in Unterordner (players/, managers/, etc.) müssen viele Links aktualisiert werden.

### Links überprüfen

```bash
# Alle Dokumentation prüfen (323 Dateien, ~124 broken links)
ruby bin/check-docs-links.rb

# Nur aktive Dokumentation (191 Dateien, ~90 broken links) - EMPFOHLEN
ruby bin/check-docs-links.rb --exclude-archives

# Hilfe anzeigen
ruby bin/check-docs-links.rb --help

# Report speichern
ruby bin/check-docs-links.rb --exclude-archives > docs/BROKEN_LINKS_REPORT.txt
```

### Links automatisch fixen

```bash
# Dry-run (zeigt was geändert würde)
ruby bin/fix-docs-links.rb

# Änderungen anwenden
ruby bin/fix-docs-links.rb --live
```

**Automatische Fixes:**
- ✓ `docs/` Prefix entfernen
- ✓ Alte `INSTALLATION/` Pfade updaten
- ✓ `test/` Referenzen zu `developers/testing/` umleiten
- ✓ Obsolete Referenzen fixen

### Aktueller Status (März 2026)

| Kategorie | Anzahl |
|-----------|--------|
| **Aktive Dokumentation** | **191 Dateien** |
| **Broken Links (aktiv)** | **90** ⚠️ |
| Automatisch fixbar | 16 ✓ |
| Manuell zu fixen | ~74 📝 |

**Breakdown:**
- `players/`: 34 broken links
- `developers/`: 23 broken links  
- `reference/`: 16 broken links
- Andere: 17 broken links

**Guide:** Siehe `docs/FIXING_DOCUMENTATION_LINKS.md` für Details

---

## 📁 Struktur

```
docs/                           # Dokumentations-Quellen (Markdown)
├── index.de.md                 # Startseite (Deutsch)
├── index.en.md                 # Startseite (Englisch)
├── decision-makers/            # Für Entscheider
├── players/                    # Für Spieler
├── managers/                   # Für Turniermanager
├── administrators/             # Für Systemadministratoren
├── developers/                 # Für Entwickler
│   ├── testing/                # Testing-Dokumentation
│   ├── scenario-management.md  # Scenario-System
│   └── developer-guide.de.md   # Entwickler-Handbuch
├── reference/                  # Referenz (API, Glossar)
├── international/              # Internationale Turniere
├── internal/                   # ❌ Interne Docs (nicht öffentlich)
├── archive/                    # ❌ Archiv (ausgeschlossen)
└── obsolete/                   # ❌ Veraltet (ausgeschlossen)

mkdocs.yml                      # MkDocs Konfiguration
requirements.txt                # Python Dependencies

site/                           # ⚠️ Temporär (von mkdocs build)
                                # ❌ NICHT committen!

public/docs/                    # ✅ Finale HTML-Dateien (für Rails)
                                # Wird von mkdocs:build generiert
```

---

## 🌍 Mehrsprachigkeit (i18n)

### Dateinamen-Konvention

```bash
# Deutsche Version (Suffix .de.md)
docs/developers/my-doc.de.md

# Englische Version (Suffix .en.md)
docs/developers/my-doc.en.md

# ❌ NICHT: docs/de/developers/my-doc.md
# ✓ JA: docs/developers/my-doc.de.md
```

**Plugin:** `mkdocs-static-i18n` mit `docs_structure: suffix`

**Generierte URLs:**
- Deutsch: `/developers/my-doc/` (Standard)
- Englisch: `/en/developers/my-doc/`

### Neue mehrsprachige Seite hinzufügen

1. **Dateien erstellen:**
   ```bash
   docs/developers/new-feature.de.md
   docs/developers/new-feature.en.md
   ```

2. **In `mkdocs.yml` hinzufügen:**
   ```yaml
   nav:
     - Developers:
       - New Feature: developers/new-feature.md
   ```

3. **Testen:**
   ```bash
   mkdocs serve
   # Besuche: http://localhost:8000/developers/new-feature/
   ```

---

## 🧪 Testing

### Struktur-Tests

```bash
# Strukturtests ausführen
./bin/test-docs-structure.sh
```

**Testet:**
- ✓ Core-Dateien (index.html, 404.html)
- ✓ Hauptsektionen (managers/, players/, etc.)
- ✓ Wichtige Dokumentationsseiten
- ✓ Mehrsprachige Unterstützung

### Vollständiger Test-Workflow

```bash
# 1. Links prüfen
ruby bin/check-docs-links.rb --exclude-archives

# 2. Automatische Fixes
ruby bin/fix-docs-links.rb --live

# 3. Dokumentation neu bauen
bundle exec rake mkdocs:deploy

# 4. Strukturtests
./bin/test-docs-structure.sh

# 5. Manuelle Prüfung
open http://localhost:3000/docs/
```

---

## ✅ Best Practices

### ✅ DO

- ✅ `mkdocs serve` für lokale Entwicklung
- ✅ `bundle exec rake mkdocs:deploy` zum Bauen
- ✅ `ruby bin/check-docs-links.rb` vor jedem Commit
- ✅ Links relativ mit `../` verwenden
- ✅ Dateinamen mit `.de.md` / `.en.md` Suffix
- ✅ Bilder in gleichen Ordner wie Markdown
- ✅ Interne Docs in `internal/` (wird ausgeschlossen)

### ❌ DON'T

- ❌ `site/` Verzeichnis committen (in `.gitignore`)
- ❌ `public/docs/` manuell bearbeiten (wird generiert)
- ❌ Absolute Pfade in Links verwenden
- ❌ `docs/` Prefix in internen Links
- ❌ Große Binärdateien in `docs/` ablegen
- ❌ Sensitive Daten in öffentlicher Dokumentation

---

## 🔧 Troubleshooting

### Problem: Broken Links nach Reorganisation

```bash
# Links checken
ruby bin/check-docs-links.rb --exclude-archives

# Automatisch fixen
ruby bin/fix-docs-links.rb --live

# Manuelle Fixes mit Guide
cat docs/FIXING_DOCUMENTATION_LINKS.md
```

### Problem: `site/` wurde versehentlich committed

```bash
# Aus Git entfernen
git rm -r --cached site/

# .gitignore prüfen
grep "site/" .gitignore

# Committen
git commit -m "Fix: Remove site/ from git"
```

### Problem: MkDocs Build-Fehler

```bash
# Verbose output
mkdocs build --verbose

# Cache leeren und neu bauen
bundle exec rake mkdocs:clean
bundle exec rake mkdocs:build

# Dependencies prüfen
pip list | grep mkdocs
```

### Problem: Links funktionieren nicht in Rails

```bash
# Trailing slashes entfernen (bekanntes Problem)
# ❌ [Link](managers/tournament-management/)
# ✓ [Link](managers/tournament-management)

# Pfad-Struktur prüfen
ls -la public/docs/managers/tournament-management/

# DocsController testen
curl http://localhost:3000/docs/managers/tournament-management
```

### Problem: Live-Reload funktioniert nicht

```bash
# Server neu starten
pkill -f mkdocs
mkdocs serve

# Oder mit --dirty flag (schneller)
mkdocs serve --dirty

# Auf anderem Port
mkdocs serve --dev-addr=127.0.0.1:8001
```

---

## 📊 Build-Statistiken

### Aktuelle Zahlen (März 2026)

```bash
# Dateien zählen
find docs -name "*.md" | wc -l
# → 323 Markdown-Dateien

# Aktive Dokumentation (ohne Archives)
find docs -name "*.md" | grep -v -E "archive|internal|obsolete|studies" | wc -l
# → 191 aktive Dateien

# Build-Größe prüfen
du -sh public/docs/
# → ~40-50 MB (HTML, CSS, JS, Bilder)
```

### Build testen

```bash
# Build lokal testen
mkdocs build --verbose

# Warnungen prüfen
mkdocs build 2>&1 | grep -i warning

# Build-Zeit messen
time mkdocs build
```

---

## 🔗 Links & Ressourcen

### Dokumentation

- **Live (GitHub Pages)**: https://GernotUllrich.github.io/carambus
- **Rails MkDocs**: http://localhost:3000/docs/
- **Rails Markdown**: http://localhost:3000/docs_page/index
- **API Docs**: https://api.carambus.de/docs_page/index

### Guides & Internal Docs

- **Link Fixing Guide**: `docs/internal/link-checking/fixing-links-guide.md`
- **Documentation System**: `docs/internal/link-checking/documentation-system-notes.md`
- **Broken Links Report**: `docs/BROKEN_LINKS_REPORT.txt` (generated)

### Tools

- **Link Checker**: `bin/check-docs-links.rb`
- **Link Fixer**: `bin/fix-docs-links.rb`
- **Structure Tests**: `bin/test-docs-structure.sh`
- **Deploy Script**: `bin/deploy-docs.sh`

### Externe Docs

- **MkDocs**: https://www.mkdocs.org
- **Material Theme**: https://squidfunk.github.io/mkdocs-material
- **i18n Plugin**: https://github.com/ultrabug/mkdocs-static-i18n

### Workflows

- **GitHub Actions**: `.github/workflows/build-docs.yml`
- **Rake Tasks**: `lib/tasks/mkdocs.rake`

---

## 💡 Tipps & Tricks

### Schnelle Navigation

```bash
# Nur geänderte Seiten neu bauen
mkdocs serve --dirty

# Watch-Mode ausschalten (für große Änderungen)
mkdocs serve --no-livereload

# Bestimmte Seite direkt öffnen
mkdocs serve
open http://127.0.0.1:8000/developers/developer-guide/
```

### Neue Seite hinzufügen

```bash
# 1. Markdown-Datei erstellen
vim docs/developers/my-new-feature.de.md

# 2. In mkdocs.yml unter nav: hinzufügen
vim mkdocs.yml
# Unter "Developers:" hinzufügen:
#   - My New Feature: developers/my-new-feature.md

# 3. Preview öffnet automatisch
# (falls mkdocs serve läuft)
```

### Performance-Optimierung

```bash
# Nur Deutsch bauen (für schnelles Testing)
# mkdocs.yml temporär anpassen:
# languages:
#   - locale: de
#     default: true
#     build: true
#   - locale: en
#     build: false  # ← Englisch deaktivieren

# Dann bauen
mkdocs build
```

### Batch-Link-Fixing

```bash
# 1. Report generieren
ruby bin/check-docs-links.rb --exclude-archives > report.txt

# 2. Nach Kategorie sortieren
grep "players/" report.txt > players_links.txt
grep "developers/" report.txt > dev_links.txt

# 3. Eine Kategorie nach der anderen fixen
# (siehe docs/FIXING_DOCUMENTATION_LINKS.md)
```

---

## 📋 Checkliste für neue Dokumentation

- [ ] Markdown-Datei mit korrektem Suffix erstellt (`.de.md` / `.en.md`)
- [ ] In `mkdocs.yml` unter `nav:` hinzugefügt
- [ ] Links mit relativen Pfaden (`../`)
- [ ] Bilder im gleichen Ordner
- [ ] Links mit `bin/check-docs-links.rb` geprüft
- [ ] Preview mit `mkdocs serve` getestet
- [ ] Build mit `rake mkdocs:build` getestet
- [ ] Committed und gepusht
- [ ] GitHub Actions erfolgreich durchgelaufen

---

## 🎯 Nächste Schritte

### Aktuelle Aufgaben

1. **Broken Links fixen** (~90 in aktiver Dokumentation)
   ```bash
   ruby bin/fix-docs-links.rb --live
   ruby bin/check-docs-links.rb --exclude-archives
   # Dann manuell restliche Links fixen
   ```

2. **Screenshots hinzufügen** (viele fehlen)
   - `players/screenshots/*.png`
   - In docs/ committen
   - Links aktualisieren

3. **Tests erweitern**
   - Mehr Seiten in `bin/test-docs-structure.sh` testen
   - Integration tests für DocsController

---

---

## 📋 Dokumentations-Regeln (NEU!)

### ⚠️ WICHTIG: Redundanz vermeiden!

**Problem:** AI erstellt oft neue Dokumentations-Dateien statt bestehende zu aktualisieren.

**Lösung:** Neue Regeln in `.cursor/rules/documentation-management.md`

### Workflow

1. **Während Entwicklung** → `docs/internal/`
   ```bash
   docs/internal/implementation-notes/FEATURE_NOTES.md
   docs/internal/bug-fixes/BUG_FIX_1234.md
   ```

2. **Nach Testing** → Offizielle Docs aktualisieren
   ```bash
   vim docs/developers/developer-guide.de.md  # Sektion hinzufügen
   vim docs/MKDOCS_DEVELOPMENT.md             # Guide erweitern
   ```

3. **Cleanup** → Internal docs archivieren/löschen
   ```bash
   mv docs/internal/implementation-notes/OLD.md \
      docs/internal/archive/2026-03/
   ```

### Was ist NICHT erlaubt

- ❌ Neue UPPERCASE .md Dateien in `docs/` (außer `internal/`)
- ❌ Dokumentation in Rails.root
- ❌ Duplicate Docs statt Updates
- ❌ Finale Docs ohne Übersetzung (.de.md + .en.md)

### Siehe

- **Vollständige Regeln**: `.cursor/rules/documentation-management.md`
- **Internal Docs Guide**: `docs/internal/README.md`

---

**Happy Documenting! 📝**

*Letzte Aktualisierung: März 2026*  
*Version: 2.1 (mit Dokumentations-Regeln)*
