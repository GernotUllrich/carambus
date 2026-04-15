# MkDocs Dokumentation für Carambus

## Übersicht

Das Carambus-Projekt verwendet **MkDocs** mit dem **Material Theme** und **mkdocs-static-i18n** Plugin für eine mehrsprachige, professionelle Dokumentation. Die Dokumentation wird automatisch über GitHub Actions gebaut und als Artifact bereitgestellt.

## Architektur

### 📁 Verzeichnisstruktur

```
carambus_api/
├── mkdocs.yml                 # Hauptkonfiguration
├── requirements.txt           # Python-Dependencies
├── docs/                      # Konsolidierte Dokumentation
│   ├── index.md              # Hauptstartseite
│   ├── assets/               # Bilder und Medien
│   ├── changelog/            # Änderungsprotokoll
│   ├── de/                   # Deutsche Dokumentation
│   │   ├── README.md
│   │   ├── DEVELOPER_GUIDE.md
│   │   ├── tournament.md
│   │   └── ...
│   └── en/                   # Englische Dokumentation
│       ├── README.md
│       ├── DEVELOPER_GUIDE.md
│       ├── tournament.md
│       └── ...
├── .github/workflows/
│   └── build-docs.yml        # CI/CD Workflow
└── site/                     # Gebaute Dokumentation (generiert)
```

### 🌐 Mehrsprachige Unterstützung

Das Projekt verwendet das **mkdocs-static-i18n** Plugin für vollständige Zweisprachigkeit:

- **Deutsch (de)**: Standardsprache, wird zuerst angezeigt
- **Englisch (en)**: Zweitsprache, vollständig übersetzt
- **Sprachumschaltung**: Automatisch in der Navigation verfügbar
- **Separate Navigation**: Jede Sprache hat ihre eigene Menüstruktur

## Konfiguration

### 🎨 Theme und Design

```yaml
theme:
  name: material
  features:
    - navigation.tabs      # Tab-Navigation
    - search.suggest       # Suchvorschläge
    - header.autohide      # Automatisches Ausblenden der Kopfzeile
  palette:
    - scheme: default
      primary: indigo      # Primärfarbe
    - scheme: slate        # Dark Mode
      primary: indigo
```

### 📋 Navigation

Die Navigation ist für beide Sprachen konfiguriert:

```yaml
nav:
  - Startseite: index.md
  - Einführung:
      - Über: about.md
      - README: README.md
  - Benutzerhandbuch:
      - Turnierverwaltung: tournament.md
      - Tischreservierung: table_reservation_heating_control.md
      - Scoreboard Setup: scoreboard_autostart_setup.md
      - Modus-Umschaltung: mode_switcher.md
  - Entwicklerhandbuch:
      - Entwicklerhandbuch: DEVELOPER_GUIDE.md
      - Datenbankdesign: database_design.md
      - Datenbanksynchronisation: database_syncing.md
      - Paper Trail Optimierung: paper_trail_optimization.md
  - Admin-Handbuch:
      - Admin-Rollen: admin_roles.md
      - Datenverwaltung: data_management.md
      - Filter-Popup Verwendung: filter_popup_usage.md
  - Referenz:
      - ER-Diagramm: er_diagram.md
      - API: API.md
      - AGB: terms.md
      - Datenschutz: privacy.md
```

### 🔌 Plugins

```yaml
plugins:
  - search                    # Volltextsuche
  - i18n:                     # Mehrsprachigkeit
      languages:
        - locale: de
          name: Deutsch
          default: true
          build: true
        - locale: en
          name: English
          build: true
      reconfigure_material: true
      docs_structure: folder
```

### 📝 Markdown-Erweiterungen

```yaml
markdown_extensions:
  - pymdownx.highlight        # Syntax-Highlighting
  - pymdownx.superfences      # Code-Blöcke und ER-Diagramme
  - toc:                      # Inhaltsverzeichnis
      permalink: true
  - admonition                # Warnungen und Hinweise
  - attr_list                 # Attribute für Bilder
  - md_in_html                # HTML in Markdown
```

## CI/CD Pipeline

### 🚀 GitHub Actions Workflow

```yaml
name: Build Documentation

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
      
      - name: Build documentation
        run: mkdocs build
      
      - name: Upload documentation artifact
        uses: actions/upload-artifact@v4
        with:
          name: documentation-build
          path: ./site
          retention-days: 30
```

### 📦 Dependencies

```txt
mkdocs-material>=9.5.0        # Material Theme
mkdocs-static-i18n>=1.0.0     # Mehrsprachigkeit
pymdown-extensions>=10.0.0    # Markdown-Erweiterungen
```

