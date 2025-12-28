# MkDocs Documentation for Carambus

## Overview

The Carambus project uses **MkDocs** with the **Material Theme** and **mkdocs-static-i18n** plugin for multilingual, professional documentation. Documentation is automatically built via GitHub Actions and provided as an artifact.

## Architecture

### 📁 Directory Structure

```
carambus_api/
├── mkdocs.yml                 # Main configuration
├── requirements.txt           # Python dependencies
├── docs/                      # Consolidated documentation
│   ├── index.md              # Main homepage
│   ├── assets/               # Images and media
│   ├── changelog/            # Change log
│   ├── de/                   # German documentation
│   │   ├── README.md
│   │   ├── DEVELOPER_GUIDE.md
│   │   ├── tournament.md
│   │   └── ...
│   └── en/                   # English documentation
│       ├── README.md
│       ├── DEVELOPER_GUIDE.md
│       ├── tournament.md
│       └── ...
├── .github/workflows/
│   └── build-docs.yml        # CI/CD workflow
└── site/                     # Built documentation (generated)
```

### 🌐 Multilingual Support

The project uses the **mkdocs-static-i18n** plugin for complete bilingual support:

- **German (de)**: Default language, displayed first
- **English (en)**: Second language, fully translated
- **Language Switcher**: Automatically available in navigation
- **Separate Navigation**: Each language has its own menu structure

## Configuration

### 🎨 Theme and Design

```yaml
theme:
  name: material
  features:
    - navigation.tabs      # Tab navigation
    - search.suggest       # Search suggestions
    - header.autohide      # Auto-hide header
  palette:
    - scheme: default
      primary: indigo      # Primary color
    - scheme: slate        # Dark mode
      primary: indigo
```

### 📋 Navigation

Navigation is configured for both languages:

```yaml
nav:
  - Home: index.md
  - Introduction:
      - About: about.md
      - README: README.md
  - User Guide:
      - Tournament Management: tournament.md
      - Table Reservation: table_reservation_heating_control.md
      - Scoreboard Setup: scoreboard_autostart_setup.md
      - Mode Switcher: mode_switcher.md
  - Developer Guide:
      - Developer Guide: DEVELOPER_GUIDE.md
      - Database Design: database_design.md
      - Database Syncing: database_syncing.md
      - Paper Trail Optimization: paper_trail_optimization.md
  - Admin Guide:
      - Admin Roles: admin_roles.md
      - Data Management: data_management.md
      - Filter Popup Usage: filter_popup_usage.md
  - Reference:
      - ER Diagram: er_diagram.md
      - API: API.md
      - Terms: terms.md
      - Privacy: privacy.md
```

### 🔌 Plugins

```yaml
plugins:
  - search                    # Full-text search
  - i18n:                     # Multilingual support
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

### 📝 Markdown Extensions

```yaml
markdown_extensions:
  - pymdownx.highlight        # Syntax highlighting
  - pymdownx.superfences      # Code blocks and ER diagrams
  - toc:                      # Table of contents
      permalink: true
  - admonition                # Warnings and notes
  - attr_list                 # Attributes for images
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
mkdocs-static-i18n>=1.0.0     # Multilingual support
pymdown-extensions>=10.0.0    # Markdown extensions
```

## Local Development

### 🛠️ Setup

```bash
# Activate Python environment
cd carambus_api

# Install dependencies
pip install -r requirements.txt

# Start documentation locally
mkdocs serve

# Build documentation
mkdocs build
```

### 🌐 Local Server

- **URL**: `http://127.0.0.1:8000/carambus-docs/`
- **Live Reload**: Automatic update on changes
- **Language Switcher**: Available in navigation

### 📁 Adding New Documentation

1. **Create file**: `docs/de/neue_seite.md`
2. **Extend navigation**: Add in `mkdocs.yml`
3. **English translation**: Create `docs/en/neue_seite.md`
4. **Test**: Run `mkdocs serve`

## Features

### 🔍 Search

- **Full-text search** in both languages
- **Search suggestions** during typing
- **Language-specific** search results

### 📱 Responsive Design

- **Mobile-optimized** via Material Theme
- **Touch-friendly** for tablets and smartphones
- **Dark mode** support

### 🎨 Customization

- **Indigo** as primary color
- **Carambus branding** integrated
- **Professional** design

### 📊 ER Diagrams

- **Mermaid** integration for ER diagrams
- **Interactive** diagrams
- **Responsive** display

## Deployment

### 🚀 GitHub Actions

- **Automatic build** on every push
- **Artifact upload** for download
- **30 days retention** for artifacts

### 📥 Artifact Download

1. **Open GitHub Actions**: `https://github.com/GernotUllrich/carambus/actions`
2. **Select "Build Documentation"** workflow
3. **Download "documentation-build"** artifact
4. **Extract** and deploy on web server

### 🌐 GitHub Pages (Optional)

For automatic online deployment:

1. **Activate GitHub Pages** in repository settings
2. **Source**: `gh-pages` branch or `/docs` folder
3. **Extend workflow** for GitHub Pages deployment

## Best Practices

### 📝 Writing Documentation

- **Clear structure** with headings
- **Code examples** with syntax highlighting
- **Images** stored in `docs/assets/`
- **Links** between related pages

### 🔗 Links and Navigation

- **Use relative links**: `[Text](file.md)`
- **Anchor links** for sections: `[Text](file.md#section)`
- **External links** with full URL

### 🖼️ Images and Media

```markdown
![Alt Text](assets/image.png){width="100%"}
![Alt Text](assets/image.png){: .center width="50%"}
```

### ⚠️ Warnings and Notes

```markdown
!!! warning "Important Note"
    Important text goes here.

!!! info "Information"
    Information goes here.

!!! tip "Tip"
    Useful tip goes here.
```

## Troubleshooting

### 🔧 Common Problems

#### Port Already in Use
```bash
# Use different port
mkdocs serve --dev-addr=127.0.0.1:8001
```

#### Missing Dependencies
```bash
# Reinstall dependencies
pip install -r requirements.txt --upgrade
```

#### Build Errors
```bash
# Validate configuration
mkdocs build --strict
```

### 📋 Debugging

- **Check logs**: Detailed output on build errors
- **Validate configuration**: `mkdocs build --strict`
- **Check dependencies**: `pip list | grep mkdocs`

## Conclusion

The MkDocs integration provides professional, multilingual documentation with:

- ✅ **Automatic CI/CD** via GitHub Actions
- ✅ **Complete bilingual support** (DE/EN)
- ✅ **Responsive design** for all devices
- ✅ **Professional Material Theme**
- ✅ **Easy maintenance** and extension

The documentation is an important part of the Carambus project and is continuously maintained and extended.



