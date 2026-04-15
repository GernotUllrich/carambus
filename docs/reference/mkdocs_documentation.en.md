# MkDocs Documentation for Carambus

## Overview

The Carambus project uses **MkDocs** with the **Material Theme** and **mkdocs-static-i18n** plugin for multilingual, professional documentation. The documentation is automatically built via GitHub Actions and provided as an artifact.

## Architecture

### 📁 Directory Structure

```
carambus_api/
├── mkdocs.yml                 # Main configuration
├── requirements.txt           # Python dependencies
├── docs/                      # Consolidated documentation
│   ├── index.md              # Main homepage
│   ├── assets/               # Images and media
│   ├── changelog/            # Changelog
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
- **Language switching**: Automatically available in navigation
- **Separate navigation**: Each language has its own menu structure

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

The navigation is configured for both languages:

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

## Pre-commit Hook: Local Auto-Rebuild

Since `public/docs/` is git-tracked and served directly by Rails at `/docs/`, any drift between `docs/**/*.md` (source) and `public/docs/**/*` (generated output) silently ships stale content. This was the root cause of v7.0 UAT gap **G-02**, where `public/docs/` had been stale since 2026-03-18 and four weeks of doc edits had no user-visible effect.

Quick task `260415-26d` (commit `912bf72a`) installed an **overcommit pre-commit hook** (`MkDocsBuild`) that eliminates this class of bug structurally on the developer's workstation.

### How it fires

```
git commit
    │
    ├── Does the staged set contain any docs/**/*.md file?
    │
    ├── no  → Hook does not execute (0 ms overhead)
    │          overcommit's `include:` filter short-circuits.
    │          bin/rails is not even loaded.
    │
    └── yes → Hook runs bin/overcommit/mkdocs-build-on-docs-change
              ├── Check `command -v mkdocs` (fail fast if CLI missing)
              ├── Run `bin/rails mkdocs:build`
              │     ├── mkdocs rebuilds ALL pages — not incremental
              │     └── FileUtils.cp_r site/* → public/docs/
              └── `git add public/docs/`
                    Regenerated files are folded into the
                    in-progress commit atomically.
```

### Fire conditions (what actually triggers a rebuild)

| Commit touches | Hook fires? | Overhead |
|---|---|---|
| Only `.rb`, `.erb`, `.js`, `.yml`, etc. | No | 0 ms |
| One `docs/foo.en.md` edit | Yes | ~7 s |
| 30 doc files in one commit | Yes | ~7 s (same build) |
| Only `public/docs/` (shouldn't happen, but...) | No | 0 ms |
| `SKIP=MkDocsBuild git commit …` | No | 0 ms (documented bypass) |

### Measured build time

On this workstation a full `bin/rails mkdocs:build` takes **~7 seconds wall-clock** (5.2 s pure `mkdocs build` + site → public/docs copy). For the current ~270-page bilingual docset this is dominated by template rendering, not I/O.

### Why the hook always does a FULL rebuild

MkDocs does not support reliable incremental builds. The `--dirty` flag exists but is explicitly documented as a development-loop optimisation for `mkdocs serve`; it skips nav/cross-link regeneration and produces incorrect output when links between pages change. Since GSD workflows routinely touch cross-referenced pages, `--dirty` is unsafe here.

### Expected overhead by commit pattern

The hook is designed around the observation that **most GSD commits don't touch docs**. The `include:` filter makes code-heavy phases cost nothing.

| Workflow pattern | Doc commits | Hook overhead |
|---|---|---|
| Pure code refactoring (e.g. v1.0 TableMonitor) | 0 | **0 s total** |
| Mixed phase, 1–2 doc touches (e.g. typical v7.0 phase) | 1–2 | **7–14 s** |
| Doc-heavy audit phase (e.g. v7.0 Phase 36a, 58 findings) | ~8 | **~56 s** over the entire phase |
| Pure documentation milestone (e.g. v6.0, ~12 plans, mostly docs) | 15–20 | **~2 minutes** over the entire milestone |

These are cumulative overheads across an entire phase/milestone, not per commit. The hook is not hot on the path of normal refactoring work.

### Activation on a fresh clone

The hook is **not automatically active** after `git clone` — overcommit requires explicit opt-in for safety (it will not run an unsigned hook config):

```bash
bundle exec overcommit --install
bundle exec overcommit --sign
```

`--sign` must be re-run after every `.overcommit.yml` edit. Prerequisite: the mkdocs CLI must be installed locally (`pip install mkdocs-material mkdocs-static-i18n pymdown-extensions`). If the CLI is missing when the hook fires, the commit is aborted with a clear install instruction rather than silently skipped.

### Bypass for emergencies

```bash
SKIP=MkDocsBuild git commit -m "..."
```

This is documented for exceptional cases (e.g. committing a fix while the mkdocs build is temporarily broken). The next commit that touches `docs/**/*.md` will regenerate everything anyway, so drift is recovered on the next doc commit.

### See also

- `docs/developers/overcommit-hooks.en.md` — activation walkthrough, troubleshooting, bypass details
- `.overcommit.yml` — hook registration (MkDocsBuild is the only enabled hook; overcommit default hooks are intentionally disabled because `BrokenSymlinks` conflicted with pre-existing intentional external symlinks in this repo)
- `bin/overcommit/mkdocs-build-on-docs-change` — the hook script itself
- `lib/tasks/mkdocs.rake` — the underlying build task (unchanged by this work)

---

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
- **Live-reload**: Automatic updates on changes
- **Language switching**: Available in navigation

### 📁 Adding New Documentation

1. **Create file**: `docs/en/new_page.md`
2. **Extend navigation**: Add to `mkdocs.yml`
3. **German translation**: Create `docs/de/new_page.md`
4. **Test**: Run `mkdocs serve`

## Features

### 🔍 Search

- **Full-text search** in both languages
- **Search suggestions** while typing
- **Language-specific** search results

### 📱 Responsive Design

- **Mobile-optimized** through Material Theme
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
4. **Extract** and deploy to web server

### 🌐 GitHub Pages (Optional)

For automatic online deployment:

1. **Enable GitHub Pages** in repository settings
2. **Source**: `gh-pages` branch or `/docs` folder
3. **Extend workflow** for GitHub Pages deployment

## Best Practices

### 📝 Writing Documentation

- **Clear structure** with headings
- **Code examples** with syntax highlighting
- **Images** stored in `docs/assets/`
- **Links** between related pages

### 🔗 Links and Navigation

- **Use relative links**: `[Text]&#40;file.md&#41;`
- **Anchor links** for sections: `[Text]&#40;file.md#section&#41;`
- **External links** with full URL

