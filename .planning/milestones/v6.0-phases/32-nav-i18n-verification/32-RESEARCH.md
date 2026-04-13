# Phase 32: Nav, i18n & Verification - Research

**Researched:** 2026-04-13
**Domain:** MkDocs nav wiring, bilingual i18n gap closure, strict build verification
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Translate all 17 in-nav gaps — create full AI-assisted translations for every missing `.de.md` or `.en.md` pair. No stubs. Ensures no EN user silently falls back to DE for any nav-linked page.
- **D-02:** Gap list (from `bin/check-docs-translations.rb --nav-only`): 8 missing EN files + 9 missing DE files.
- **D-03:** New `Services:` subsection under `Developers:` in mkdocs.yml nav, placed after the existing `UMB Scraping:` block. Lists all 8 namespace pages + video-crossref.
- **D-04:** Include `nav_translations` entries for DE labels of all new nav items.
- **D-05:** Fix ALL 29 strict-mode warnings (actual current count: 32 unique / 62 total — both DE and EN build passes) regardless of origin. Zero warnings is the clean baseline.
- **D-06:** Full sweep as the last task — re-run ALL verification scripts: `bin/check-docs-links.rb`, `bin/check-docs-translations.rb --nav-only`, `bin/check-docs-coderef.rb`, and `mkdocs build --strict`. All must report zero issues.
- **D-07:** German primary, AI-assisted translation to English.
- **D-08:** One commit per bilingual doc pair.

### Claude's Discretion

- Order of operations (nav first, then translations, or interleaved)
- How to handle orphan pages that cause strict warnings (add to nav vs remove)
- nav_translations label phrasing for German
- Whether to reorganize existing nav entries while adding new ones

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOC-03 | Add new docs to mkdocs.yml nav, resolve in-nav bilingual gaps (de/en), pass `mkdocs build --strict` with zero warnings | All research findings directly enable implementation: nav insertion point identified, all 17 gaps mapped to source files, all 32 unique warnings classified by root cause and fix strategy |
</phase_requirements>

---

## Summary

Phase 32 is the closing verification gate for the v6.0 Documentation Quality milestone. All Phase 31 services pages exist as bilingual `.de.md`/`.en.md` pairs in `docs/developers/services/` but are not yet registered in `mkdocs.yml` nav — adding a `Services:` block after the `UMB Scraping:` block at line 175 is the single nav change needed for those 8 pages (plus video-crossref).

The 17 translation gaps all stem from monolingual plain `.md` files currently referenced in nav (8 files need renaming to `.de.md` + a new `.en.md` translation) plus one `.en.md`-only file that needs a `.de.md` counterpart. No file is genuinely missing — every source exists; the task is rename + translate.

`mkdocs build --strict` currently produces 62 warnings (32 unique, doubled because the i18n plugin runs both DE and EN builds). These fall into three root-cause buckets: 24 unique warnings come from `internal/`, `changelog/`, and `studies/` directories that are not in `exclude_docs` — adding them to `exclude_docs` eliminates all 24; 7 unique warnings come from broken links in visible/nav-linked docs (fixable by updating 5 specific files); and 1 unique warning is the nav reference to the missing `managers/table-reservation.md` (fixed by creating the `.de.md` counterpart and fixing the nav entry to use suffix-aware path).

**Primary recommendation:** Execute in this order — (1) expand `exclude_docs` to eliminate 24 internal/changelog/studies warnings, (2) add Services nav block + nav_translations, (3) fix 7 visible-doc broken links, (4) rename 8 monolingual files + create translations, (5) create managers/table-reservation.de.md, (6) run full verification sweep.

---

## Standard Stack

### Core (all already in project)

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| mkdocs-material | current | Site theme + build engine | Established project choice |
| mkdocs-static-i18n | current | `.de.md`/`.en.md` suffix docs_structure | Project's i18n plugin |
| bin/check-docs-translations.rb | — | Translation gap checker | Project script, Phase 28 deliverable |
| bin/check-docs-links.rb | — | Broken link checker | Project script, Phase 28 deliverable |
| bin/check-docs-coderef.rb | — | Stale reference checker | Project script, Phase 28 deliverable |
| lib/tasks/mkdocs.rake | — | `mkdocs:check` CI task | Phase 28 deliverable |

[VERIFIED: live file inspection]

**No new packages needed** — this phase is pure config/content work.

---

## Architecture Patterns

### i18n Plugin: docs_structure suffix

[VERIFIED: mkdocs.yml line 47]

