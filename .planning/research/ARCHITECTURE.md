# Architecture Research

**Domain:** Documentation audit and update for mkdocs-based Rails app docs
**Researched:** 2026-04-12
**Confidence:** HIGH (all findings from direct inspection of docs/, mkdocs.yml, PROJECT.md)

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                     mkdocs-material site                             │
│                                                                      │
│  ┌──────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐  │
│  │decision-makers│  │  players   │  │  managers  │  │administrators│ │
│  └──────────────┘  └────────────┘  └────────────┘  └────────────┘  │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                      developers/                               │ │
│  │  getting-started · developer-guide · database-design           │ │
│  │  umb-scraping-* · streaming-architecture · testing/            │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌─────────────────────────┐  ┌──────────────────────────────────┐  │
│  │       reference/        │  │       about / changelog          │  │
│  └─────────────────────────┘  └──────────────────────────────────┘  │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│              docs/ file storage (342 .md files total)                │
│                                                                      │
│  ┌────────────────────┐  ┌────────────────────┐                     │
│  │  Active: ~255 files │  │  Archive/Obsolete  │                    │
│  │  (in nav + extras) │  │  87 files (frozen) │                    │
│  └────────────────────┘  └────────────────────┘                     │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│                   i18n plugin (mkdocs-material)                      │
│     locale: de (default) · locale: en · suffix pattern              │
│     file.de.md / file.en.md · fallback_to_default: true             │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Current State |
|-----------|----------------|---------------|
| `mkdocs.yml` nav | Source of truth for what is published | 42 nav entries; some nav items lack `.de.md`/`.en.md` pairs |
| `docs/` active files | ~255 files; audience sections + reference + internal | Mixed: some current, many stale re: v1.0–v5.0 changes |
| `docs/archive/` | Frozen historical docs (2026-02 epoch) | 87 files — do not touch |
| `docs/obsolete/` | Explicitly superseded content | 2 files — do not touch |
| `docs/internal/` | Developer notes, bug-fix records, implementation summaries | Not in mkdocs nav; maintenance reference only |
| Language pair (`.de.md` / `.en.md`) | Both files required for each published nav entry | 87 de-files, 63 en-files — 27 de-only gaps, 3 en-only gaps |
| `BROKEN_LINKS_REPORT.txt` | Pre-existing link audit | 74 broken links across 6 directories |

## Recommended Project Structure (Audit Target)

The audit operates on the existing structure — no restructuring is needed. The task is to assess correctness of content within this layout:

```
docs/
├── decision-makers/          # Audience: business stakeholders
│   ├── index.{de,en}.md
│   ├── executive-summary.{de,en}.md
│   ├── features-overview.{de,en}.md
│   └── deployment-options.{de,en}.md
├── players/                  # Audience: end-user players
│   ├── index.{de,en}.md
│   ├── scoreboard-guide.{de,en}.md      ← 34 broken image links (screenshots missing)
│   ├── tournament-participation.{de,en}.md
│   └── ai-search.{de,en}.md
├── managers/                 # Audience: tournament managers
│   └── [9 nav entries, all bilingual]
├── administrators/           # Audience: sysadmins
│   └── [10 nav entries; streaming docs partially de-only]
├── developers/               # Audience: contributors/maintainers  ← PRIMARY AUDIT TARGET
│   ├── developer-guide.{de,en}.md      ← references deleted enhanced_mode_system.md (x2)
│   ├── umb-scraping-implementation.md  ← entire file is stale (pre-v5.0 plan)
│   ├── umb-scraping-methods.md         ← references UmbScraperV2 (deleted in v5.0)
│   ├── testing/
│   │   ├── testing-quickstart.md       ← links to test/ files that may have moved
│   │   └── fixture-collection-guide.md ← 5 broken links to test/ paths
│   └── [scenario-workflow.md]          ← 3 broken links (CONTRIBUTING.md, README.md, etc.)
├── reference/                # Glossary, API, terms, config
│   ├── glossary.{de,en}.md             ← broken link to ../search.md
│   └── mkdocs_dokumentation.{de,en}.md ← example links are placeholder (intentional)
├── internal/                 # NOT in nav — internal notes only
├── archive/                  # Frozen — do not modify
└── obsolete/                 # Superseded — do not modify
```

