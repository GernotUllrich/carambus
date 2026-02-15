# 📁 Test-Struktur von Carambus

Visueller Überblick über die Test-Organisation.

## 🌳 Verzeichnis-Struktur

```
test/
│
├── 📋 README.md                      # Hauptdokumentation
├── 🏗️ ARCHITECTURE.md                # Architektur-Details
├── 📊 TEST_STRUCTURE.md              # Diese Datei
│
├── 🔧 concerns/                      # Concern Tests (KRITISCH)
│   ├── local_protector_test.rb      # ✅ Datenschutz
│   ├── source_handler_test.rb       # ✅ Sync Tracking
│   └── region_taggable_test.rb      # ⏳ TODO
│
├── 🕷️ scraping/                      # Scraping Tests (KRITISCH)
│   ├── tournament_scraper_test.rb   # ⏳ Benötigt Fixtures
│   └── change_detection_test.rb     # ⏳ Benötigt Fixtures
│
├── 📦 models/                        # Model Tests (45 Dateien)
│   ├── tournament_test.rb           # ✅ Vorhanden
│   ├── game_test.rb                 # ⏳ Erweitern
│   ├── player_test.rb               # ⏳ Erweitern
│   └── ...                          # Weitere 42 Dateien
│
├── 🎮 controllers/                   # Controller Tests (13 Dateien)
│   ├── tournaments_controller_test.rb
│   ├── games_controller_test.rb
│   └── ...
│
├── 🔗 integration/                   # Integration Tests
│   ├── clubcloud_sync_test.rb       # ⏳ TODO
│   └── users_test.rb                # ✅ Vorhanden
│
├── 🖥️ system/                        # Browser E2E Tests (10 Dateien)
│   ├── tournament_management_test.rb
│   └── ...
│
├── 🗂️ fixtures/                      # Test-Daten (YAML)
│   ├── seasons.yml                  # ✅ NEU
│   ├── regions.yml                  # ✅ NEU
│   ├── disciplines.yml              # ✅ NEU
│   ├── clubs.yml                    # ✅ NEU
│   ├── tournaments.yml              # ✅ NEU
│   ├── users.yml                    # ✅ Vorhanden
│   └── ...                          # 9 Fixture-Dateien
│
├── 📸 snapshots/                     # HTTP & Data Snapshots
│   ├── 📹 vcr/                       # VCR Cassettes
│   │   ├── .gitkeep
│   │   └── README.md                # ✅ Dokumentiert
│   └── 💾 data/                      # Data Snapshots
│       └── .gitkeep
│
├── 🛠️ support/                       # Test Helpers
│   ├── vcr_setup.rb                 # ✅ VCR Konfiguration
│   ├── scraping_helpers.rb          # ✅ Scraping Utilities
│   └── snapshot_helpers.rb          # ✅ Snapshot Tools
│
├── ⚙️ tasks/                         # Task Tests
│   └── auto_reserve_tables_test.rb
│
└── 🔍 helpers/                       # Helper Tests
    ├── filters_helper_test.rb
    └── current_helper_test.rb
```

## 📊 Statistik

```
Gesamt Test-Dateien:    49
├─ Models:              45
├─ Controllers:         13
├─ System:              10
├─ Concerns:            2 (NEU)
├─ Scraping:            2 (NEU)
├─ Integration:         1
├─ Tasks:               1
└─ Helpers:             2

Fixture-Dateien:        9
├─ Seasons:             ✅ NEU
├─ Regions:             ✅ NEU
├─ Disciplines:         ✅ NEU
├─ Clubs:               ✅ NEU
├─ Tournaments:         ✅ NEU
└─ Bestehend:           4

Test Helpers:           3
├─ VCR Setup:           ✅ NEU
├─ Scraping:            ✅ NEU
└─ Snapshots:           ✅ NEU
```

## 🎯 Test-Kategorien nach Priorität

### 🔥 Kritisch (Höchste Priorität)

```
concerns/local_protector_test.rb    ✅ Implementiert
├─ Verhindert Datenverlust
├─ Kern der Multi-Tenant-Architektur
└─ 8 Tests vorhanden

concerns/source_handler_test.rb     ✅ Implementiert
├─ Sync-Date Tracking
├─ Change Detection Basis
└─ 4 Tests vorhanden

scraping/tournament_scraper_test.rb  ⏳ Framework vorhanden
├─ ClubCloud HTML Parsing
├─ 8 Tests vorbereitet (mit skip)
└─ Benötigt: ClubCloud HTML Fixtures

scraping/change_detection_test.rb    ⏳ Framework vorhanden
├─ Erkennt Änderungen in ClubCloud
├─ 6 Tests vorbereitet (mit skip)
└─ Benötigt: VCR Cassettes
```

### 📦 Wichtig

```
models/tournament_test.rb           ✅ Vorhanden (3 Tests)
├─ Business Logic
└─ Kann erweitert werden

models/game_test.rb                 ⏳ Basis vorhanden
├─ Ergebnis-Logik
└─ Erweitern empfohlen

models/party_test.rb                ✅ Vorhanden
└─ Liga-Partien
```

### 🔗 Sinnvoll

```
integration/clubcloud_sync_test.rb  ⏳ TODO
├─ Kompletter Sync-Workflow
└─ Scraping → API → Storage

system/tournament_management_test.rb ✅ Vorhanden
├─ Browser-basiert
└─ Kritische User Flows
```