The project uses `docs_structure: suffix` with `fallback_to_default: true` (DE is default). This means:
- Nav entries use plain paths: `developers/deployment-checklist.md`
- The plugin maps to `deployment-checklist.de.md` for DE users, `deployment-checklist.en.md` for EN users
- If only `.de.md` exists and fallback is true, EN users silently get DE content — which D-01 prohibits
- Plain `.md` files (no suffix) are NOT recognized by the plugin as a valid pair member; they are treated as a separate file, causing the translation checker to report both MISSING_DE and MISSING_EN for the same nav entry

### Nav Structure: Existing Developers Section

```yaml
# Lines 161-188 of mkdocs.yml (current)
- Developers:
    - developers/index.md
    - Getting Started: developers/getting-started.md
    ...
    - Testing:
        - Testing Quickstart: developers/testing/testing-quickstart.md
        - Fixture Collection Guide: developers/testing/fixture-collection-guide.md
    - UMB Scraping:                                          # <-- line 173
        - UMB Scraping Implementation: developers/umb-scraping-implementation.md
        - UMB Scraping Methods: developers/umb-scraping-methods.md
    - Frontend STI Migration: developers/frontend-sti-migration.md  # line 176
    ...
```

**Insertion point for Services block:** After the `UMB Scraping:` closing line (after line 175), before `Frontend STI Migration` at line 176. [VERIFIED: mkdocs.yml inspection]

### nav_translations Format

[VERIFIED: mkdocs.yml lines 55-122]

All nav label DE equivalents live inside the `de:` locale block:
```yaml
- locale: de
  nav_translations:
    UMB Scraping: UMB Scraping
    UMB Scraping Implementation: UMB Scraping Implementierung
    Services: Services               # <-- add new entries here
    Table Monitor: Table Monitor     # (or German equivalent)
```

The nav_translations block is at lines 55-122. New entries must be added to this block.

### Bilingual File Naming

[VERIFIED: docs/developers/services/ — 16 files present]

All Phase 31 services pages already follow the correct pattern:
```
docs/developers/services/table-monitor.de.md
docs/developers/services/table-monitor.en.md
```

For the 8 monolingual files being converted, the pattern is:
1. `git mv` plain `.md` → `.de.md` (for DE-language content) or `.en.md` (for EN-language content)
2. Create translated counterpart (AI-assisted)
3. Update mkdocs.yml nav entry stays the same (plain `.md` path — plugin handles suffix routing)

---

## Warning Classification: All 32 Unique Warnings

[VERIFIED: `mkdocs build --strict 2>&1` output, 2026-04-13]

Total: 62 warnings (32 unique × 2 because DE and EN builds both run).

### Bucket A: exclude_docs expansion — 24 unique warnings

These come from files in `internal/`, `changelog/`, and `studies/` directories which are NOT currently in `exclude_docs` (only `archive/**` and `obsolete/**` are excluded). Adding these three directories to `exclude_docs` eliminates all 24 warnings with a single config change.

**Files generating warnings:**
- `changelog/changelog.de.md` — 2 broken links (CHANGELOG.md, INSTALLATION/QUICKSTART.md)
- `changelog/changelog.en.md` — 2 broken links (same targets)
- `internal/INDEX.md` — 1 broken link
- `internal/archive/2026-01/EMAIL_CONFIGURATION_FIX.md` — 3 broken links
- `internal/archive/chat-status-docs-2025/README.de.md` — 7 broken links
- `internal/archive/chat-status-docs-2025/SCENARIO_SYSTEM_IMPLEMENTATION.md` — 2 broken links
- `internal/archive/chat-status-docs-2025/SCENARIO_SYSTEM_SUMMARY.md` — 1 broken link
- `internal/bug-fixes/ADMIN_SETTINGS_CONFIGURATION.md` — 3 broken links
- `internal/implementation-notes/TOURNAMENT_WIZARD_TECHNICAL.md` — 2 broken links
- `studies/DOCKER_RASPI_FEASIBILITY_STUDY.de.md` — 2 broken links (outside docs root)

**Fix:** Add to `exclude_docs` in mkdocs.yml:
```yaml
exclude_docs: |
  archive/**
  obsolete/**
  internal/**
  studies/**
  changelog/**
```

**Validation:** `bin/check-docs-links.rb --exclude-archives` already reports 0 broken links in active docs. [VERIFIED: script run, 2026-04-13]

### Bucket B: Visible doc broken links — 7 unique warnings

These require targeted edits to 5 files:

| File | Broken Link | Fix |
|------|-------------|-----|
| `administrators/index.de.md` | `../managers/table-reservation.md` | Fixed when table-reservation.de.md is created (x2 occurrences) |
| `managers/index.de.md` | `table-reservation.md` | Fixed when table-reservation.de.md is created (x2 occurrences) |
| `developers/developer-guide.en.md` line 455 | `../developers/developer-guide.de.md#operations` | Change to `developer-guide.md#operations` (cross-language link; suffix stripping makes .de.md invalid) |
| `developers/rake-tasks-debugging.de.md` lines 49/83/312 | `../../lib/tasks/obsolete/README.md` | Points outside docs root — update text/link or remove link |
| `developers/rake-tasks-debugging.en.md` lines 49/83/312 | `../../lib/tasks/obsolete/README.md` | Same as above |
| `reference/api.de.md` line 673 | `API.md` | `reference/API.md` does not exist; fix to point to correct target or remove |
| `reference/api.en.md` line 673 | `API.md` | Same as above |

### Bucket C: Nav reference to missing file — 1 unique warning

```
WARNING: A reference to 'managers/table-reservation.md' is included in the 'nav'
```

`managers/table-reservation.en.md` exists. The `.de.md` is missing. The nav references `managers/table-reservation.md` (plain suffix) which the i18n plugin resolves — but since DE is default and only EN exists, the nav resolution fails. Fix: create `managers/table-reservation.de.md`.

**Note:** After creating the `.de.md`, the nav entry `managers/table-reservation.md` remains correct.

---

## Translation Gap Inventory: All 17 Gaps

[VERIFIED: `bin/check-docs-translations.rb --nav-only` output, 2026-04-13]

### Group 1: Monolingual plain .md files — rename + translate (8 files)

All 8 files exist as `filename.md` (no suffix). Each counts as BOTH MISSING_DE and MISSING_EN because the translation checker only recognizes `.de.md`/`.en.md` pairs.

**Correct action: `git mv filename.md filename.{primary_lang}.md` + create translated counterpart**

| Nav Label | Source File | Language | Action |
|-----------|-------------|----------|--------|
| Deployment Checklist Production | `developers/deployment-checklist.md` | DE (content in German) | rename -> `.de.md`, create `.en.md` |
| Frontend STI Migration | `developers/frontend-sti-migration.md` | DE | rename -> `.de.md`, create `.en.md` |
| Pool Scoreboard Changelog | `developers/pool-scoreboard-changelog.md` | DE | rename -> `.de.md`, create `.en.md` |
| RubyMine Setup | `developers/rubymine-setup.md` | EN (content in English) | rename -> `.en.md`, create `.de.md` |
| Scenario Workflow | `developers/scenario-workflow.md` | DE | rename -> `.de.md`, create `.en.md` |
| UMB Deployment Checklist | `developers/umb-deployment-checklist.md` | DE (mixed, primarily DE) | rename -> `.de.md`, create `.en.md` |
| Fixture Collection Guide | `developers/testing/fixture-collection-guide.md` | DE | rename -> `.de.md`, create `.en.md` |
| Testing Quickstart | `developers/testing/testing-quickstart.md` | DE | rename -> `.de.md`, create `.en.md` |

**Nav entries stay unchanged** — the nav uses plain `.md` paths which the i18n plugin resolves to the appropriate suffix.

### Group 2: .en.md-only file — create .de.md (1 file)

| Nav Label | File | Missing |
|-----------|------|---------|
| Table Reservation | `managers/table-reservation.en.md` | `managers/table-reservation.de.md` |

**Nav entry already correct:** `- Table Reservation: managers/table-reservation.md`

---

## Phase 31 Services Nav Block

[VERIFIED: `docs/developers/services/` directory listing, 2026-04-13]

All 8 service pairs + video-crossref exist as bilingual `.de.md`/`.en.md`. The complete nav block to insert (after `UMB Scraping:` block, before `Frontend STI Migration:` line):

```yaml
      - Services:
          - Table Monitor: developers/services/table-monitor.md
          - Region CC: developers/services/region-cc.md
          - Tournament: developers/services/tournament.md
          - Tournament Monitor: developers/services/tournament-monitor.md
          - League: developers/services/league.md
          - Party Monitor: developers/services/party-monitor.md
          - UMB Services: developers/services/umb.md
          - Video Cross-Reference: developers/services/video-crossref.md
```