### Structure Rationale

- **Audience-first hierarchy:** The five top-level sections (decision-makers, players, managers, administrators, developers) match the mkdocs nav tabs exactly. Audit work scopes to the section most affected by v1.0–v5.0 changes: `developers/`.
- **Language pairs at file level:** The i18n plugin uses the `suffix` docs_structure: `file.de.md` for German (default), `file.en.md` for English. Both must exist for a nav entry to render correctly in both languages. `fallback_to_default: true` means a missing `.en.md` silently serves the German version to English users — correct behavior, but invisible staleness.
- **Archive/obsolete are frozen:** 87 archive files and 2 obsolete files are explicitly out of scope. They document historical decisions and must not be modified or moved.

## Architectural Patterns

### Pattern 1: Audit-First, Then Fix

**What:** Complete the full audit pass across all nav-linked files before writing a single content update. Produce a structured staleness inventory (file, issue type, codebase reference) before any edits.

**When to use:** Always. Editing while auditing creates a moving target and makes it impossible to estimate remaining work. The broken links report already exists — the first phase extends that into content correctness.

**Trade-offs:** Slightly slower start (no visible doc improvements on day one). Massive benefit: the fix phase has explicit, enumerable work items and no surprises.

**Why not interleave:** 255 active files across 6 audience sections. Interleaving means context-switching between audit mode (what is wrong?) and fix mode (how do I rewrite this?). Separate passes allow better pattern recognition across the whole corpus.

### Pattern 2: Issue Triage into Three Buckets

**What:** During the audit pass, classify every finding into exactly one of:

- **DELETE** — references deleted code or features that no longer exist (UmbScraperV2, pre-refactoring service names, old model line counts). Remove the section or the whole file.
- **UPDATE** — content exists but is inaccurate (wrong class names, outdated flow diagrams, stale method signatures). Rewrite in-place.
- **CREATE** — a feature or service from v1.0–v5.0 has no documentation at all. Write new content.

**When to use:** For every file touched. Triage happens during audit, execution happens during fix.

**Example:**

| File | Bucket | Reason |
|------|--------|--------|
| `developers/umb-scraping-implementation.md` | DELETE or REPLACE | Entire file describes a pre-v5.0 plan; current reality is 10 `Umb::` services + thin facade |
| `developers/umb-scraping-methods.md` | UPDATE | References `UmbScraperV2` (deleted v5.0); update method inventory to match `Umb::*` namespace |
| `international/umb_scraper.md` | UPDATE | Pre-v5.0 description of `UmbScraper`; needs to describe current facade + `Umb::` services |
| `developers/developer-guide.en.md` | UPDATE | Two broken links to `enhanced_mode_system.md` (moved to obsolete) |
| *(no file)* | CREATE | `Umb::` service architecture: 10 services, PdfParser subclasses, HttpClient |
| *(no file)* | CREATE | Video cross-referencing: `Video::TournamentMatcher`, `Video::MetadataExtractor`, confidence scoring |
| *(no file)* | CREATE | 37 extracted services inventory: what was extracted from which model, in which milestone |

### Pattern 3: Language Pair Discipline

**What:** For every content change, update both `.de.md` and `.en.md` in the same commit. Never update one without the other. For new files, create both simultaneously.

**When to use:** Every content fix. No exceptions.

**Exception — de-only gaps (27 files):** These exist intentionally (DE-only operational docs for German-speaking admins). Do not create `.en.md` stubs for these. Only create English counterparts for files that are referenced in the mkdocs nav or that address international developer audiences.

