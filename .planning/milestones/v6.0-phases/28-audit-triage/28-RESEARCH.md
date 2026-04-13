# Phase 28: Audit & Triage - Research

**Researched:** 2026-04-12
**Domain:** MkDocs documentation audit tooling for a Rails 7.2 app; Ruby stdlib scripting; git diff-based stale identifier detection; JSON report schema design
**Confidence:** HIGH — all findings from direct codebase inspection; no speculative claims

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Dual output — `docs/audit.json` (machine-parseable, structured by category) AND `docs/DOCS-AUDIT-REPORT.md` (human-readable summary with sections: broken links, stale refs, coverage gaps, bilingual gaps)
- **D-02:** The JSON enables automated tracking across phases (e.g., Phase 29 can parse FIX items, Phase 31 can parse DOC items). The markdown is for human review.
- **D-03:** Comprehensive git diff approach — diff all deleted/renamed files across v1.0–v5.0 git tags to build the stale identifier list. Catches everything, not just known targets.
- **D-04:** Use git tags (v1.0, v2.0, v2.1, v3.0, v4.0, v5.0) to compute the full set of deleted/renamed Ruby files, then grep docs/ for any reference to those names.
- **D-05:** Fix archive search indexing in Phase 28 — add `exclude_docs` or equivalent in `mkdocs.yml` to prevent `archive/` and `obsolete/` from appearing in site search results. This is a config change, not a content edit.

### Claude's Discretion

- JSON schema design for audit.json (categories, fields, severity levels)
- How to handle false positives in the git diff (e.g., files renamed but still referenced correctly)
- Whether `check-docs-coderef.rb` should be a separate script or integrated into `check-docs-links.rb`

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUDIT-01 | Build complete staleness inventory — broken links + code identifier sweep + coverage gap map — before any content editing | Covered by: git diff v1.0..v5.0 deleted file list (verified), stale identifier grep findings (verified), broken links baseline from BROKEN_LINKS_REPORT.txt (74 links verified), coverage gap list from FEATURES.md research (37 services verified). Output format: dual audit.json + DOCS-AUDIT-REPORT.md per D-01/D-02. |
| AUDIT-02 | Create `bin/check-docs-translations.rb` script for translation coverage reporting (de vs en file pairs) | Covered by: pattern from bin/check-docs-links.rb (verified), translation gap data (89 de vs 63 en files — verified by wc), in-nav gap (managers/table-reservation.md has no .de.md — verified). Stdlib-only Ruby implementation confirmed. |
| AUDIT-03 | Add `mkdocs:check` rake task wrapping `mkdocs build --strict` for CI-ready doc validation | Covered by: existing lib/tasks/mkdocs.rake pattern (verified), mkdocs 1.6.1 installed and confirms --strict flag support (verified). One new task appended to existing file. |
</phase_requirements>

---

## Summary

Phase 28 is a pure tooling and inventory phase. Its output — `docs/audit.json` and `docs/DOCS-AUDIT-REPORT.md` — gates all five subsequent phases (29–32). The phase produces no content edits; it only creates two new scripts, extends one rake file, makes one mkdocs.yml config change, and writes the audit output files.

The existing toolchain is almost complete. `bin/check-docs-links.rb` (291 lines, verified working) provides the exact pattern for both new scripts. `lib/tasks/mkdocs.rake` already has four tasks; a fifth `mkdocs:check` task is a one-liner append. The `mkdocs build --strict` command is verified to work with mkdocs 1.6.1 installed at `~/Library/Python/3.12/`.

The stale identifier scope is now fully defined from the git diff: only one file was deleted (umb_scraper_v2.rb → class `UmbScraperV2`), and one was renamed (lib/tournament_monitor_support.rb → app/services/tournament_monitor/table_populator.rb → identifier `TournamentMonitorSupport`). The comprehensive git diff catches both. Active doc occurrences of these identifiers have been verified: 4 files reference `tournament_monitor_support`/`TournamentMonitorSupport`, 1 file references `UmbScraperV2`. All are confirmed in non-archive active docs.

