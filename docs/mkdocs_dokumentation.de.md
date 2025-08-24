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

- **Relative Links** verwenden: `[Text](datei.md)`
- **Anker-Links** für Abschnitte: `[Text](datei.md#abschnitt)`
- **Externe Links** mit vollständiger URL

### 🖼️ Bilder und Medien

```markdown
![Alt-Text](assets/bild.png){width="100%"}
![Alt-Text](assets/bild.png){: .center width="50%"}
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