### 🖼️ Images and Media

```markdown
![Alt text]&#40;assets/image.png&#41;{width="100%"}
![Alt text]&#40;assets/image.png&#41;{: .center width="50%"}
```

### ⚠️ Warnings and Notes

```markdown
!!! warning "Important Note"
    Here is the important text.

!!! info "Information"
    Here is an information.

!!! tip "Tip"
    Here is a useful tip.
```

## Troubleshooting

### 🔧 Common Issues

#### Port already in use
```bash
# Use different port
mkdocs serve --dev-addr=127.0.0.1:8001
```

#### Missing dependencies
```bash
# Reinstall dependencies
pip install -r requirements.txt --upgrade
```

#### Build errors
```bash
# Validate configuration
mkdocs build --strict
```

### 📋 Debugging

- **Check logs**: Detailed output for build errors
- **Validate configuration**: `mkdocs build --strict`
- **Check dependencies**: `pip list | grep mkdocs`

## Conclusion

The MkDocs integration provides professional, multilingual documentation with:

- ✅ **Automatic CI/CD** via GitHub Actions
- ✅ **Complete bilingual support** (DE/EN)
- ✅ **Responsive design** for all devices
- ✅ **Professional Material Theme**
- ✅ **Easy maintenance** and extension

The documentation is an important component of the Carambus project and is continuously maintained and expanded. 