**Primary recommendation:** Implement in strict wave order — (1) scripts + rake task first as testable deliverables, (2) run the audit, (3) write the output files, (4) apply the mkdocs.yml config change. Each step produces a verifiable artifact.

---

## Standard Stack

### Core (all already installed — zero new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| mkdocs | 1.6.1 | `mkdocs build --strict` for CI validation | Already installed at `~/Library/Python/3.12/`; `--strict` converts warnings to errors |
| mkdocs-material | 9.6.15 | Docs theme; `exclude_docs` support | Already configured and working |
| Ruby stdlib | 3.2.1 | `bin/check-docs-translations.rb`, `bin/check-docs-coderef.rb` | Project pattern: bin/ scripts use stdlib only, no gems |
| git | system | `git diff --diff-filter=D --name-only v1.0 v5.0` for stale identifier extraction | Tags v1.0 through v5.0 all verified present |

**Installation:** Nothing to install. All tools already present.

### Existing Scripts (reuse pattern, do not replace)

| Script | Lines | What to Reuse |
|--------|-------|--------------|
| `bin/check-docs-links.rb` | 291 | `Find.find` walk, `DOCS_ROOT = Pathname.new(__dir__).join('..', 'docs').expand_path` pattern, color constants, exit code convention |
| `bin/fix-docs-links.rb` | 172 | `find_markdown_files` with exclude pattern filter |
| `lib/tasks/mkdocs.rake` | 74 | Task namespace, `system("which mkdocs > /dev/null 2>&1")` guard pattern |

---

## Architecture Patterns

### Recommended File Locations

```
bin/
├── check-docs-links.rb        # EXISTS — link checker (pattern source)
├── check-docs-translations.rb # CREATE — AUDIT-02 deliverable
└── check-docs-coderef.rb      # CREATE — supports AUDIT-01

lib/tasks/
└── mkdocs.rake                # EXTEND — append mkdocs:check task

docs/
├── audit.json                 # CREATE — machine-parseable audit output (D-01)
└── DOCS-AUDIT-REPORT.md       # CREATE — human-readable audit summary (D-01)

mkdocs.yml                     # EDIT — add exclude_docs for archive/ (D-05)
```

### Pattern 1: Ruby stdlib Doc Audit Script

**What:** Standalone scripts in `bin/` using only Ruby stdlib (`Pathname`, `Find`, `Set`, `JSON`). Start with frozen string literal. Accept `--help` flag. Exit 0 on clean, 1 on findings. Print colored output using ANSI codes.

**When to use:** All doc tooling scripts in this project.

**Example — translation checker core (AUDIT-02):**
```ruby
# Source: modeled on bin/check-docs-links.rb pattern (VERIFIED: codebase read)
#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pathname'
require 'set'

DOCS_ROOT = Pathname.new(__dir__).join('..', 'docs').expand_path

de_files = Dir.glob(DOCS_ROOT.join('**', '*.de.md'))
              .map { |f| Pathname.new(f).sub_ext('').sub_ext('').to_s }
              .to_set
en_files = Dir.glob(DOCS_ROOT.join('**', '*.en.md'))
              .map { |f| Pathname.new(f).sub_ext('').sub_ext('').to_s }
              .to_set

missing_en = (de_files - en_files).sort
missing_de = (en_files - de_files).sort

missing_en.each { |f| puts "MISSING_EN: #{f}.en.md" }
missing_de.each { |f| puts "MISSING_DE: #{f}.de.md" }

exit(missing_en.empty? && missing_de.empty? ? 0 : 1)
```