## Manuelle Rebuild-Disziplin (keine automatische Absicherung)

Da `public/docs/` git-getrackt ist und direkt von Rails unter `/docs/` ausgeliefert wird, führt jede Abweichung zwischen `docs/**/*.md` (Source) und `public/docs/**/*` (generiertes Output) dazu, dass stille, veraltete Inhalte ausgeliefert werden. Genau das war der Grund für v7.0 UAT-Lücke **G-02**, wo `public/docs/` seit dem 18.03.2026 veraltet war und vier Wochen Doc-Änderungen keinerlei sichtbare Wirkung hatten.

**Aktuell gibt es keinen automatischen Schutz gegen diese Drift-Klasse.** Quick Task `260415-26d` (15.04.2026) hat versucht, einen overcommit pre-commit Hook (`MkDocsBuild`) zu installieren, und wurde zurückgerollt, nachdem festgestellt wurde, dass der Hook im produktiven `git commit` Pfad nicht zuverlässig feuert — trotz erfolgreicher `overcommit --run` Tests. Siehe `.planning/quick/260415-26d-public-docs-build-hardening-via-overcomm/260415-26d-POSTMORTEM.md` für die reproduzierbaren Findings und die Entscheidung, den Ansatz in einer zukünftigen Milestone durch einen CI-Guard zu ersetzen.

Bis ein neuer Ansatz umgesetzt ist, läuft die Rebuild-Disziplin **manuell**:

```bash
# Nach jeder Änderung in docs/**/*.md
bin/rails mkdocs:build
git add docs/ public/docs/
git commit -m "docs(topic): Beschreibung"
```

Gute Trigger-Momente für einen Rebuild:

| Trigger | Grund |
|---|---|
| Vor jedem `git push` der `docs/**/*.md` angefasst hat | Erkennt Drift bevor sie die Workstation verlässt |
| Bei jedem `/gsd-complete-milestone` | Milestone-Artifacts müssen synchron sein |
| Nach jedem `/gsd-docs-update` Lauf | Hält generiertes Output aktuell zur Source |
| Als letzter Schritt jeder Phase die Docs editiert hat | Hält Phase-Complete-Commits atomar |

### Gemessene Build-Zeit

Auf dieser Workstation dauert ein vollständiger `bin/rails mkdocs:build` **~7 Sekunden wall-clock** (5,2 s reiner `mkdocs build` + site → public/docs Kopie). Für das aktuell ~270-seitige zweisprachige Docset wird das vom Template-Rendering dominiert, nicht vom I/O.

### Warum ein vollständiger Rebuild (kein inkrementeller Modus)

MkDocs unterstützt keine zuverlässigen inkrementellen Builds. Der `--dirty` Flag existiert, ist aber explizit als Entwicklungs-Loop-Optimierung für `mkdocs serve` dokumentiert. Er überspringt Nav- und Cross-Link-Regeneration und produziert fehlerhaftes Output wenn sich Links zwischen Seiten ändern. Da Dokumentationsarbeiten routinemäßig quervernetzte Seiten anfassen, ist `--dirty` für verbindliche Builds unsicher — immer den Default `bin/rails mkdocs:build` verwenden.

### Warum das Rollback passiert ist (Historie für zukünftige Maintainer)

Falls in der git-Historie ein `MkDocsBuild` overcommit Hook, eine `.overcommit.yml` oder `bin/overcommit/mkdocs-build-on-docs-change` erwähnt wird: diese existierten kurzzeitig und wurden entfernt. Im produktiven `git commit` Pfad wurde das Hook-Skript nie wirklich ausgeführt, obwohl overcommit `[MkDocsBuild] OK` meldete. Ein Proof-of-Life `echo >> /tmp/proof.log` auf Zeile 2 des Skripts feuerte bei realen Commits nicht, wohl aber bei `bundle exec overcommit --run`. Der fehlschlagende Dog-Food-Commit war `59c0d7ee`, dessen `public/docs/` Tree zum Commit-Zeitpunkt veraltet war obwohl der Source-Edit gelandet ist — exakte G-02-Reproduktion. Das Rollback ist im Commit-Log dokumentiert; die vollständige Root-Cause-Analyse liegt in `.planning/quick/260415-26d-public-docs-build-hardening-via-overcomm/260415-26d-POSTMORTEM.md`. Der Ersatz-Ansatz für diese Drift-Klasse ist auf eine zukünftige Milestone verschoben und wird wahrscheinlich ein CI-Guard sein, kein weiterer pre-commit Hook.

### Siehe auch

