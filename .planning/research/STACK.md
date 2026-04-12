# Stack Research: Documentation Quality Audit (v6.0)

**Domain:** Documentation audit and update for mkdocs-material + multilingual docs against a Rails 7.2 codebase
**Researched:** 2026-04-12
**Confidence:** HIGH (existing toolchain read directly from codebase; no speculation about installed versions)

---

## Decision Summary

v6.0 is a documentation audit milestone, not a code milestone. The four work streams are:

1. **Audit docs against codebase** — find stale references to deleted classes (UmbScraperV2, old model structures)
2. **Fix/remove broken internal links** — 74 broken links already identified by `bin/check-docs-links.rb`
3. **Document 37 new services from v1.0–v5.0** — services exist in code with no corresponding doc pages
4. **Verify multilingual consistency** — 89 `.de.md` files vs. 63 `.en.md` files, 26 pages missing English translation

**Net result: Zero new gems, zero new Python packages required for this milestone.**

The codebase already has all the tooling needed:

- `bin/check-docs-links.rb` — link checker (already ran, identified 74 broken links)
- `bin/fix-docs-links.rb` — pattern-based link fixer (dry-run mode)
- `lib/tasks/mkdocs.rake` — `mkdocs:build`, `mkdocs:serve`, `mkdocs:deploy`
- `mkdocs` 1.6.1 + `mkdocs-material` 9.6.15 + `mkdocs-static-i18n` 1.3.0 (all installed at `~/Library/Python/3.12/`)

The only "stack" question for v6.0 is: which scripts/approaches handle the four audit tasks, and what (if anything) is missing from the existing toolchain.

---

## Recommended Stack

### Core Technologies (all already installed)

| Technology | Version | Purpose | Why Sufficient |
|------------|---------|---------|----------------|
| `mkdocs` | 1.6.1 | Build/serve docs site, strict mode | `mkdocs build --strict` exits non-zero on warnings including unresolved nav entries. Use for CI-style validation. |
| `mkdocs-material` | 9.6.15 | Theme with i18n integration | Already configured. No changes to theme needed. |
| `mkdocs-static-i18n` | 1.3.0 | `.de.md` / `.en.md` suffix-based multilingual docs | Already configured with `docs_structure: suffix`. Source of truth for which translations exist. |
| Ruby (stdlib) | 3.2.1 | `bin/check-docs-links.rb`, `bin/fix-docs-links.rb` | Custom scripts already exist. Use them; extend rather than replace. |

### Existing Audit Scripts

| Script | What It Does | Current Gaps |
|--------|-------------|--------------|
| `bin/check-docs-links.rb` | Checks all 177 markdown files for broken internal links; reports 74 broken as of last run | Does not check `mkdocs.yml` nav entries against files on disk; does not validate anchors |
| `bin/fix-docs-links.rb` | Pattern-based batch fixer for common broken link patterns (language suffix removal, path prefix fixes) | Fix patterns hardcoded for old v1/v2 restructure; some patterns may no longer apply |
| `lib/tasks/mkdocs.rake` | `build`, `clean`, `serve`, `deploy` via `bundle exec rake mkdocs:*` | No `mkdocs:lint` or `mkdocs:check` task; would be useful addition |

### What Is Missing (and Needs to be Built)

The audit requires three things the existing tools do not cover:

#### 1. Stale-Reference Detector (new Ruby script, ~40 lines)

A script that walks `docs/**/*.md`, extracts class/module names (`CamelCase` tokens), and checks each against the live codebase (`app/**/*.rb`, `lib/**/*.rb`) — flagging names that appear in docs but not in code. This catches references to deleted classes like `UmbScraperV2`, `tournament_monitor_support`, old model names.

**Implementation:** Shell one-liner or simple Ruby. No gem required.

```bash
# Quick version (finds CamelCase doc references not in code):
grep -roh '\b[A-Z][a-zA-Z0-9]*\b' docs/ | sort -u > /tmp/doc_names.txt
grep -roh '\b[A-Z][a-zA-Z0-9]*\b' app/ lib/ | sort -u > /tmp/code_names.txt
comm -23 /tmp/doc_names.txt /tmp/code_names.txt
```

This is a starting point, not a complete solution — the output has false positives (English words, abbreviations). The real value is scoping the work: look at which service class names in docs don't exist in `app/services/`.

#### 2. Translation Coverage Report (new Ruby script, ~30 lines)

A script that compares `.de.md` files against `.en.md` files and reports which pages have only one language. The current situation: 89 `.de.md` vs 63 `.en.md` — 26 pages lack English translations (or vice versa). `mkdocs-static-i18n` silently falls back to the default language (`de`) for missing translations; there is no built-in warning.

**Implementation:** Walk `docs/` directory, group by base name (strip locale suffix), report bases with only one locale.

```ruby
# ~15 lines: find base names with missing locale counterpart
de_files = Dir.glob('docs/**/*.de.md').map { |f| f.sub('.de.md', '') }.to_set
en_files = Dir.glob('docs/**/*.en.md').map { |f| f.sub('.en.md', '') }.to_set
(de_files - en_files).each { |f| puts "Missing EN: #{f}.en.md" }
(en_files - de_files).each { |f| puts "Missing DE: #{f}.de.md" }
```

Add as `bin/check-docs-translations.rb`.