**Example — stale coderef checker core (supports AUDIT-01):**
```ruby
# Source: modeled on bin/check-docs-links.rb pattern (VERIFIED: codebase read)
# Extract CamelCase identifiers from docs, check each against app/ + lib/
require 'pathname'
require 'set'

DOCS_ROOT = Pathname.new(__dir__).join('..', 'docs').expand_path
APP_ROOT  = Pathname.new(__dir__).join('..').expand_path

# Build set of identifiers that exist in the codebase
live_names = Set.new
Dir.glob(APP_ROOT.join('{app,lib}', '**', '*.rb')).each do |f|
  File.basename(f, '.rb').split('_').map(&:capitalize).join.tap { |n| live_names << n }
end

# Extract CamelCase tokens from docs and report any not in live codebase
stale = []
Dir.glob(DOCS_ROOT.join('**', '*.md')).each do |f|
  next if f.include?('/archive/') || f.include?('/obsolete/')
  File.read(f).scan(/\b[A-Z][a-zA-Z0-9]{3,}\b/).uniq.each do |name|
    stale << { file: f, name: name } unless live_names.include?(name)
  end
end
```

### Pattern 2: mkdocs:check Rake Task

**What:** Append to existing `lib/tasks/mkdocs.rake` — no new file. Use the same `system("which mkdocs > /dev/null 2>&1")` guard. Run `mkdocs build --strict` and capture exit code.

**When to use:** CI validation, pre-commit hook, manual doc quality check.

**Example:**
```ruby
# Source: extends existing lib/tasks/mkdocs.rake (VERIFIED: codebase read)
# Append inside namespace :mkdocs block:
desc "Validate MkDocs documentation — strict mode, exits non-zero on any warning (CI-ready)"
task check: :environment do
  unless system("which mkdocs > /dev/null 2>&1")
    puts "Error: mkdocs is not installed."
    exit 1
  end

  puts "Running mkdocs build --strict..."
  success = system("mkdocs build --strict 2>&1")
  unless success
    puts "Error: mkdocs build failed with warnings or errors."
    puts "Fix all warnings before proceeding."
    exit 1
  end

  puts "Documentation validation passed."
end
```

### Pattern 3: exclude_docs in mkdocs.yml

**What:** MkDocs 1.5+ feature. Accepts gitignore-style patterns. Files matching `exclude_docs` are not built into the site and not indexed by search. [VERIFIED: mkdocs source at `~/Library/Python/3.12/lib/python/site-packages/mkdocs/config/defaults.py`]

**When to use:** Prevent `docs/archive/` and `docs/obsolete/` from appearing in site search results (D-05).

**Example:**
```yaml
# Source: mkdocs 1.6.1 config defaults (VERIFIED: source inspection)
# Add to mkdocs.yml after docs_dir:
exclude_docs: |
  archive/**
  obsolete/**
  internal/**
```

**Note:** `exclude_docs` removes files from site build entirely. If archive pages should remain browsable (just not in search), use `search: exclude: true` front matter on the archive index page instead. The decision (D-05) specifies "prevent archive/ from appearing in search results" — `exclude_docs` satisfies this.

### Pattern 4: audit.json Schema Design (Claude's Discretion)

**What:** Machine-parseable inventory consumed by Phases 29–32. Each finding gets a category, action bucket (DELETE/UPDATE/CREATE/FIX), severity, and source citation.

**Recommended schema:**
```json
{
  "generated_at": "ISO8601",
  "summary": {
    "total_findings": 0,
    "by_action": { "DELETE": 0, "UPDATE": 0, "CREATE": 0, "FIX": 0 },
    "by_category": { "broken_link": 0, "stale_ref": 0, "coverage_gap": 0, "bilingual_gap": 0 }
  },
  "findings": [
    {
      "id": "FIND-001",
      "category": "broken_link",
      "action": "FIX",
      "severity": "high",
      "file": "docs/relative/path.md",
      "line": 42,
      "description": "Link to deleted enhanced_mode_system.md",
      "target": "developers/enhanced_mode_system.md",
      "phase": 29
    }
  ]
}
```