**nav_translations entries to add** (inside the `de:` locale `nav_translations:` block):
```yaml
            Services: Services
            Table Monitor: Table Monitor
            Region CC: Region CC
            Tournament: Turnier
            Tournament Monitor: Turnier-Monitor
            League: Liga
            Party Monitor: Party-Monitor
            UMB Services: UMB-Services
            Video Cross-Reference: Video-Querverweise
```

[ASSUMED] nav_translations German label phrasings above are reasonable defaults — the planner has discretion on exact German labels per D-04.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Translation gap detection | Custom scan | `bin/check-docs-translations.rb --nav-only` |
| Link validation | Manual check | `bin/check-docs-links.rb` |
| Strict build validation | Manual invocation | `bin/rails mkdocs:check` (uses `--strict` + temp dir) |
| i18n routing | Custom redirect | mkdocs-static-i18n plugin — nav `.md` -> `.de.md`/`.en.md` automatically |

---

## Common Pitfalls

### Pitfall 1: Renaming plain .md breaks git history for important docs
**What goes wrong:** `git mv` loses blame/log if reviewers look at the new `.de.md` file
**Why it happens:** Git mv is correct but reviewers may not know to use `--follow`
**How to avoid:** Use `git mv` (not delete+create) — git tracks renames with `--follow`
**Warning signs:** N/A — use `git mv` as standard practice

### Pitfall 2: Nav entry still references plain .md after rename — file disappears
**What goes wrong:** After renaming `scenario-workflow.md` -> `scenario-workflow.de.md`, if the nav still says `developers/scenario-workflow.md` and only `.de.md` exists, the nav works fine (plugin resolves it). But if someone manually checks for `scenario-workflow.md` in the filesystem it won't be there.
**How to avoid:** Do NOT change nav entries for the renamed files — the plain `.md` reference in nav is exactly correct for the i18n plugin.

### Pitfall 3: Cross-language links use language-suffixed paths
**What goes wrong:** A `.en.md` file linking to `another-file.de.md` fails because the i18n plugin processes suffixes — the correct cross-language link omits the suffix
**Why it happens:** This is exactly the `developer-guide.en.md` -> `developer-guide.de.md#operations` bug (line 455)
**How to avoid:** Internal links in any language file should use plain `.md` paths (no suffix)
**Example fix:** `[Runbook](../developers/developer-guide.de.md#operations)` -> `[Runbook](../developers/developer-guide.md#operations)`

### Pitfall 4: exclude_docs only excludes at build time, not from link checking
**What goes wrong:** Adding `internal/**` to `exclude_docs` fixes mkdocs strict warnings but `bin/check-docs-links.rb` (without `--exclude-archives`) will still report those as broken
**Why it happens:** The two tools have separate exclusion configs
**How to avoid:** Phase success criterion for `bin/check-docs-links.rb` should use `--exclude-archives` flag, or accept that non-nav links in internal/ remain as-is. Alternatively update the checker. The Phase 29 baseline for the link checker already shows `internal: 75` broken links as a known baseline.

### Pitfall 5: Double-counting warnings (62 vs 32 unique)
**What goes wrong:** Thinking there are 62 problems to fix when there are only 32 unique causes
**Why it happens:** mkdocs-static-i18n runs two build passes (DE + EN), each generating the same warning
**How to avoid:** Fix the 32 unique root causes; the 62 total drops to 0

---

## Fix Execution Map

Summary of all work items, ordered for efficient execution:

| # | Work Item | Type | Files Changed |
|---|-----------|------|---------------|
| 1 | Expand `exclude_docs` in mkdocs.yml | Config edit | `mkdocs.yml` |
| 2 | Add Services nav block to mkdocs.yml | Config edit | `mkdocs.yml` |
| 3 | Add nav_translations for Services entries | Config edit | `mkdocs.yml` |
| 4 | Fix `developer-guide.en.md` cross-language link (line 455) | Link fix | `docs/developers/developer-guide.en.md` |
| 5 | Fix `rake-tasks-debugging.de.md` lib/tasks links (lines 49/83/312) | Link fix | `docs/developers/rake-tasks-debugging.de.md` |
| 6 | Fix `rake-tasks-debugging.en.md` lib/tasks links | Link fix | `docs/developers/rake-tasks-debugging.en.md` |
| 7 | Fix `reference/api.de.md` + `api.en.md` API.md link (line 673) | Link fix | `docs/reference/api.de.md`, `docs/reference/api.en.md` |
| 8 | Create `managers/table-reservation.de.md` | New file | `docs/managers/table-reservation.de.md` |
| 9 | Rename + translate 8 monolingual .md files (1 commit each pair) | Rename + new file | 16 file operations |

