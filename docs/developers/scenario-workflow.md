# Scenario Workflow - Git Verwaltung

## ⚠️ WICHTIGE REGEL: Single Source of Truth

**ALLE Code-Änderungen, Commits und Pushes werden NUR in `carambus_master` durchgeführt.**

Die anderen Scenarios (`carambus_bcw`, `carambus_api`, `carambus_phat`, `carambus_pbv`) holen sich die Änderungen per `git pull`.

---

## 📋 Workflow-Regeln

### ✅ Was IMMER in `carambus_master` passiert:

1. **Code-Änderungen**: Alle Edits an Ruby-Dateien, Views, JavaScript, CSS, etc.
2. **Git Commits**: Alle Commits mit aussagekräftigen Commit-Messages
3. **Git Push**: Push zu `carambus/master` Remote
4. **Testing**: Initiales Testing neuer Features

### ✅ Was in den Scenario-Repos passiert:

1. **Git Pull**: Änderungen von `carambus_master` holen
2. **Deployment**: Deployment auf die jeweiligen Server (z.B. `cap bcw deploy`)
3. **Scenario-spezifische Konfiguration**: 
   - `.env`-Dateien (werden nicht committed)
   - `config/database.yml` (scenario-spezifisch)
   - Produktions-Testing

### ❌ Was NIEMALS in Scenario-Repos passiert:

- ❌ Direkte Code-Änderungen
- ❌ Git Commits
- ❌ Git Push
- ❌ Manuelle Edits an geteilten Dateien

---

## 🔄 Typischer Workflow

### Beispiel: Bug Fix implementieren

```bash
# 1. In carambus_master arbeiten
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master

# 2. Code ändern
vim app/controllers/tournaments_controller.rb

# 3. Testen (lokal oder auf master-Server)
rails test

# 4. Commit und Push
git add .
git commit -m "Fix: Tournament status update in background jobs"
git push carambus master

# 5. In jedem Scenario-Repo: Pull und Deploy
cd ../carambus_bcw
git pull
cap bcw deploy

cd ../carambus_api
git pull
cap api deploy

cd ../carambus_phat
git pull
cap phat deploy

cd ../carambus_pbv
git pull
cap pbv deploy
```

---

## 🚨 Was tun bei Git-Konflikten in Scenarios?

Wenn ein Scenario-Repo lokale Änderungen hat und `git pull` abbricht:

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw

# 1. Prüfen, was geändert wurde
git status
git diff

# 2. Lokale Änderungen verwerfen (wenn sie versehentlich gemacht wurden)
git reset --hard HEAD
git pull

# 3. ODER: Lokale Änderungen in carambus_master portieren
# - Änderungen kopieren
# - In carambus_master einfügen
# - In carambus_master committen und pushen
# - Dann in Scenario-Repo: git reset --hard HEAD && git pull
```

---

## 📁 Repository-Struktur

```
carambus/
├── carambus_master/          # 🌟 SINGLE SOURCE OF TRUTH
│   ├── app/                  # ✅ Hier alle Code-Änderungen
│   ├── docs/                 # ✅ Hier alle Dokumentations-Updates
│   └── .git/                 # ✅ Hier alle Commits
│
├── carambus_bcw/             # 🔄 BCW Scenario (Pull only)
│   ├── .env                  # Scenario-spezifisch
│   └── config/database.yml   # Scenario-spezifisch
│
├── carambus_api/             # 🔄 API Scenario (Pull only)
├── carambus_phat/            # 🔄 PHAT Scenario (Pull only)
└── carambus_pbv/             # 🔄 PBV Scenario (Pull only)
```

---

## 🤖 Cursor AI Regel

**Für Cursor AI / AI-Assistenten:**

```
WICHTIGE REGEL:
- Alle Edits, Commits und Pushes werden NUR von carambus_master aus gemacht
- Andere Scenarios holen sich die Versionen per git pull
- NIEMALS direkt in carambus_bcw, carambus_api, carambus_phat oder carambus_pbv editieren
```

---

## 📖 Verwandte Dokumentation

- [CONTRIBUTING.de.md](CONTRIBUTING.md) - Allgemeine Beitrags-Richtlinien
- [README.de.md](README.md) - Projekt-Übersicht
- [carambus_master/docs/developers/](carambus_master/docs/developers/) - Developer-Dokumentation

---

## ✅ Checkliste für Code-Änderungen

- [ ] Änderungen in `carambus_master` durchgeführt
- [ ] Lokal getestet
- [ ] Commit mit aussagekräftiger Message
- [ ] Push zu `carambus/master`
- [ ] In allen relevanten Scenarios: `git pull`
- [ ] In allen relevanten Scenarios: Deployment durchgeführt
- [ ] Produktions-Test auf mindestens einem Scenario-Server

---

**Letzte Aktualisierung**: 2026-02-06