**Category values:** `broken_link`, `stale_ref`, `coverage_gap`, `bilingual_gap`
**Action values:** `FIX` (broken links — Phase 29), `DELETE` (remove stale ref — Phase 29), `UPDATE` (rewrite content — Phase 30), `CREATE` (new doc needed — Phase 31)
**Severity values:** `high` (actively misleads developers), `medium` (degraded docs experience), `low` (housekeeping)

### Anti-Patterns to Avoid

- **Running check-docs-coderef.rb without false positive filtering:** CamelCase extraction from markdown produces hundreds of English words (JavaScript, YouTube, GitHub). Filter to only identifiers matching `.*Scraper|.*Monitor|.*Service|.*Calculator|.*Parser|.*Client|.*Matcher|.*Extractor|[A-Z][a-z]+[A-Z].*` pattern.
- **Writing audit.json while the inventory is still in progress:** Write the JSON only once after all checks are complete. Partial writes create inconsistent state.
- **Adding exclude_docs before verifying archive content is not in nav:** mkdocs.yml nav does not reference archive/ (confirmed). Safe to add without nav cleanup.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Stale identifier detection | Custom AST parser for Ruby class names | `git diff --diff-filter=D --name-only v1.0 v5.0 -- app/ lib/` + basename-to-CamelCase | Git knows exactly what was deleted; filesystem walking confirms what exists now |
| Translation gap detection | Complex YAML-driven i18n audit | `Dir.glob('**/*.de.md') - Dir.glob('**/*.en.md')` (by base name) | Suffix-based naming makes this a set difference operation |
| Broken link counting | New custom checker | `bin/check-docs-links.rb` (existing) | Already working, reports 74 broken links, exclude-archives mode included |
| Search indexing control | Custom search plugin | mkdocs `exclude_docs` top-level key | Built into mkdocs 1.5+, one config line |

---

## Verified Stale Identifiers (AUDIT-01 Input)

[VERIFIED: git diff --diff-filter=D --name-only v1.0 v5.0]

**Deleted files (git --diff-filter=D):**
- `app/services/umb_scraper_v2.rb` → identifier: `UmbScraperV2`

**Renamed files (git --diff-filter=R):**
- `lib/tournament_monitor_support.rb` → `app/services/tournament_monitor/table_populator.rb` → identifier: `TournamentMonitorSupport`, `tournament_monitor_support`

**Active doc occurrences confirmed by grep (non-archive, non-obsolete, non-internal):**

| Identifier | File | Line | Action |
|------------|------|------|--------|
| `UmbScraperV2` | `developers/umb-scraping-methods.md` | 73 | DELETE reference |
| `tournament_monitor_support` | `developers/clubcloud-upload.de.md` | 194 | UPDATE — code comment reference |
| `tournament_monitor_support` | `developers/clubcloud-upload.en.md` | 194 | UPDATE — code comment reference |
| `TournamentMonitorSupport` | `developers/tournament-architecture-overview.en.md` | 20, 35 | UPDATE — describes deleted class as active |

---

## Verified In-Nav Bilingual Gaps (AUDIT-01 Input)

[VERIFIED: Ruby script parsing mkdocs.yml nav structure against docs/ filesystem]

**Only one confirmed gap in the mkdocs nav:**

| Nav Entry | Missing File | Severity |
|-----------|-------------|---------|
| `managers/table-reservation.md` | `docs/managers/table-reservation.de.md` | Medium — DE users get EN fallback |

The previously reported de-only gap count of 26 files applies to the full docs/ directory including internal/, studies/, and archive/ which are NOT in nav. For nav-linked files, only the single `table-reservation.de.md` gap was confirmed.

---

## Verified Broken Link Root Causes (AUDIT-01 Input)

[VERIFIED: BROKEN_LINKS_REPORT.txt + filesystem checks]

