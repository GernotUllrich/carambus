# Project Research Summary

**Project:** Carambus API — Documentation Quality Audit (v6.0)
**Domain:** Documentation audit and update for mkdocs-material + multilingual docs against a Rails 7.2 codebase
**Researched:** 2026-04-12
**Confidence:** HIGH

## Executive Summary

v6.0 is a pure documentation audit milestone. The codebase underwent five milestones of significant refactoring (v1.0–v5.0), extracting 37 service classes across 8 namespaces and deleting multiple large classes (UmbScraperV2, lib/tournament_monitor_support.rb), but documentation was not updated alongside those changes. The result is a docs site with 74 confirmed broken links, active developer docs referencing deleted classes, and zero documentation coverage for any of the 37 extracted services. The goal is to bring the docs into accurate alignment with the current codebase — no new features, no tooling changes, no new infrastructure.

The recommended approach is audit-first: produce a complete inventory of broken links, stale code references, and documentation gaps before writing a single content update. This avoids the classic pitfall of fixing visible issues while missing deeper staleness embedded in code blocks and diagrams. The existing toolchain (mkdocs 1.6.1, mkdocs-material 9.6.15, mkdocs-static-i18n 1.3.0, Ruby link-checking scripts) is fully sufficient. The only new tooling required is two small Ruby scripts (~30–50 lines each) for translation coverage reporting and stale-identifier detection — both are stdlib-only additions to the existing pattern.

The primary risk is scope creep: the docs corpus contains 177 markdown files and 342 total .md files across active, archive, and internal directories. The audit must stay focused on nav-linked active docs, resist translating non-nav DE-only internal files, and avoid auto-generating API reference docs. A secondary risk is language pair discipline: the mkdocs i18n plugin silently serves German content to English users when `.en.md` files are missing, making English staleness invisible unless actively checked. Every content change must update both language files in the same commit.

## Key Findings

### Recommended Stack

No new dependencies are required. The entire v6.0 toolchain is already installed and working. The only additions are two small stdlib-Ruby scripts that extend the existing link-checking pattern.

**Core technologies:**
- `mkdocs` 1.6.1: Build/serve/validate docs — already configured; `mkdocs build --strict` provides CI-style validation
- `mkdocs-material` 9.6.15: Theme with i18n integration — already configured, no changes needed
- `mkdocs-static-i18n` 1.3.0: `.de.md`/`.en.md` suffix-based multilingual docs — already working with `fallback_to_default: true`
- `bin/check-docs-links.rb` (existing): Link checker — already identified 74 broken links; use as baseline
- `bin/fix-docs-links.rb` (existing): Pattern-based batch fixer — useful for automatable link repairs
- `bin/check-docs-translations.rb` (to create, ~30 lines): Identifies `.de.md` files missing `.en.md` counterparts and vice versa
- `bin/check-docs-coderef.rb` (to create, ~50 lines): Extracts CamelCase class names from docs and verifies they exist in `app/` — catches deleted-class references

### Expected Features

**Must have (P1 — milestone not complete without these):**
- Fix all 74 broken internal links — docs are broken without this; a pre-existing report already enumerates them
- Rewrite `umb-scraping-implementation.md` and `umb-scraping-methods.md` — both reference `UmbScraperV2` (deleted v5.0) as current architecture
- Add developer reference for all 37 extracted services, grouped by namespace (8 groups) — zero current coverage of 5-milestone refactoring
- Verify all mkdocs.yml nav entries resolve to existing files — build warnings surface missing pages

**Should have (P2 — strong quality improvement):**
- Document video cross-referencing system (`Video::TournamentMatcher`, confidence scoring, operational workflow) — non-obvious v5.0 architecture with zero docs
- Create EN stubs for in-nav pages currently DE-only — English users silently receive German content via fallback
- Stale content pass on 10 most likely stale developer docs (game-plan-reconstruction, league-management, clubcloud-integration)

**Defer (P3 — not this milestone):**
- Full translation of non-nav DE-only docs (internal, archive, studies) — 26 files × ~200 lines each; translation cost far exceeds value for docs users never see
- Automated stale content detection in CI — multi-week project; known stale files are already identified
- New screenshots for scoreboard guide — fix 34 existing broken screenshot refs first; do not add new placeholders without actual images

### Architecture Approach

The audit operates on the existing five-audience docs structure (decision-makers, players, managers, administrators, developers) with no restructuring required. The primary audit target is `developers/` — the only section significantly affected by v1.0–v5.0 refactoring. Work proceeds in four sequential phases: structural triage (audit and classify all findings as DELETE/UPDATE/CREATE), break-fix (link repairs and stale-reference removal), content updates (rewrite inaccurate sections), and new content creation (document undocumented v1.0–v5.0 work). Language pair discipline is non-negotiable: every content change must update both `.de.md` and `.en.md` in the same commit.