#### 3. Extend `mkdocs.rake` with Lint Task

Add `mkdocs:check` that runs `mkdocs build --strict 2>&1` and reports errors. MkDocs `--strict` mode converts warnings to errors, catching:
- Nav entries referencing non-existent files
- Broken nav structure
- Plugin configuration errors

This is a one-liner rake task wrapping the existing `mkdocs build`.

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `mkdocs-linkcheck` (PyPI) | Adds Python dependency for external URL checking only. 74 known broken links are all internal. External link checking is out of scope for v6.0. | `bin/check-docs-links.rb` (already handles internal links correctly) |
| `linkcheckmd` (PyPI) | Same problem — external link focus, no value for internal link audit. | Existing Ruby script |
| Automated translation services (DeepL, Google Translate) | v6.0 goal is consistency verification, not generating new translations. Auto-translated docs with wrong content are worse than acknowledged gaps. | Flag missing translations; write them manually or explicitly defer |
| `rdoc` / YARD integration with mkdocs | Complex toolchain to auto-generate API docs from Ruby source. Adds build pipeline complexity not warranted for an audit milestone. | Manual service documentation following existing patterns in `docs/developers/` |
| `mike` (versioning) | Already in `mkdocs.yml` as version provider but not actively used. Do not activate for v6.0 — adds deployment complexity, no audit value. | Leave in config, do not configure |
| Sphinx / ReadTheDocs migration | Major infrastructure change. mkdocs-material is already well-configured and working. | Stay with existing mkdocs setup |

---

## Audit Workflow (No New Stack Required)

For each of the four work streams, the approach using existing tools:

**Stream 1 — Stale references:**
```bash
# Find docs that mention deleted class names
grep -rl "UmbScraperV2\|tournament_monitor_support\|TableMonitor.*3900\|RegionCc.*2700" docs/
# Extend to: any CamelCase name in docs not found in app/ (see stale-reference script above)
```

**Stream 2 — Broken links:**
```bash
ruby bin/check-docs-links.rb --exclude-archives
# Then: ruby bin/fix-docs-links.rb --live  (for automatable patterns)
# Manual fix for the rest (74 broken links, grouped by file)
```

**Stream 3 — New service documentation:**
```bash
# Cross-reference: which services have no doc page
ls app/services/**/*.rb | sed 's|app/services/||; s|\.rb||' > /tmp/services.txt
# grep docs/ for each service name, flag undocumented ones
```

**Stream 4 — Multilingual consistency:**
```bash
ruby bin/check-docs-translations.rb  # (new script to create)
```

---

## Version Compatibility

| Package | Version | Compatible With | Notes |
|---------|---------|-----------------|-------|
| mkdocs | 1.6.1 | mkdocs-material 9.6.15 | MEDIUM confidence — mkdocs 1.6.x + material 9.6.x is the current stable pairing. No known incompatibilities. |
| mkdocs-material | 9.6.15 | mkdocs-static-i18n 1.3.0 | HIGH confidence — `reconfigure_material: true` in mkdocs.yml already works (docs build currently succeeds). |
| mkdocs-static-i18n | 1.3.0 | mkdocs 1.6.1 | HIGH confidence — installed and configured with `docs_structure: suffix`, `fallback_to_default: true`. Current working state. |
| pymdown-extensions | 10.16 | mkdocs-material 9.6.15 | HIGH confidence — installed, all extensions in mkdocs.yml are loading without error. |

---

## Installation (nothing new required)

```bash
# Already installed — verify with:
mkdocs --version
# mkdocs, version 1.6.1

# Serve locally:
bundle exec rake mkdocs:serve
# OR directly:
mkdocs serve

# Build with strict mode (proposed new task):
mkdocs build --strict
```

New scripts to create (no dependencies):

```bash
# Translations coverage report
bin/check-docs-translations.rb  # ~30 lines of stdlib Ruby

# Stale reference scanner (optional, can be a one-liner)
bin/check-docs-coderef.rb       # ~50 lines of stdlib Ruby
```

---

## Sources

- `bin/check-docs-links.rb` — custom link checker, already identifies 74 broken links
- `bin/fix-docs-links.rb` — pattern-based link fixer with dry-run mode
- `lib/tasks/mkdocs.rake` — existing mkdocs Rake task
- `mkdocs.yml` — current configuration: material 9.x, static-i18n 1.3.0, suffix structure, de default
- `requirements.txt` — Python deps: mkdocs-material>=9.5.0, mkdocs-static-i18n>=1.0.0, pymdown-extensions>=10.0.0
- `docs/BROKEN_LINKS_REPORT.txt` — 74 broken links across 177 markdown files (current state)
- Installed packages: mkdocs 1.6.1, mkdocs-material 9.6.15, mkdocs-static-i18n 1.3.0, pymdown-extensions 10.16
- `find docs -name "*.de.md" | wc -l` → 89; `find docs -name "*.en.md" | wc -l` → 63 (26-page translation gap)
- https://pypi.org/project/mkdocs-linkcheck/ — external link checker, assessed as out-of-scope for v6.0
- https://github.com/ultrabug/mkdocs-static-i18n — no built-in consistency check; missing translations silently fall back

---

*Stack research for: Documentation Quality Audit (v6.0)*
*Researched: 2026-04-12*