| Directory | Count | Root Cause |
|-----------|-------|------------|
| `players/` | 34 | 22 missing screenshot .png files in `players/screenshots/`; bilingual (11 per language pair) |
| `developers/` | 19 | Enhanced_mode_system.md (moved to obsolete), scenario-system-workflow.md (missing), test/ paths outside docs root (5 links), wrong self-reference in testing-quickstart.md |
| `reference/` | 16 | Placeholder example links in mkdocs_dokumentation (intentional documentation examples, not real links); `../search.md` broken (should be `reference/search.md`) |
| `managers/` | 2 | `../bin/test-cc-name-mapping.rb` (outside docs root, bin/ is not docs), `logging_conventions.md` (does not exist) |
| `international/` | 2 | `international_videos.md` does not exist, `youtube_scraper.md` does not exist |
| `administrators/` | 1 | `systemd-streaming-services.md` does not exist |

**Special case — reference/mkdocs_dokumentation:** The placeholder links (`file.md`, `datei.md`, `assets/image.png`) are intentional documentation examples showing mkdocs link syntax. The audit inventory should classify these as `low` severity `FIX` items that require context judgment (delete the placeholder or replace with a real example).

---

## Common Pitfalls

### Pitfall 1: CamelCase False Positives in check-docs-coderef.rb

**What goes wrong:** Extracting all CamelCase tokens from markdown produces hundreds of false positives — English words, proper nouns, product names (YouTube, GitHub, JavaScript, MkDocs, SoopLive).

**Why it happens:** Markdown documents discuss the product in natural language, not just reference Ruby class names.

**How to avoid:** Filter extracted tokens to those that could plausibly be Ruby class identifiers. A practical filter: require at least two uppercase-initiated segments (e.g., `UmbScraper`, `VideoMatcher`), or check against a known "ignore list" of common English capitalized words. Alternatively, scope the search to content inside code blocks (``` ` ``` and ```` ``` ```` fences) where class name references are more intentional.

**Warning signs:** Script reports hundreds of "stale" identifiers including "English", "Rails", "German".

**Note on plan approach:** The plan (28-01) avoids this pitfall entirely by using git-diff-scoped identifiers rather than broad CamelCase extraction. See "Open Questions (RESOLVED)" item 1 below for the rationale.

### Pitfall 2: exclude_docs Removes Archive Pages from Site Build Entirely

**What goes wrong:** Decision D-05 says "prevent archive/ from appearing in site search results." Using `exclude_docs: archive/**` removes those pages from the build entirely — they cannot be reached by URL either. If someone has a direct link to an archive page, it returns 404.

**Why it happens:** `exclude_docs` prevents file from being built; it's not a search-only exclusion.

**How to avoid:** For D-05, `exclude_docs` is the correct choice since archive pages describing deleted code should not be directly accessible at all. Confirm this is acceptable before applying. Alternative if browsability is needed: use `search: exclude: true` in each archive page's front matter (or in an `archive/index.md` that sets the meta flag).