## 🚦 Status-Legende

- ✅ **Implementiert** - Funktioniert, kann genutzt werden
- ⏳ **Framework vorhanden** - Struktur da, benötigt Fixtures/Daten
- 🔧 **In Arbeit** - Wird gerade entwickelt
- 📝 **TODO** - Geplant aber noch nicht begonnen

## 📈 Coverage-Ziele nach Komponente

```
┌─────────────────────────────────────────────────────┐
│ Komponente              │ Aktuell │ Ziel   │ Status │
├─────────────────────────┼─────────┼────────┼────────┤
│ LocalProtector          │   85%   │  90%+  │   ✅   │
│ SourceHandler           │   90%   │  90%+  │   ✅   │
│ Tournament Scraping     │    0%   │  80%+  │   ⏳   │
│ Change Detection        │    0%   │  70%+  │   ⏳   │
│ Models (Business Logic) │   45%   │  70%+  │   📝   │
│ Controllers             │   40%   │  60%+  │   📝   │
│ Services                │   30%   │  60%+  │   📝   │
├─────────────────────────┼─────────┼────────┼────────┤
│ GESAMT                  │   42%   │  60%+  │   🔧   │
└─────────────────────────────────────────────────────┘
```

## 🔄 Test-Workflow

```
1. Developer schreibt Code
        ↓
2. Schreibt Test (oder umgekehrt bei TDD)
        ↓
3. Lokale Tests: bin/rails test
        ↓
4. Commit & Push
        ↓
5. GitHub Actions: CI läuft
        ↓
6. ✅ Tests grün → Merge möglich
   ❌ Tests rot → Fix erforderlich
```

## 🛠️ Helper-Nutzung

### VCR (HTTP Recording)

```ruby
# In Test
VCR.use_cassette("nbv_tournament") do
  tournament.scrape_single_tournament_public
end

# Cassette wird gespeichert in:
# test/snapshots/vcr/nbv_tournament.yml
```

### Scraping Helpers

```ruby
# HTML Fixture mocken
mock_clubcloud_html(url, html_content)

# Sync-Date prüfen
assert_sync_date_updated(tournament, since: 1.hour.ago)

# Snapshot-Name generieren
name = snapshot_name("tournament", "nbv", "2025")
# => "tournament_nbv_2025"
```

### Snapshot Helpers

```ruby
# Data Snapshot erstellen/vergleichen
data = { title: tournament.title, date: tournament.date }
assert_matches_snapshot("tournament_structure", data)

# Model Attributes für Snapshot
attrs = snapshot_attributes(tournament, :title, :date)
```

## 🎯 Nächste Schritte

### Phase 1: ClubCloud Fixtures (1-2 Tage)
```
1. [ ] NBV Tournament HTML sammeln
2. [ ] VCR Cassette für Tournament aufnehmen
3. [ ] skip aus tournament_scraper_test.rb entfernen
4. [ ] Tests grün machen
```

### Phase 2: Change Detection (1-2 Tage)
```
1. [ ] VCR Cassettes mit Änderungen aufnehmen
2. [ ] skip aus change_detection_test.rb entfernen
3. [ ] sync_date Logik verifizieren
4. [ ] Tests grün machen
```

### Phase 3: Integration Tests (2-3 Tage)
```
1. [ ] clubcloud_sync_test.rb schreiben
2. [ ] Kompletter Workflow-Test
3. [ ] Error-Handling testen
```

### Phase 4: CI/CD & Coverage (1 Tag)
```
1. [ ] GitHub Actions Badge ins README
2. [ ] Coverage-Reports in CI
3. [ ] Test-Reports automatisiert
```

## 📚 Dokumentation

```
test/
├── README.md              # Hauptanleitung
├── ARCHITECTURE.md        # Architektur-Details
└── TEST_STRUCTURE.md      # Diese Datei (Übersicht)

Haupt-Verzeichnis:
├── TESTING.md             # Quick Start Guide
└── TEST_SETUP_SUMMARY.md  # Zusammenfassung Setup

Strategie:
└── docs/developers/
    └── testing-strategy.de.md  # Konzept & Philosophie
```

## 🎓 Für Einsteiger

**Wo anfangen?**

1. **Lesen:** [TESTING.md](../TESTING.md) für Quick Start
2. **Validieren:** `bin/rails test:validate`
3. **Laufen lassen:** `bin/rails test:critical`
4. **Ersten Test schreiben:** Siehe [test/README.md](README.md)

**Einfache Einstiegs-Tasks:**

- ✅ Fixture für neues Model hinzufügen
- ✅ ClubCloud HTML Fixture sammeln
- ✅ Test mit `skip` vervollständigen
- ✅ Coverage für Model erhöhen

## 📞 Support

- **Fragen zu Tests:** Siehe [test/README.md](README.md)
- **Architektur-Fragen:** Siehe [test/ARCHITECTURE.md](ARCHITECTURE.md)
- **Quick Start:** Siehe [TESTING.md](../TESTING.md)
- **Strategie:** Siehe [docs/developers/testing-strategy.de.md](../docs/developers/testing-strategy.de.md)

---

**Letzte Aktualisierung:** 2026-02-14
**Status:** ✅ Test-Setup komplett, 🔧 Tests in Entwicklung