**How to check parity after writing:** Content sections should mirror structurally (same headings, same code blocks). Prose can be translation-natural rather than word-for-word, but topic coverage must match.

**Trade-offs:** Doubles the writing work for bilingual nav entries. Non-negotiable given the DE-first user base and the `fallback_to_default: true` setting that silently serves German to English users when `.en.md` is absent.

### Pattern 4: Systematic Codebase-to-Docs Mapping

**What:** Use the 37-service inventory from PROJECT.md as the authoritative "what was built" list. Cross-reference each service against the docs corpus to find documentation gaps.

**When to use:** During the CREATE bucket work in the audit phase. A service with no docs mention is a documentation gap. A docs mention with no corresponding service file is a staleness hit.

**Mapping sources:**

| Codebase Truth | Where to check | Method |
|----------------|----------------|--------|
| 37 extracted services (PROJECT.md) | `docs/developers/` | `grep -r "ServiceName"` across active docs |
| Deleted: UmbScraperV2, lib/tournament_monitor_support.rb | All active docs | Grep for class names — every hit is a DELETE or UPDATE item |
| New: `Umb::*` namespace (10 services) | All active docs | No matches → CREATE needed |
| New: `Video::TournamentMatcher`, `Video::MetadataExtractor` | All active docs | No matches → CREATE needed |
| Existing concerns (LocalProtector, RegionTaggable, etc.) | `docs/developers/developer-guide.*` | Verify descriptions still accurate |

## Data Flow

### Audit Execution Flow

```
Phase 1: Pre-Audit Inventory
  → Read mkdocs.yml nav (42 entries × 2 languages = up to 84 files)
  → Identify all nav-linked files
  → Cross-reference against file system: missing? present?
  → Output: nav-to-file coverage matrix

Phase 2: Content Audit (per file)
  → Read each active nav-linked file
  → Check: references to deleted code? (UmbScraperV2, old method names, pre-v5 service names)
  → Check: missing coverage? (37 services — how many appear in docs?)
  → Check: broken internal links? (74 already known from BROKEN_LINKS_REPORT.txt)
  → Classify: DELETE / UPDATE / CREATE
  → Output: staleness inventory with line-level citations

Phase 3: Fix Execution (per work item)
  → DELETE items: remove stale sections, archive whole files if fully superseded
  → UPDATE items: rewrite inaccurate sections with codebase-verified content
  → CREATE items: write new docs for undocumented v1.0–v5.0 features
  → For each change: update both .de.md and .en.md
  → Run mkdocs build to verify no new broken links introduced

Phase 4: nav Verification
  → Confirm mkdocs.yml nav entries match existing files
  → Fix any nav references pointing to nonexistent paths
  → Verify i18n plugin resolves all nav entries in both locales
```

### Content Staleness Flow (Known Issues at Audit Start)

```
Deleted in v5.0: UmbScraperV2 (585 lines)
  → Referenced in: docs/developers/umb-scraping-methods.md:73
  → Action: UPDATE — replace reference with Umb::PdfParser::* description

Deleted in v2.1: lib/tournament_monitor_support.rb (1078 lines)
  → Search needed: any doc mentioning "tournament_monitor_support"
  → Action: DELETE references, UPDATE to point at extracted services

Deleted in v2.1: TournamentMonitor reduced 499→181 lines (4 services extracted)
  → No known doc references yet — audit will confirm

Broken link cluster: players/scoreboard-guide.{de,en}.md
  → 34 broken image links (screenshots/*.png missing)
  → Action: Provide screenshots or remove img references

Broken link cluster: developers/ (19 broken links)
  → enhanced_mode_system.md (deleted → moved to obsolete): 2 occurrences in developer-guide.en.md
  → scenario-system-workflow.md (missing): rake-tasks-debugging.{de,en}.md
  → fixture-collection-guide.md → test/ paths (5 occurrences)
  → Action: fix links or remove dead references

Broken link: reference/glossary.{de,en}.md → ../search.md
  → Action: update link to reference/search.md (correct path exists)
```