**Recommendation (Claude's discretion):** Use `exclude_docs` — cleaner, single config line, and archive pages describing deleted class APIs have negative value if served. [ASSUMED: acceptable to 404 archive pages; user confirmed "do not modify archive content" but not "keep archive pages accessible by URL"]

### Pitfall 3: audit.json Written Prematurely Becomes Stale Mid-Phase

**What goes wrong:** Generating audit.json as each check script runs means the file is partially populated during phase execution. Downstream phases check if audit.json exists and may read an incomplete file.

**Why it happens:** Natural temptation to generate output early.

**How to avoid:** Collect all findings into in-memory structures, write audit.json in a single final step after all checks complete. The write task is the last step of the phase.

### Pitfall 4: mkdocs:check Task Leaves site/ Directory as Build Artifact

**What goes wrong:** `mkdocs build --strict` creates a `site/` directory. If the task is used as a CI check, the side-effect build artifacts pollute the working directory or get committed.

**Why it happens:** mkdocs always builds to `site_dir` (default: `site/`).

**How to avoid:** After the check passes, the `mkdocs:check` task should clean up: call `mkdocs:clean` or `FileUtils.rm_rf(Rails.root.join("site"))`. Alternatively, use `mkdocs build --strict --site-dir /tmp/mkdocs-check-#{Time.now.to_i}` to avoid polluting the project directory.

---

## Code Examples

### Running the git diff for stale identifiers

```bash
# Source: verified against this repo's git tags (VERIFIED: git tag output)
# One deleted file: app/services/umb_scraper_v2.rb → UmbScraperV2
git diff --diff-filter=D --name-only v1.0 v5.0 -- app/ lib/ | grep '\.rb$'
# app/services/umb_scraper_v2.rb

# One renamed file: lib/tournament_monitor_support.rb
git diff --diff-filter=R --name-status v1.0 v5.0 -- app/ lib/
# R054  lib/tournament_monitor_support.rb  app/services/tournament_monitor/table_populator.rb
```

### Grepping active docs for stale identifiers

```bash
# Source: verified grep on this repo (VERIFIED: grep output confirmed)
grep -rn "UmbScraperV2\|tournament_monitor_support\|TournamentMonitorSupport" \
  docs/ --include="*.md" \
  | grep -v '/archive/' | grep -v '/obsolete/' | grep -v '/internal/'
```

### mkdocs.yml exclude_docs addition (D-05)

```yaml
# Source: mkdocs 1.6.1 config/defaults.py (VERIFIED: source inspection)
# Add after site_dir line in mkdocs.yml:
exclude_docs: |
  archive/**
  obsolete/**
```

### Translation coverage one-liner verification

```bash
# Source: derived from STACK.md research + verified file counts (VERIFIED: wc -l)
# Confirmed: 89 .de.md files, 63 .en.md files → 26 de-only base names
find docs -name "*.de.md" | sed 's/\.de\.md$//' | sort > /tmp/de_bases.txt
find docs -name "*.en.md" | sed 's/\.en\.md$//' | sort > /tmp/en_bases.txt
comm -23 /tmp/de_bases.txt /tmp/en_bases.txt  # DE-only
comm -13 /tmp/de_bases.txt /tmp/en_bases.txt  # EN-only
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| mkdocs `pages:` config key | `nav:` key | mkdocs 1.0 | `pages:` removed; `nav:` is current |
| `docs_dir` + manual nav for i18n | `mkdocs-static-i18n` with `docs_structure: suffix` | 2021 | `.de.md`/`.en.md` suffix pattern replaces per-locale folder structure |
| No `exclude_docs` | `exclude_docs: |` with gitignore patterns | mkdocs 1.5 | Single config key excludes files from build + search |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Using `exclude_docs` to remove archive pages from the site entirely is acceptable (pages return 404 rather than being search-hidden but URL-accessible) | Pattern 3 / Pitfall 2 | If user wants archive pages browsable by URL, use front matter `search: exclude: true` instead; different implementation but same config change task |
| A2 | The `check-docs-coderef.rb` script should be a separate file from `check-docs-links.rb` (not integrated) | Architecture Patterns | If user prefers a single combined checker, the script structure changes but not the logic |

---

## Open Questions (RESOLVED)

1. **False positive handling in check-docs-coderef.rb**
   - What we know: CamelCase extraction from markdown produces false positives (YouTube, GitHub, JavaScript, etc.)
   - What's unclear: Should the script use an explicit ignore list, or restrict scanning to code fences only?
   - RESOLVED: The plan uses a git-diff-scoped identifier set (only deleted/renamed filenames from `v1.0..v5.0`) matched against full file content via `Regexp.union`. This eliminates false positives entirely because the search terms are a tiny, specific set derived from git (e.g., `UmbScraperV2`, `TournamentMonitorSupport`, `tournament_monitor_support`) — not broad CamelCase extraction from markdown. The research recommendation to restrict to code fences was designed for a different approach (extracting all CamelCase tokens from docs, then checking against live codebase). With git-diff-scoped identifiers, full-text scanning is safe and preferable: it catches references in prose, headings, and inline code — not just fenced blocks. No `--full-text` flag needed; full-text is the only mode.

2. **audit.json severity classification for reference/mkdocs_dokumentation placeholder links**
   - What we know: 8 of the 16 broken links in reference/ are intentional documentation syntax examples (`[Text](file.md)`)
   - What's unclear: Should these be classified as `low FIX` items or excluded from the audit entirely?
   - RESOLVED: Include with `severity: low`, `note: "intentional documentation example"` — keeps the audit complete while clearly flagging these as non-urgent. Phase 29 planner can explicitly decide to skip them.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| mkdocs | AUDIT-03, D-05 verification | Yes | 1.6.1 | — |
| Python | mkdocs runtime | Yes | 3.13.3 | — |
| Ruby | AUDIT-02, coderef script | Yes | 3.2.1 | — |
| git tags v1.0–v5.0 | D-03/D-04 stale identifier diff | Yes (all 6 tags verified) | — | — |
| mkdocs-material | exclude_docs support | Yes | 9.6.15 | — |

**No missing dependencies.** All required tools are available.

---

## Validation Architecture

> `workflow.nyquist_validation` is explicitly `false` in `.planning/config.json` — this section is skipped.

---

## Security Domain

> Phase 28 creates no code that handles user input, authentication, or sensitive data. Scripts are read-only audit tools. No ASVS controls apply.

---

## Sources

### Primary (HIGH confidence — direct codebase inspection)
- `bin/check-docs-links.rb` — 291-line script; reuse pattern for new scripts
- `bin/fix-docs-links.rb` — 172-line fixer; file exclusion pattern
- `lib/tasks/mkdocs.rake` — 74-line rake file; extend with mkdocs:check
- `mkdocs.yml` — full site config; i18n plugin settings; no exclude_docs currently
- `docs/BROKEN_LINKS_REPORT.txt` — 74 broken links across 177 files (baseline)
- `~/Library/Python/3.12/lib/python/site-packages/mkdocs/config/defaults.py` — confirms `exclude_docs = c.Optional(c.PathSpec())` in mkdocs 1.6.1
- `git diff --diff-filter=D --name-only v1.0 v5.0 -- app/ lib/` — one deleted .rb file: umb_scraper_v2.rb
- `git diff --diff-filter=R --name-status v1.0 v5.0 -- app/ lib/` — one rename: lib/tournament_monitor_support.rb
- `grep -rn "UmbScraperV2|tournament_monitor_support" docs/` — 4 active doc files confirmed
- `find docs -name "*.de.md" | wc -l` → 89; `*.en.md` → 63 (26-gap confirmed)
- Ruby nav parser on mkdocs.yml — one in-nav bilingual gap: managers/table-reservation.md missing .de.md
- `.planning/config.json` — nyquist_validation: false confirmed
- `.planning/research/STACK.md`, `FEATURES.md`, `ARCHITECTURE.md`, `PITFALLS.md` — prior research validated against live codebase

### Secondary (MEDIUM confidence)
- `.planning/phases/28-audit-triage/28-CONTEXT.md` — user decisions D-01 through D-05

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools verified installed, all versions confirmed
- Architecture: HIGH — all patterns derived from existing working scripts in codebase
- Stale identifier list: HIGH — git diff against verified tags, grep against live docs
- Bilingual gap count: HIGH — Ruby script enumerated nav entries against filesystem
- audit.json schema: MEDIUM — design is Claude's discretion; schema is plausible but user may want different fields

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable domain — mkdocs config, Ruby stdlib; unlikely to change)