- `lib/tasks/mkdocs.rake` — die zugrundeliegende Build-Task
- `.planning/quick/260415-26d-public-docs-build-hardening-via-overcomm/260415-26d-POSTMORTEM.md` — warum der overcommit Hook zurückgerollt wurde

---

## Lokale Entwicklung

### 🛠️ Setup

```bash
# Python-Umgebung aktivieren
cd carambus_api

# Dependencies installieren
pip install -r requirements.txt

# Dokumentation lokal starten
mkdocs serve

# Dokumentation bauen
mkdocs build
```

### 🌐 Lokaler Server

- **URL**: `http://127.0.0.1:8000/carambus-docs/`
- **Live-Reload**: Automatische Aktualisierung bei Änderungen
- **Sprachumschaltung**: Verfügbar in der Navigation

### 📁 Neue Dokumentation hinzufügen

1. **Datei erstellen**: `docs/de/neue_seite.md`
2. **Navigation erweitern**: In `mkdocs.yml` hinzufügen
3. **Englische Übersetzung**: `docs/en/neue_seite.md` erstellen
4. **Testen**: `mkdocs serve` ausführen

## Features

### 🔍 Suche

- **Volltextsuche** in beiden Sprachen
- **Suchvorschläge** während der Eingabe
- **Sprachspezifische** Suchergebnisse

### 📱 Responsive Design

- **Mobile-optimiert** durch Material Theme
- **Touch-freundlich** für Tablets und Smartphones
- **Dark Mode** Unterstützung

### 🎨 Customization

- **Indigo** als Primärfarbe
- **Carambus-Branding** integriert
- **Professionelles** Design

### 📊 ER-Diagramme

- **Mermaid** Integration für ER-Diagramme
- **Interaktive** Diagramme
- **Responsive** Darstellung

## Deployment

### 🚀 GitHub Actions

- **Automatischer Build** bei jedem Push
- **Artifact-Upload** für Download
- **30 Tage Retention** für Artifacts

### 📥 Artifact-Download

1. **GitHub Actions** öffnen: `https://github.com/GernotUllrich/carambus/actions`
2. **"Build Documentation"** Workflow auswählen
3. **"documentation-build"** Artifact herunterladen
4. **Entpacken** und auf Webserver deployen

### 🌐 GitHub Pages (Optional)

Für automatisches Online-Deployment:

1. **GitHub Pages** in Repository-Einstellungen aktivieren
2. **Source**: `gh-pages` Branch oder `/docs` Ordner
3. **Workflow erweitern** um GitHub Pages Deployment

## Best Practices

### 📝 Dokumentation schreiben

- **Klare Struktur** mit Überschriften
- **Code-Beispiele** mit Syntax-Highlighting
- **Bilder** in `docs/assets/` speichern
- **Links** zwischen verwandten Seiten

### 🔗 Links und Navigation

- **Relative Links** verwenden: `[Text]&#40;datei.md&#41;`
- **Anker-Links** für Abschnitte: `[Text]&#40;datei.md#abschnitt&#41;`
- **Externe Links** mit vollständiger URL

### 🖼️ Bilder und Medien

```markdown
![Alt-Text]&#40;assets/bild.png&#41;{width="100%"}
![Alt-Text]&#40;assets/bild.png&#41;{: .center width="50%"}
```

### ⚠️ Warnungen und Hinweise

```markdown
!!! warning "Wichtiger Hinweis"
    Hier steht der wichtige Text.

!!! info "Information"
    Hier steht eine Information.

!!! tip "Tipp"
    Hier steht ein nützlicher Tipp.
```

## Troubleshooting

### 🔧 Häufige Probleme

#### Port bereits belegt
```bash
# Anderen Port verwenden
mkdocs serve --dev-addr=127.0.0.1:8001
```

#### Fehlende Dependencies
```bash
# Dependencies neu installieren
pip install -r requirements.txt --upgrade
```

#### Build-Fehler
```bash
# Validierung der Konfiguration
mkdocs build --strict
```

### 📋 Debugging

- **Logs prüfen**: Detaillierte Ausgabe bei Build-Fehlern
- **Konfiguration validieren**: `mkdocs build --strict`
- **Dependencies checken**: `pip list | grep mkdocs`

## Fazit

Die MkDocs-Integration bietet eine professionelle, mehrsprachige Dokumentation mit:

- ✅ **Automatischem CI/CD** über GitHub Actions
- ✅ **Vollständiger Zweisprachigkeit** (DE/EN)
- ✅ **Responsive Design** für alle Geräte
- ✅ **Professionellem Material Theme**
- ✅ **Einfacher Wartung** und Erweiterung

Die Dokumentation ist ein wichtiger Bestandteil des Carambus-Projekts und wird kontinuierlich gepflegt und erweitert.