**Major components:**
1. `mkdocs.yml` nav (42 entries) — source of truth for what is published; some entries currently lack `.de.md`/`.en.md` pairs
2. Active docs (~255 files, non-archive/non-obsolete) — audit target; mixed state from stale pre-v5.0 to current
3. `docs/archive/` (87 files) + `docs/obsolete/` (2 files) — frozen; do not modify content; verify they are excluded from mkdocs search indexing
4. Language pairs (`.de.md`/`.en.md`) — 87 DE files vs 63 EN files; 27 DE-only gaps, 3 EN-only gaps; every update must maintain or improve parity
5. Two new Ruby audit scripts — extend existing link-checking toolchain without adding Python dependencies

### Critical Pitfalls

1. **Auditing only prose, missing embedded code identifiers** — grep for class names, file paths, and method references in docs BEFORE reading any file. `UmbScraperV2` and `tournament_monitor_support` were confirmed via grep, not prose reading. Build a code-identifier inventory as Phase A.

2. **Updating one language file without its pair** — `fallback_to_default: true` silently hides the divergence. Every file change must include both `.de.md` and `.en.md` in the same commit; verify with `diff` before marking a file done.

3. **Deleting stale content without checking inbound links** — grep the full `docs/` tree for any file's name before deleting it; check `mkdocs.yml` nav; verify broken link count did not increase after deletion.

4. **Over-documenting extracted service internals** — document architecture (namespace role, public interface, data contract) not implementation. No published page should describe private methods. 37 services across 8 namespaces maps to 8 namespace-level overview sections, not 37 per-class pages.

5. **Treating archived docs as harmless** — mkdocs indexes all files under `docs/` unless explicitly excluded. Verify `mkdocs.yml` has `exclude_docs` or `not_in_nav` directives covering `docs/archive/` and `docs/internal/`; add "Archived — this feature no longer exists" notices to archive pages containing deleted-code examples.

## Implications for Roadmap

Based on research, the natural phase structure is audit-before-fix, structural-before-semantic, and existing-accuracy-before-new-content.

### Phase 1: Audit and Triage

**Rationale:** Cannot estimate or execute fix work without knowing the full scope. Two Ruby scripts need to be created; the identifier-grep inventory must be built before any content is touched. A complete DELETE/UPDATE/CREATE classification prevents context-switching between audit and fix modes.

**Delivers:** Complete staleness inventory (broken links by category, stale class references with file/line citations, documentation gaps per namespace, bilingual coverage gaps for nav-linked files), plus the two new audit scripts (`bin/check-docs-translations.rb`, `bin/check-docs-coderef.rb`).

**Addresses:** FEATURES P1 "audit nav against actual file existence"; establishes baseline for all subsequent work

**Avoids:** Pitfall 1 (editing while auditing creates moving target); Pitfall 3 (deletion without inbound-link check)

### Phase 2: Break-Fix (DELETE and Link Repairs)

**Rationale:** Fixes things that are actively wrong with low content risk. Removing and repairing is safer than rewriting; establishes a clean link baseline against which update work can be verified.

**Delivers:** Zero (or near-zero) broken links in active nav docs; no active doc references deleted classes (UmbScraperV2, tournament_monitor_support); nav file existence verified; duplicate nav entries resolved.

**Uses:** `bin/check-docs-links.rb` (verification), `bin/fix-docs-links.rb` (automatable repairs), `bin/check-docs-coderef.rb` (identifier sweep)

**Avoids:** Pitfall 3 (inbound-link grep before every deletion); Pitfall 5 (archive exclusion verification in mkdocs.yml)

### Phase 3: Update Existing Docs