## New vs Documented Components

| Component | v-milestone | Documented? | Action |
|-----------|-------------|-------------|--------|
| ScoreEngine, GameSetup, OptionsPresenter, ResultRecorder | v1.0 | No | CREATE |
| ClubCloudClient + 9 region_cc syncers | v1.0 | No | CREATE |
| RankingCalculator, TableReservationService, PublicCcScraper | v2.1 | No | CREATE |
| PlayerGroupDistributor, RankingResolver, ResultProcessor, TablePopulator | v2.1 | No | CREATE |
| League::StandingsCalculator, GamePlanReconstructor, ClubCloudScraper, BbvScraper | v4.0 | No | CREATE |
| PartyMonitor::TablePopulator, ResultProcessor | v4.0 | No | CREATE |
| Umb::HttpClient, DisciplineDetector, DateHelpers, PlayerResolver | v5.0 | No | CREATE |
| Umb::FutureScraper, ArchiveScraper, DetailsScraper | v5.0 | No | CREATE |
| Umb::PdfParser::{PlayerListParser, GroupResultParser, RankingParser} | v5.0 | No | CREATE |
| Video::TournamentMatcher, Video::MetadataExtractor | v5.0 | No | CREATE |
| SoopliveBilliardsClient | v5.0 | No | CREATE |
| UmbScraperV2 | DELETED v5.0 | Yes (stale ref) | DELETE ref |
| lib/tournament_monitor_support.rb | DELETED v2.1 | Unknown | AUDIT first |
| UmbScraper (thin facade, 175 lines) | MODIFIED v5.0 | Partially | UPDATE |

## Anti-Patterns

### Anti-Pattern 1: Edit While Auditing

**What people do:** Spot a stale sentence, fix it immediately, continue the audit.

**Why it's wrong:** Creates half-audited state. Missing the full picture — one file may reference a concept that five other files also get wrong. Fixing one without fixing the others creates inconsistency that requires a second pass.

**Do this instead:** During audit, add a comment or inventory entry. Fix only after the full audit inventory is complete.

### Anti-Pattern 2: Updating Only One Language

**What people do:** Fix the German version, forget to update the English version.

**Why it's wrong:** `fallback_to_default: true` hides the gap — English users silently get the German version. When someone later audits only the EN files, they see the stale content and don't know it's already correct in DE.

**Do this instead:** Every file pair is a single atomic unit of work. `{file}.de.md` and `{file}.en.md` are updated in the same commit.

### Anti-Pattern 3: Rewriting Archive or Obsolete Files

**What people do:** Find a `docs/archive/2026-02/` file that references the old UmbScraper and "fix" it.

**Why it's wrong:** Archive files are historical records. They document what was true at a point in time. Modifying them destroys the record.

**Do this instead:** If a file's content is entirely obsolete and not providing historical value, move it from `docs/` to `docs/archive/` with a datestamp. Never edit `docs/archive/` or `docs/obsolete/` content.

### Anti-Pattern 4: Creating New Docs Without Nav Entries

**What people do:** Write `docs/developers/extracted-services.md` without adding it to `mkdocs.yml`.

**Why it's wrong:** Files not in the nav are invisible in the published site. The mkdocs i18n plugin won't translate them. They accumulate as orphan files and become the next audit's cleanup work.

**Do this instead:** For every new file created, add it to `mkdocs.yml` nav simultaneously. Add both `.de.md` and `.en.md` nav entries.

### Anti-Pattern 5: Documenting Implementation Details That Change

**What people do:** Document that "UmbScraper has 175 lines" or "TableMonitor was reduced from 3903 lines."

**Why it's wrong:** Line counts are already stale. They will change again with the next refactoring milestone. Documenting them creates guaranteed future staleness.

