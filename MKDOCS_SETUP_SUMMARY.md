# MkDocs Setup - Zusammenfassung ✅

**Status:** Korrekt konfiguriert  
**Datum:** 2026-02-15

---

## 📋 Was wurde korrigiert?

### Problem (vorher):
- ❌ `site/` Verzeichnis (~950.000 Zeilen) wurde versehentlich committed
- ❌ Fehlte in `.gitignore`
- ❌ Lokaler Build sollte nicht committed werden

### Lösung (jetzt):
- ✅ `site/` aus Git entfernt (Commit `d3f6cf6`)
- ✅ `/site/` in `.gitignore` hinzugefügt
- ✅ `.mkdocsignore` erstellt (zusätzlicher Schutz)
- ✅ Dokumentation für Entwickler erstellt

---

## 🎯 Korrekte Workflows

### Lokale Entwicklung (empfohlen):

```bash
# Live-Preview starten (kein site/ auf Disk)
mkdocs serve

# Browser öffnen
open http://127.0.0.1:8000
```

**Vorteile:**
- Änderungen werden sofort sichtbar
- Kein `site/` Verzeichnis lokal
- Schnell und effizient

### Deployment (automatisch):

```bash
# 1. Dokumentation bearbeiten
vim docs/developers/my-doc.md

# 2. Commit & Push
git add docs/
git commit -m "Update docs"
git push

# 3. GitHub Actions buildet automatisch
# → https://GernotUllrich.github.io/carambus
```

---

## 📁 Dateien im Repository

### ✅ Was ist im Git:

```
mkdocs.yml                      # MkDocs Konfiguration
.gitignore                      # Enthält /site/
.mkdocsignore                   # Zusätzliche Ausschlüsse
docs/                           # Dokumentations-Quellen
├── MKDOCS_DEVELOPMENT.md       # Entwickler-Guide (NEU)
└── (alle anderen .md Dateien)
.github/workflows/build-docs.yml # GitHub Actions
requirements.txt                # Python Dependencies
```

### ❌ Was NICHT im Git ist:

```
site/                           # ❌ Wird von GitHub Actions generiert
*.pyc                           # ❌ Python bytecode
__pycache__/                    # ❌ Python cache
```

---

## 🔧 GitHub Actions

**Workflow:** `.github/workflows/build-docs.yml`

**Trigger:**
- Bei jedem Push zu `master`
- Bei Pull Requests
- Manuell (workflow_dispatch)

**Was passiert:**
1. Checkout Repository
2. Setup Python 3.11
3. Install Dependencies (`pip install -r requirements.txt`)
4. Build Documentation (`mkdocs build`)
5. Deploy zu GitHub Pages

**URL:** https://GernotUllrich.github.io/carambus

---

## 🌍 Mehrsprachigkeit

**Plugin:** `mkdocs-i18n`

**Struktur:**
```
docs/my-doc.md       # Deutsch (Standard)
docs/my-doc.en.md    # Englisch (Suffix)
```

**URLs:**
- Deutsch: `/de/my-doc/`
- Englisch: `/en/my-doc/`

---

## ✅ Checklist für Entwickler

Beim Arbeiten mit MkDocs:

- [ ] ✅ `mkdocs serve` für lokale Vorschau
- [ ] ✅ Dokumentation in `docs/` bearbeiten
- [ ] ✅ Nur `.md` Dateien committen
- [ ] ❌ NIEMALS `mkdocs build` lokal ausführen
- [ ] ❌ NIEMALS `site/` committen
- [ ] ✅ Push → GitHub Actions übernimmt Rest

---

## 🔍 Troubleshooting

### Q: Warum wurde `site/` generiert?

**A:** Jemand hat lokal `mkdocs build` ausgeführt. Das ist nur zum Testen nötig.

### Q: Wie verhindere ich zukünftige Commits von `site/`?

**A:** `.gitignore` enthält jetzt `/site/`. Git wird es ignorieren.

### Q: Wie lösche ich lokales `site/` Verzeichnis?

**A:** 
```bash
rm -rf site/
# Wird von mkdocs serve NICHT neu erstellt (nur im RAM)
```

### Q: Wo sehe ich die deployed Dokumentation?

**A:** https://GernotUllrich.github.io/carambus (nach ~2 Min nach Push)

---

## 📚 Dokumentation

**Für Entwickler:** `docs/MKDOCS_DEVELOPMENT.md`

**Wichtige Links:**
- MkDocs: https://www.mkdocs.org
- Material Theme: https://squidfunk.github.io/mkdocs-material
- i18n Plugin: https://github.com/ultrabug/mkdocs-i18n

---

## 🎉 Status

**Setup:** ✅ Vollständig korrekt  
**Git:** ✅ Keine unnötigen Dateien  
**GitHub Actions:** ✅ Funktioniert  
**Dokumentation:** ✅ Verfügbar  

---

**Alles bereit für professionelle Dokumentation! 📝**