Items 1-3 = 1 wave. Items 4-7 = 1 wave. Item 8 = 1 commit. Item 9 = 8 commits (one per pair per D-08).

---

## Environment Availability

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| mkdocs | All build/validate tasks | Yes | Confirmed via `mkdocs build --strict` run |
| mkdocs-material | Theme rendering | Yes | Build succeeded |
| mkdocs-static-i18n | i18n routing | Yes | Build succeeded |
| Ruby | Verification scripts | Yes | Project standard |
| bin/check-docs-translations.rb | Gap validation | Yes | Confirmed working |
| bin/check-docs-links.rb | Link validation | Yes | Confirmed working |
| bin/check-docs-coderef.rb | Stale ref validation | Yes | Confirmed working |

No missing dependencies. [VERIFIED: all tools run successfully, 2026-04-13]

---

## Validation Architecture

Nyquist validation is disabled (`workflow.nyquist_validation: false` in config.json). No test framework section required.

Final gate verification commands (per D-06):
```bash
mkdocs build --strict                                    # must exit 0 (zero warnings)
ruby bin/check-docs-translations.rb --nav-only          # must report 0 gaps
ruby bin/check-docs-links.rb --exclude-archives         # must report 0 broken links
ruby bin/check-docs-coderef.rb                          # must report 0 stale refs
```

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `internal/**`, `studies/**`, `changelog/**` are appropriate to add to `exclude_docs` — they are non-nav internal notes not meant for end-users | Warning Classification Bucket A | If these dirs contain nav-linked pages, excluding them would break nav. Verified: none of these dirs appear in nav entries — safe to exclude. [LOW residual risk] |
| A2 | nav_translations German label phrasings ("Turnier-Monitor", "Party-Monitor", "Video-Querverweise") | Services nav block section | If project has established German terminology from Phase 31 content, those terms should be used instead. Check Phase 31 .de.md titles. |

---

## Open Questions (RESOLVED)

1. **lib/tasks/obsolete/README.md broken link fix strategy**
   - What we know: `rake-tasks-debugging.de.md` and `.en.md` both link to `../../lib/tasks/obsolete/README.md` (outside docs root, 3 occurrences each). The file exists at `lib/tasks/obsolete/README.md` in the project but is outside the docs root so mkdocs cannot resolve it.
   - What's unclear: Should the link be removed, replaced with prose, or replaced with a link to a docs page about the obsolete tasks?
   - RESOLVED: Replace the three links with a plain text note (no hyperlink) since the file is not renderable via mkdocs. This is the minimal change. (Claude's discretion)

2. **reference/api.md broken link fix strategy**
   - What we know: `reference/api.de.md` and `.en.md` both link to `API.md` (reference/API.md does not exist — only `api.de.md`/`api.en.md`)
   - What's unclear: What was `API.md` supposed to be? A legacy file?
   - RESOLVED: Remove the link or replace with a self-referential note — the api pages ARE the API reference. (Claude's discretion)

---

## Sources

### Primary (HIGH confidence)
- `mkdocs.yml` — Full nav structure, plugin config, nav_translations (lines 1-246) — inspected live
- `mkdocs build --strict` — All 62 warnings captured and classified live, 2026-04-13
- `bin/check-docs-translations.rb --nav-only` — All 17 gaps confirmed live
- `bin/check-docs-links.rb --exclude-archives` — 0 broken links in active docs confirmed
- `docs/developers/services/` directory listing — all 16 bilingual files confirmed present
- `docs/managers/` directory listing — table-reservation.en.md exists, .de.md missing confirmed

### Secondary (MEDIUM confidence)
- mkdocs-static-i18n `docs_structure: suffix` behavior — [CITED: plugin config in mkdocs.yml + observed warning patterns from live build]

---

## Metadata

**Confidence breakdown:**
- Warning classification: HIGH — all 62 warnings captured and classified from live build
- Translation gap inventory: HIGH — all 17 gaps confirmed from live checker + file inspection
- Nav insertion point: HIGH — exact line numbers verified
- German nav_translations labels: MEDIUM (A2 above) — reasonable defaults, may need adjustment per Phase 31 doc titles
- Fix strategies for lib/tasks and API.md links: MEDIUM — root cause clear, exact resolution is Claude's discretion

**Research date:** 2026-04-13
**Valid until:** Until any new docs are added to docs/ or Phase 31 content changes
