---
created: 2026-05-07T02:30:00Z
title: Lokale mkdocs-Config drifted — Auto-Rebuild produziert broken href="*.md" statt href="*/" links
area: documentation / mkdocs / build-pipeline
files:
  - mkdocs.yml (mkdocs root config)
  - Gemfile / requirements.txt (mkdocs version pin)
  - config/initializers/docs_auto_rebuild.rb (Listen-based watcher; debounced rebuild on docs/**/*.md edits)
  - public/docs/**/*.html (generated output that drifts)
---

## Problem

Beim Merge von Phase 40 (origin/master, 35 Commits inkl. neue `docs/**/*.md`) hat der `config/initializers/docs_auto_rebuild.rb` Watcher in carambus_bcw `bin/rails mkdocs:build` getriggert → Hunderte `public/docs/**/*.html` regeneriert → working tree dirty.

**Diff zeigt aber Regression, nicht Update:** lokaler Rebuild produziert raw-Markdown-Pfade in Links, origin/master's pre-built HTML hat korrekte MkDocs-Pretty-URLs.

```diff
- <a href="reference/api/" class="md-tabs__link">          # origin/master (KORREKT)
+ <a href="reference/api.md" class="md-tabs__link">        # local rebuild (BROKEN)
```

Statistik: **287 Dateien geändert, 621 insertions, 1485 deletions** — lokaler Build ist *kürzer und kaputter*. Würde die Live-Doku unbrauchbar machen wenn committet.

**Discovered during:** Phase-39 Gap-01-Fix-Merge nach origin/master (Commit `cf7c0fa3`, 2026-05-07T02:25Z). Workaround: `git checkout HEAD -- public/docs/` zum Verwerfen der Auto-Rebuild-Artefakte vor jedem Push.

## Root Cause (vermutet)

Mismatched mkdocs / Plugin-Versionen zwischen:
- **Lokale Build-Umgebung in carambus_bcw** (und vermutlich master/phat/api auch): produziert `href="*.md"`
- **Build-Umgebung der Phase-40-Commits** (z. B. `c67ab550 docs(mcp): rebuild public/docs after mkdocs config update + new MCP page`): produziert `href="*/"`

Mögliche Faktoren:
1. Unterschiedliche `mkdocs`-Version (z. B. lokal älter als in Phase-40-Build)
2. Plugin-Version-Drift — `mkdocs-material`, `mkdocs-i18n` (oder Equivalente), `mkdocs-mermaid2-plugin` (Phase 40 hat Mermaid-Diagramme eingeführt)
3. mkdocs.yml-Setting `use_directory_urls: true` (Standard) vs. `false` — könnte lokal überschrieben sein oder durch Plugin-Inkompatibilität ignoriert werden
4. Unterschiedliche Python-Version unter der mkdocs läuft

## Solution-Skizze

1. **Versions-Audit** der lokalen Build-Toolchain in carambus_bcw:
   ```bash
   which mkdocs && mkdocs --version
   pip show mkdocs mkdocs-material mkdocs-mermaid2-plugin 2>/dev/null
   bundle exec ruby -e "puts ENV.to_h.slice('PYTHON', 'PYTHONPATH', 'PATH')"
   bin/rails mkdocs:build --verbose 2>&1 | head -30
   ```

2. **Vergleich mit Phase-40-Build-Stand:**
   - Welche `mkdocs`-Version wurde verwendet beim Commit `c67ab550`?
   - Gibt es eine Versions-Pin-Datei (`requirements.txt`, `Pipfile`, `Gemfile.lock`)?
   - Reproduzierbarkeit prüfen: `git checkout c67ab550 && bin/rails mkdocs:build` lokal — produziert das die committete HTML byte-genau? Wenn nein, ist es Nicht-Determinismus, nicht Versions-Drift.

3. **Pin der Toolchain** wenn nötig:
   - Lokale `mkdocs`-Versionen auf das Maß updaten/downgraden, das die committete HTML produziert
   - Optional: Versions-Pin-File anlegen + im README dokumentieren
   - Optional: GitHub-Actions-CI-Guard (siehe STATE.md Z. 192) — `mkdocs build` + `git diff --exit-code public/docs/` als gate

4. **DOCS_AUTO_REBUILD=0 als interim opt-out** für carambus_bcw / phat / api falls der Drift dort dauerhaft besteht — nur `carambus_master` rebuildet docs, dann commit + push, andere pullen das pre-built HTML. Das passt auch zum `scenario-management` SKILL (Edits nur in master).

## Verifikation

Nach Fix sollte gelten:
- `bin/rails mkdocs:build` in jedem der 4 Checkouts produziert `git status --short public/docs/` = leer (deterministisch)
- `git diff` zwischen zwei aufeinanderfolgenden Builds ist leer
- Live-Doku-Site (über NGINX/Capistrano) zeigt funktionierende Links auf `/reference/api/` etc.

**Schweregrad:** Mittel-hoch. Bedrohung: jeder zukünftige `git pull` in einem deployment-Checkout, der `docs/**/*.md` enthält, triggert den Watcher → working tree dirty → vor jedem Commit muss manuell `git checkout HEAD -- public/docs/` gefahren werden. Wenn ein Operator das vergisst und `git add .` macht, landen broken docs in production.

**Touches:**
- mkdocs / Python-Toolchain (build-system, nicht Rails-Code)
- `config/initializers/docs_auto_rebuild.rb` (optional: opt-out-Logik / version-check)
- Dokumentation für Dev-Setup
- Optional: CI-Pipeline (mkdocs-build-Gate)
- Cross-Checkout-Hygiene (alle 4 Checkouts: bcw, phat, api, master)

## Cross-References

- STATE.md Z. 192: ursprüngliche Auflösung des `public/docs/`-manual-rebuild-gaps via Listen-watcher (2026-05-05)
- Quick-Task `260415-26d`: vorheriger Versuch via overcommit pre-commit hook → rolled back
- Phase 40 Commits `c67ab550` + `070563f0`: Mermaid + neue MCP-Doku → introduced docs that exposed the drift
