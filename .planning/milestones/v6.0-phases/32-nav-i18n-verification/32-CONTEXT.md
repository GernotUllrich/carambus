# Phase 32: Nav, i18n & Verification - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Register all Phase 31 namespace pages in mkdocs.yml nav, resolve all in-nav bilingual gaps, fix all mkdocs strict warnings to achieve zero, and run a full verification sweep as the milestone's final gate. This is the closing phase — no new content creation, only nav wiring, translation gap closure, and build verification.

</domain>

<decisions>
## Implementation Decisions

### Bilingual Gap Resolution
- **D-01:** Translate all 17 in-nav gaps — create full AI-assisted translations for every missing `.de.md` or `.en.md` pair. No stubs. Ensures no EN user silently falls back to DE for any nav-linked page.
- **D-02:** Gap list (from `bin/check-docs-translations.rb --nav-only`): 8 missing EN files + 9 missing DE files. Some are monolingual docs that need a bilingual counterpart.

### Nav Registration
- **D-03:** New `Services:` subsection under `Developers:` in mkdocs.yml nav, placed after the existing `UMB Scraping:` block. Lists all 8 namespace pages + video-crossref.
- **D-04:** Include `nav_translations` entries for DE labels of all new nav items.

### Strict Build Target
- **D-05:** Fix ALL 29 strict-mode warnings regardless of origin. This is the final phase — zero warnings is the clean baseline for future maintenance. Includes orphan pages needing nav entries or removal, missing file warnings, broken nav references, and unresolved i18n fallbacks.

### Final Verification Pass
- **D-06:** Full sweep as the last task — re-run ALL verification scripts: `bin/check-docs-links.rb`, `bin/check-docs-translations.rb --nav-only`, `bin/check-docs-coderef.rb`, and `mkdocs build --strict`. All must report zero issues. This is the milestone's final gate.

### Bilingual Strategy (carried from Phase 30/31)
- **D-07:** German primary, AI-assisted translation to English (consistent with prior phases).
- **D-08:** One commit per bilingual doc pair (consistent with prior phases).

### Claude's Discretion
- Order of operations (nav first, then translations, or interleaved)
- How to handle orphan pages that cause strict warnings (add to nav vs remove)
- nav_translations label phrasing for German
- Whether to reorganize existing nav entries while adding new ones

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### mkdocs config (primary target)
- `mkdocs.yml` — Full nav structure, theme config, i18n settings, nav_translations

### Audit data (gap source)
- `docs/audit.json` — 21 bilingual_gap findings assigned to Phase 32 (FIND-091 through FIND-111)

### Verification tooling
- `bin/check-docs-links.rb` — Link checker (must report zero)
- `bin/check-docs-translations.rb` — Translation gap checker (must report zero with --nav-only)
- `bin/check-docs-coderef.rb` — Stale reference checker (must report zero)
- `lib/tasks/mkdocs.rake` — mkdocs:check task (must pass with zero warnings)

### Phase 31 pages to register
- `docs/developers/services/table-monitor.{de,en}.md`
- `docs/developers/services/region-cc.{de,en}.md`
- `docs/developers/services/tournament.{de,en}.md`
- `docs/developers/services/tournament-monitor.{de,en}.md`
- `docs/developers/services/league.{de,en}.md`
- `docs/developers/services/party-monitor.{de,en}.md`
- `docs/developers/services/umb.{de,en}.md`
- `docs/developers/services/video-crossref.{de,en}.md`

### Files needing bilingual pairs (from translation checker)
- 8 missing EN: deployment-checklist, frontend-sti-migration, pool-scoreboard-changelog, rubymine-setup, scenario-workflow, fixture-collection-guide, testing-quickstart, umb-deployment-checklist
- 9 missing DE: same 8 plus managers/table-reservation

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bin/check-docs-translations.rb --nav-only` — Identifies exactly which in-nav pages lack bilingual pairs
- `mkdocs-static-i18n` plugin with `docs_structure: suffix` — handles `.de.md`/`.en.md` transparently
- Phase 30/31 bilingual docs — established pattern for AI-assisted translation

### Established Patterns
- `nav_translations` in mkdocs.yml maps EN nav labels to DE equivalents
- Bilingual `.de.md`/`.en.md` suffix convention
- `exclude_docs: archive/**, obsolete/**` already configured (Phase 28)

### Integration Points
- `mkdocs.yml` nav — adding Services subsection + registering any orphan pages
- `mkdocs build --strict` — the ultimate verification gate
- All 4 verification scripts must pass as the milestone's final gate

</code_context>

<specifics>
## Specific Ideas

- The 17 translation gaps are mostly developer-focused docs — translations should use consistent technical terminology established in Phase 30/31
- Some "missing" pairs may actually be the same file appearing monolingual (e.g., `deployment-checklist.md` exists but not as `.de.md`/`.en.md` pair) — may need renaming + creating the counterpart
- The 29 strict warnings likely include warnings about the Phase 31 services pages not being in nav yet — fixing nav registration should resolve a chunk of them

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 32-nav-i18n-verification*
*Context gathered: 2026-04-13*