**Do this instead:** Document architecture (what classes exist, what they do, how they relate) not implementation metrics. Line counts belong in retrospectives and planning documents, not in user-facing developer documentation.

### Anti-Pattern 6: Treating "No English Version" as a Bug for Internal Dev Docs

**What people do:** See 27 de-only files and create placeholder English stubs for all of them.

**Why it's wrong:** Many of those 27 files are German-specific operational docs (streaming-obs-setup.de.md, raspi-network-stability.de.md) aimed at German-speaking administrators. They do not need English counterparts. Creating empty stubs adds noise and may cause the i18n plugin to serve empty pages.

**Do this instead:** Evaluate intent. Docs in `developers/` with technical content (no cultural specificity) should have English counterparts. Ops docs targeting German sysadmins do not.

## Integration Points

### External: codebase ↔ docs

| Codebase Element | Relevant Doc Files | Sync Direction |
|------------------|-------------------|----------------|
| `app/services/umb/` (10 files) | `developers/umb-scraping-implementation.md`, `developers/umb-scraping-methods.md`, `international/umb_scraper.md` | Code is truth → docs must update |
| `app/services/video/` (2 files) | No current docs | Code is truth → CREATE needed |
| `app/services/league/` (4 files) | `managers/league-management.{de,en}.md` (partial) | Code is truth → UPDATE needed |
| `app/services/table_monitor/` (4 files) | No dedicated docs; mentioned in developer-guide | Code is truth → UPDATE needed |
| `app/services/region_cc/` (10 files) | No docs | Code is truth → CREATE or UPDATE needed |
| Deleted: `UmbScraperV2` | `developers/umb-scraping-methods.md:73` | Code is truth → DELETE reference |
| Concerns: LocalProtector, APIProtector | `developers/developer-guide.{de,en}.md` | Likely accurate — VERIFY |
| Test suite: 1130 runs, Minitest | `developers/testing/testing-quickstart.md`, `fixture-collection-guide.md` | Partially stale links → FIX |

### Internal: mkdocs.yml ↔ docs/

| Nav Entry | File Pair Status | Action |
|-----------|-----------------|--------|
| `managers/table-reservation` | Only `.en.md` exists | CREATE `.de.md` or add nav guard |
| `developers/tournament-architecture-overview` | Only `.en.md` exists | CREATE `.de.md` or add nav guard |
| `reference/mkdocs_dokumentation` | Both `.de.md` and `.en.md` exist | Nav references `.de.md` variant; also `mkdocs_dokumentation.en.md` exists but is not referenced separately |
| `reference/api` | Referenced twice in nav (Developer section + Reference section) | Deduplication — verify intentional |

### Internal: broken links (74 known)

| Directory | Count | Primary Cause |
|-----------|-------|---------------|
| `players/` | 34 | Missing screenshot images (scoreboard-guide) |
| `developers/` | 19 | Deleted files (enhanced_mode_system, scenario-system-workflow), wrong test/ paths |
| `reference/` | 16 | Placeholder example links in mkdocs_dokumentation (may be intentional), broken ../search.md |
| `managers/` | 2 | Unknown — verify during audit |
| `administrators/` | 1 | Missing systemd-streaming-services.md |
| `international/` | 2 | Unknown — verify during audit |

## Suggested Build Order

Phase ordering rationale: (1) structural clarity before content changes, (2) high-impact/low-effort fixes first, (3) new content last (hardest, most time-consuming).

### Phase A: Structural Triage (no content edits)

1. Build the full nav-to-file coverage matrix from `mkdocs.yml` × file system
2. Extend `BROKEN_LINKS_REPORT.txt` findings with content-level staleness inventory
3. Classify all findings: DELETE / UPDATE / CREATE
4. Prioritize by: (a) broken published nav entries, (b) stale UmbScraperV2/deleted-code references, (c) missing v5.0 services, (d) bilingual gaps

### Phase B: Break-Fix (DELETE and link repairs)

