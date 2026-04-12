# Requirements: Carambus API v6.0

**Defined:** 2026-04-12
**Core Value:** A maintainable, well-tested codebase where every test is trustworthy and every model is appropriately sized.

## v6.0 Requirements

Requirements for Documentation Quality milestone. Each maps to roadmap phases.

### Documentation Audit

- [ ] **AUDIT-01**: Build complete staleness inventory — broken links + code identifier sweep + coverage gap map — before any content editing
- [ ] **AUDIT-02**: Create `bin/check-docs-translations.rb` script for translation coverage reporting (de vs en file pairs)
- [ ] **AUDIT-03**: Add `mkdocs:check` rake task wrapping `mkdocs build --strict` for CI-ready doc validation

### Broken Link & Stale Reference Fixes

- [ ] **FIX-01**: Fix all 74 broken internal links catalogued in BROKEN_LINKS_REPORT.txt
- [ ] **FIX-02**: Remove/update all references to deleted code (UmbScraperV2, tournament_monitor_support.rb, pre-refactoring god-object descriptions) in non-archive docs

### Content Updates

- [ ] **UPDATE-01**: Rewrite `developers/umb-scraping-implementation.md` and `developers/umb-scraping-methods.md` to reflect the Umb:: namespace with 10 services
- [ ] **UPDATE-02**: Update developer guide services sections to reflect all 37 extracted services across 7 namespaces

### New Documentation

- [ ] **DOC-01**: Document all 37 extracted services grouped by namespace (8 namespace overview pages)
- [ ] **DOC-02**: Document video cross-referencing system (Video::TournamentMatcher, Video::MetadataExtractor, SoopliveBilliardsClient)
- [ ] **DOC-03**: Add new docs to mkdocs.yml nav, resolve in-nav bilingual gaps (de/en), pass `mkdocs build --strict` with zero warnings

## Future Requirements

Deferred to future release. Tracked but not in current roadmap.

### Translation

- **TRANSLATE-01**: Full EN translation of 26 de-only non-nav pages

### Visual

- **SCREENSHOT-01**: Update/fix 22 broken screenshot references in players/ section

## Out of Scope

| Feature | Reason |
|---------|--------|
| Full translation of archive/internal docs | 5200+ lines of translation for non-nav files; not user-visible |
| New screenshots | Fix broken refs first; new screenshots are a visual design task |
| Automated stale-content detection CI | Over-engineering; known staleness is already specific and catalogued |
| External link checking | All 74 known broken links are internal; external links are low-risk |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUDIT-01 | Phase 28 | Pending |
| AUDIT-02 | Phase 28 | Pending |
| AUDIT-03 | Phase 28 | Pending |
| FIX-01 | Phase 29 | Pending |
| FIX-02 | Phase 29 | Pending |
| UPDATE-01 | Phase 30 | Pending |
| UPDATE-02 | Phase 30 | Pending |
| DOC-01 | Phase 31 | Pending |
| DOC-02 | Phase 31 | Pending |
| DOC-03 | Phase 32 | Pending |

**Coverage:**
- v6.0 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-12*
*Last updated: 2026-04-12 after roadmap creation*
