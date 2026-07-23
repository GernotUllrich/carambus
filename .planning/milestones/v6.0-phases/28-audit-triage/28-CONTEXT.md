# Phase 28: Audit & Triage - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Build a complete staleness inventory of the docs/ directory before any content editing. Create two new audit scripts (translation coverage, code reference checker). Add `mkdocs:check` rake task. Fix archive search indexing. Output: structured audit report that gates Phases 29-32.

</domain>

<decisions>
## Implementation Decisions

### Inventory Output Format
- **D-01:** Dual output — `docs/audit.json` (machine-parseable, structured by category) AND `docs/DOCS-AUDIT-REPORT.md` (human-readable summary with sections: broken links, stale refs, coverage gaps, bilingual gaps)
- **D-02:** The JSON enables automated tracking across phases (e.g., Phase 29 can parse FIX items, Phase 31 can parse DOC items). The markdown is for human review.

### Stale Identifier Scope
- **D-03:** Comprehensive git diff approach — diff all deleted/renamed files across v1.0–v5.0 git tags to build the stale identifier list. Catches everything, not just known targets.
- **D-04:** Use git tags (v1.0, v2.0, v2.1, v3.0, v4.0, v5.0) to compute the full set of deleted/renamed Ruby files, then grep docs/ for any reference to those names.

### Archive Indexing
- **D-05:** Fix archive search indexing in Phase 28 — add `exclude_docs` or equivalent in `mkdocs.yml` to prevent `archive/` and `obsolete/` from appearing in site search results. This is a config change, not a content edit.

### Claude's Discretion
- JSON schema design for audit.json (categories, fields, severity levels)
- How to handle false positives in the git diff (e.g., files renamed but still referenced correctly)
- Whether `check-docs-coderef.rb` should be a separate script or integrated into `check-docs-links.rb`

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing audit tooling
- `bin/check-docs-links.rb` — 291-line link checker; pattern for new scripts
- `bin/fix-docs-links.rb` — 171-line link fixer
- `lib/tasks/mkdocs.rake` — Existing mkdocs rake tasks
- `docs/BROKEN_LINKS_REPORT.txt` — 244-line broken links baseline (74 broken links)

### Documentation structure
- `mkdocs.yml` — Full site config with nav structure, theme, i18n settings
- `docs/` — 342 total docs (255 active, 87 in archive/obsolete)

### Research findings
- `.planning/research/STACK.md` — Zero new tools needed; 26-page translation gap; two scripts to add
- `.planning/research/FEATURES.md` — 37 services have zero doc coverage; UMB docs actively misleading
- `.planning/research/ARCHITECTURE.md` — 5-phase build order; audit-first strategy
- `.planning/research/PITFALLS.md` — Stale identifiers confirmed; archive not excluded from search

### Git tags for diff
- Tags: v1.0, v2.0, v2.1, v3.0, v4.0, v5.0 — used for comprehensive deleted/renamed file diff

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bin/check-docs-links.rb` — Established pattern for Ruby doc audit scripts; uses `Find.find`, regex link extraction, path resolution
- `docs/BROKEN_LINKS_REPORT.txt` — Baseline of 74 broken links; new audit report extends this
- `mkdocs-static-i18n` plugin — Already configured with `fallback_to_default: true`

### Established Patterns
- Ruby scripts in `bin/` for doc tooling (not gems, not rake tasks for scripts)
- Rake tasks in `lib/tasks/` for build commands
- Plain text reports in `docs/` for audit output

### Integration Points
- `mkdocs.yml` — Config changes for archive exclusion
- `lib/tasks/mkdocs.rake` — New `mkdocs:check` task wrapping `mkdocs build --strict`
- Git tags — Source for comprehensive file diff

</code_context>

<specifics>
## Specific Ideas

- The audit report is the single deliverable that gates ALL subsequent phases — quality here saves churn later
- Archive exclusion is a config-only fix (not content edit), which is why it fits in the audit phase
- The comprehensive git diff may surface files the user doesn't care about (test fixtures, config files) — the script should filter to only app/, lib/, docs/ references

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 28-audit-triage*
*Context gathered: 2026-04-12*