Fix things that are actively wrong — broken links, references to deleted classes, dead nav entries. These have no content risk (removing is safer than rewriting).

1. Fix 74 broken links from existing report
   - Screenshot placeholders in scoreboard-guide: add images or replace img refs with text descriptions
   - `enhanced_mode_system.md` refs in developer-guide.en.md: remove or redirect to obsolete notice
   - `scenario-system-workflow.md` refs: update to correct file path
   - test/ path refs in fixture-collection-guide.md: verify current paths
   - `../search.md` refs in glossary: update to `reference/search.md`
2. Remove/update references to deleted code
   - `umb-scraping-methods.md:73` — UmbScraperV2 reference
   - Any reference to `lib/tournament_monitor_support.rb` (grep will surface these)
3. Fix duplicate `reference/api` nav entry

### Phase C: UPDATE Existing Docs

Rewrite inaccurate sections. These have content risk — verify against codebase before writing.

1. `developers/umb-scraping-implementation.md` — Entirely a pre-v5.0 plan. Options: (a) archive the old plan, create new doc describing actual Umb:: architecture; (b) rewrite in place. Recommend (a) — preserves history, creates clean current doc.
2. `developers/umb-scraping-methods.md` — Update method inventory from flat UmbScraper methods to `Umb::*` service breakdown
3. `international/umb_scraper.md` — Update to describe facade + 10 Umb:: services
4. `developers/developer-guide.{de,en}.md` — Update services section; add Umb::, Video::, extracted service namespaces
5. Verify concern descriptions (LocalProtector, APIProtector, RegionTaggable) still accurate

### Phase D: CREATE New Docs

New content for undocumented v1.0–v5.0 work. Highest effort; do last when structural/accuracy issues are resolved.

Priority order (most cross-referenced first):
1. Extracted services overview (all 37 services, grouped by milestone and namespace) — one reference doc, both languages
2. `Umb::` architecture doc (10 services, PdfParser breakdown, HttpClient, facade pattern) — both languages
3. `Video::` cross-referencing doc (TournamentMatcher + MetadataExtractor + confidence scoring) — both languages
4. Test suite architecture doc (1130 tests, Minitest, VCR, fixture-first approach, ApiProtectorTestOverride) — both languages
5. Broadcast isolation notes (ActionCable architecture, suppress_broadcast, deferred FIX-01/FIX-02) — developer audience

### Phase E: nav and i18n Cleanup

1. Add new Phase D docs to `mkdocs.yml` nav
2. Resolve de-only gap decisions (create EN counterparts for developer-facing files, leave admin-ops files as de-only)
3. Final `mkdocs build` — verify zero broken links in output
4. Verify i18n plugin renders both languages for all nav entries

## Sources

All findings from direct codebase inspection — no external sources required.

- `mkdocs.yml` — nav structure, 42 nav entries, i18n plugin configuration (suffix pattern, fallback_to_default)
- `docs/BROKEN_LINKS_REPORT.txt` — 74 broken links across 6 directories
- `docs/` file system inventory — 342 total .md files; 255 active (non-archive/non-obsolete)
- `.planning/PROJECT.md` — 37 extracted services inventory, v1.0–v5.0 milestone record, deleted files (UmbScraperV2, lib/tournament_monitor_support.rb)
- Language pair analysis: 87 de-files, 63 en-files, 27 de-only gaps, 3 en-only gaps
- `docs/developers/developer-guide.en.md` — 2 broken links to deleted enhanced_mode_system.md
- `docs/developers/umb-scraping-methods.md:73` — reference to deleted UmbScraperV2
- `docs/developers/umb-scraping-implementation.md` — 727-line pre-v5.0 plan (entirely stale)
- `.planning/codebase/STRUCTURE.md` — codebase directory layout and naming conventions

---
*Architecture research for: documentation audit and update (v6.0)*
*Researched: 2026-04-12*