**Rationale:** Rewriting inaccurate content has semantic risk — requires reading both the doc and the corresponding code. Must happen after the audit inventory is complete (scope is known) and after link repairs (updated docs don't inherit broken links).

**Delivers:** `umb-scraping-implementation.md` reflects actual v5.0 `Umb::` architecture; `umb-scraping-methods.md` method inventory matches `Umb::*` namespace; `international/umb_scraper.md` describes facade + 10 services; `developer-guide.{de,en}.md` services section updated; concern descriptions verified.

**Avoids:** Pitfall 2 (both language files updated per commit); Pitfall 6 (code examples verified runnable against current codebase)

### Phase 4: Create New Documentation

**Rationale:** Highest effort, highest value. Done last because structural accuracy issues are resolved, and new docs can reference the already-corrected architecture. Grouped by namespace for tractability (8 namespace overviews, not 37 individual class pages).

**Delivers:** Developer reference for all 37 extracted services (8 namespace sections, both languages); `Umb::` architecture doc (10 services, PdfParser breakdown, facade pattern); `Video::` cross-referencing doc (TournamentMatcher, MetadataExtractor, confidence scoring, operational workflow); updated architecture overview per refactored domain.

**Addresses:** FEATURES P1 "document 37 extracted services"; FEATURES P2 "video cross-referencing docs"

**Avoids:** Pitfall 4 (architecture overview before any method-level docs; no private-method documentation); Pitfall 7 (every namespace gets at least one architecture-level reference)

### Phase 5: Nav, i18n, and Verification

**Rationale:** Final integration pass. New Phase 4 docs must be added to `mkdocs.yml` nav with nav_translations entries; bilingual gap decisions resolved for in-nav pages; final build must pass clean.

**Delivers:** All Phase 4 docs in mkdocs.yml nav with DE nav_translations; EN stubs for in-nav developer docs currently DE-only; `mkdocs build --strict` passes; broken link count at or below Phase 2 baseline.

**Addresses:** FEATURES P2 "EN stubs for in-nav DE-only pages"; FEATURES P1 "verify nav file existence"

**Avoids:** Architecture Anti-Pattern 4 (new docs without nav entries); Pitfall 2 (language pair parity verified)

### Phase Ordering Rationale

- Audit must precede all fix work — without the full inventory, scope is unknown and fixes create a moving target
- Link and structural repairs precede semantic rewrites — a clean link baseline makes it possible to verify that updates don't introduce new breakage
- Existing accuracy before new content — correcting stale information in active docs is higher priority than adding new pages for undocumented services
- Nav and i18n last — new nav entries can only be added after new content is written; final verification can only happen after all changes land

### Research Flags

Phases with standard patterns (skip research-phase):
- **Phase 2 (Break-Fix):** Well-documented patterns; existing link checker script handles verification; deletion checklist is mechanical
- **Phase 5 (Nav/i18n Cleanup):** mkdocs.yml nav editing and i18n plugin behavior already understood from current working state

Phases likely needing codebase verification during planning (not exploratory research, but careful code reading):
- **Phase 3 (Update Existing Docs):** Each UMB docs rewrite requires reading the corresponding `app/services/umb/` source files to verify current behavior before writing
- **Phase 4 (Create New Docs):** Writing accurate architecture overviews requires reading each service's source; especially `Video::TournamentMatcher` (confidence scoring, two-path matching) and `Umb::PdfParser` subclasses — non-obvious architectures that need careful inspection before documentation

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All tools read directly from installed packages and existing scripts; no speculation |
| Features | HIGH | Work items derived from direct file inventory: 74 broken links confirmed, 37 services confirmed absent from docs, stale references confirmed via grep with file/line citations |
| Architecture | HIGH | Phase structure derived from direct inspection of docs corpus; all findings have file/line citations |
| Pitfalls | HIGH | All pitfalls confirmed via grep on live repo; specific stale references cited with file and line number, not inferred |

**Overall confidence:** HIGH

### Gaps to Address

- **In-nav DE-only gap count:** Research identified 27 DE-only gaps total, but not all are in the mkdocs.yml nav. The exact count of in-nav pages lacking `.en.md` must be determined in Phase 1 before estimating EN stub effort for Phase 5.
- **Archive search indexing status:** `mkdocs.yml` has no `exclude_docs` directive for archive directories. Whether archive content is currently indexed requires `mkdocs build` + `site/search/search_index.json` inspection — to be done in Phase 1.
- **`managers/` and `international/` broken links (4 total):** Root causes noted as "unknown — verify during audit" in BROKEN_LINKS_REPORT.txt; to be confirmed in Phase 1.
- **`lib/tournament_monitor_support.rb` doc references:** Grep confirmed references in `tournament-architecture-overview.en.md` and `clubcloud-upload.{de,en}.md`; a full sweep may surface additional files not yet identified.

## Sources

### Primary (HIGH confidence)

All findings from direct codebase inspection — no external sources required.

- `docs/BROKEN_LINKS_REPORT.txt` — 74 confirmed broken links, pre-audit baseline; scope and exclusions documented
- `mkdocs.yml` — nav structure (42 entries), i18n plugin config (`fallback_to_default: true`, suffix pattern), no `exclude_docs` directive
- `.planning/PROJECT.md` — 37 extracted services inventory, deleted files (UmbScraperV2, lib/tournament_monitor_support.rb), v1.0–v5.0 milestone record
- `bin/check-docs-links.rb`, `bin/fix-docs-links.rb`, `lib/tasks/mkdocs.rake` — existing toolchain
- `docs/developers/umb-scraping-methods.md:73` — confirmed `UmbScraperV2` stale reference (active nav page)
- `docs/developers/tournament-architecture-overview.en.md` — confirmed `tournament_monitor_support` stale reference
- File tree analysis: 89 `.de.md` files, 63 `.en.md` files, 342 total `.md` files across docs/
- Installed packages verified: mkdocs 1.6.1, mkdocs-material 9.6.15, mkdocs-static-i18n 1.3.0, pymdown-extensions 10.16

### Secondary (MEDIUM confidence)

- https://github.com/ultrabug/mkdocs-static-i18n — no built-in consistency check; missing translations silently fall back (documented plugin behavior)
- https://pypi.org/project/mkdocs-linkcheck/ — external link checker; assessed as out-of-scope for v6.0 (74 known broken links are all internal)

---
*Research completed: 2026-04-12*
*Ready for roadmap: yes*
