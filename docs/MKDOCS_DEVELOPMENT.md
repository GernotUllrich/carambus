# MkDocs Development Guide

## 🎯 Quick Start

### Lokale Vorschau (empfohlen)

```bash
# Live-Preview starten (kein site/ Verzeichnis wird generiert)
mkdocs serve

# Browser öffnen
open http://127.0.0.1:8000
```

**Vorteile:**
- ✅ Änderungen werden sofort sichtbar (Live-Reload)
- ✅ Kein `site/` Verzeichnis auf der Festplatte
- ✅ Schnell und effizient

### ❌ NICHT lokal builden

```bash
# ❌ NICHT ausführen (außer zum Testen)
mkdocs build
```

**Warum nicht?**
- Generiert `site/` Verzeichnis lokal (950.000+ Zeilen)
- Sollte NIEMALS committed werden (steht in `.gitignore`)
- GitHub Actions macht das automatisch

---

## 📦 Setup (einmalig)

### 1. Python & Dependencies installieren

```bash
# Python 3.11+ erforderlich
python3 --version

# Dependencies installieren
pip install -r requirements.txt
```

### 2. requirements.txt erstellen (falls nicht vorhanden)

```txt
mkdocs>=1.5.0
mkdocs-material>=9.4.0
mkdocs-i18n>=0.4.0
```

---

## 🚀 Workflow

### Lokale Entwicklung

```bash
# 1. Live-Preview starten
mkdocs serve

# 2. Dokumentation bearbeiten (z.B. docs/developers/my-doc.md)
vim docs/developers/my-doc.md

# 3. Browser aktualisiert automatisch
# Keine weiteren Schritte nötig!
```

### Deployment (automatisch via GitHub)

```bash
# 1. Änderungen committen
git add docs/
git commit -m "Update documentation"
git push

# 2. GitHub Actions buildet & deployed automatisch
# Siehe: .github/workflows/build-docs.yml

# 3. Nach ~2 Minuten verfügbar unter:
# https://GernotUllrich.github.io/carambus
```

---

## 📁 Struktur

```
docs/                           # Dokumentations-Quellen
├── index.md                    # Startseite
├── decision-makers/            # Für Entscheider
├── players/                    # Für Spieler
├── managers/                   # Für Manager
├── administrators/             # Für Admins
├── developers/                 # Für Entwickler
│   └── scenario-management.md  # Wichtig: Scenario-System
├── reference/                  # Referenz (API, Glossar)
└── about.md                    # Über

mkdocs.yml                      # MkDocs Konfiguration
.mkdocsignore                   # Ausschlussliste
.gitignore                      # Git Ignore (enthält /site/)

site/                           # ❌ Wird von GitHub Actions generiert
                                # ❌ NICHT lokal committen!
```

---

## 🌍 Mehrsprachigkeit (i18n)

### Dokumentation übersetzen

```bash
# Deutsche Version (Standard)
docs/my-doc.md

# Englische Version (Suffix)
docs/my-doc.en.md
```

**Beispiel:**

```
docs/developers/
├── scenario-management.md       # Deutsch (Standard)
└── scenario-management.en.md    # Englisch (optional)
```

MkDocs generiert automatisch:
- Deutsch: `/de/developers/scenario-management/`
- Englisch: `/en/developers/scenario-management/`

---

## ✅ Best Practices

### ✅ DO

- ✅ `mkdocs serve` für lokale Entwicklung
- ✅ Dokumentation in `docs/` bearbeiten
- ✅ Bilder in `docs/screenshots/` ablegen
- ✅ Interne Dokumentation in `docs/internal/` (nicht öffentlich)
- ✅ Commit & Push → GitHub Actions übernimmt Rest

### ❌ DON'T

- ❌ `mkdocs build` lokal ausführen (außer zum Testen)
- ❌ `site/` Verzeichnis committen
- ❌ Große Binärdateien (SQL dumps) in `docs/` ablegen
- ❌ Sensitive Daten in öffentlicher Dokumentation

---

## 🔧 Troubleshooting

### Problem: `site/` wurde versehentlich committed

```bash
# 1. Aus Git entfernen
git rm -r --cached site/

# 2. Sicherstellen dass .gitignore korrekt ist
echo "/site/" >> .gitignore

# 3. Committen
git add .gitignore
git commit -m "Fix: Remove site/ from git"
git push
```

### Problem: MkDocs findet Dateien nicht

```bash
# Prüfen ob docs_dir korrekt ist
grep docs_dir mkdocs.yml
# Sollte sein: docs_dir: docs

# Prüfen ob Datei existiert
ls -la docs/my-doc.md
```

### Problem: Live-Reload funktioniert nicht

```bash
# Server neu starten
pkill -f mkdocs
mkdocs serve

# Oder mit --dirty flag (schneller)
mkdocs serve --dirty
```

---

## 📊 Build-Statistiken prüfen

```bash
# Build lokal testen (nur zum Debugging)
mkdocs build --verbose

# Build-Größe prüfen
du -sh site/

# Sollte sein: ~30-50 MB (hauptsächlich JavaScript/CSS)
```

---

## 🔗 Links

- **Live-Dokumentation**: https://GernotUllrich.github.io/carambus
- **MkDocs Docs**: https://www.mkdocs.org
- **Material Theme**: https://squidfunk.github.io/mkdocs-material
- **GitHub Actions**: `.github/workflows/build-docs.yml`

---

## 💡 Tipps

### Schnelles Navigieren

```bash
# Nur bestimmte Seite builden (schneller)
mkdocs serve --dirty

# Auf anderem Port
mkdocs serve --dev-addr=127.0.0.1:8001
```

### Neue Seite hinzufügen

1. Markdown-Datei erstellen: `docs/developers/my-new-doc.md`
2. In `mkdocs.yml` unter `nav:` hinzufügen:
   ```yaml
   - Developers:
       - My New Doc: developers/my-new-doc.md
   ```
3. Speichern → Live-Reload zeigt neue Seite

### Internes vs. Öffentliches

```
docs/
├── developers/          # ✅ Öffentlich (wird gebaut)
└── internal/            # ❌ Intern (in .mkdocsignore)
```

---

**Happy Documenting! 📝**
