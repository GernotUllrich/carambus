# Phase 29: Break-Fix - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix all broken internal links and stale code references identified in docs/audit.json so the active docs site builds with zero missing-file warnings for nav entries and zero stale class references. This is structural repair only — no semantic content rewrites.

</domain>

<decisions>
## Implementation Decisions

### Fix Strategy
- **D-01:** Automation first — run `bin/fix-docs-links.rb` to handle pattern-based fixes (language suffixes, path prefixes), then manually fix remaining broken links. 75 broken links total from audit.json.
- **D-02:** When a broken link's target doesn't exist, remove the link markup and keep surrounding text. If the linked content was important, note it for Phase 31 (new documentation).

### Stale Reference Handling
- **D-03:** Update stale references to current names rather than deleting context. Specifically: FIND-076 (UmbScraperV2 → current scraper name in umb-scraping-methods.md), FIND-077/078 (tournament_monitor_support.rb → app/services/tournament_monitor/ in both .de.md and .en.md).

### Verification Approach
- **D-04:** Verify after each batch — run `bin/check-docs-links.rb` and `bin/check-docs-coderef.rb` after automation pass, then again after manual fixes. Catches regressions early.
- **D-05:** Fix link-related warnings only. Non-link mkdocs --strict warnings are out of scope for Phase 29 (tracked in audit.json for later phases). Success criterion #4 scopes to "zero missing-file warnings for nav entries."

### File Deletion Policy
- **D-06:** Grep before every delete — run grep across all active docs for any reference to the file before removing it. Log the grep result in the commit message. Satisfies success criterion #3 ("preceded by an inbound-link grep").

### Claude's Discretion
- Order of manual fixes within the batch (by severity, by file, or by error pattern)
- Commit granularity for manual fixes (per-file, per-pattern, or per-batch)
- Whether to update audit.json after fixes to reflect resolved findings

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Audit data (primary input)
- `docs/audit.json` — 78 findings assigned to Phase 29 (75 broken_link, 3 stale_ref) with file, line, action, and severity
- `docs/DOCS-AUDIT-REPORT.md` — Human-readable summary of all findings

### Fix tooling
- `bin/fix-docs-links.rb` — Existing automated link fixer with pattern-based replacements
- `bin/check-docs-links.rb` — Link checker for verification (must report zero after fixes)
- `bin/check-docs-coderef.rb` — Stale reference checker (must report zero after fixes)

### Documentation structure
- `mkdocs.yml` — Nav structure, active file list, i18n config
- `lib/tasks/mkdocs.rake` — mkdocs:check task for strict build verification

### Specific files needing stale ref updates
- `docs/developers/umb-scraping-methods.md` — FIND-076: UmbScraperV2 reference at line 73
- `docs/developers/clubcloud-upload.de.md` — FIND-077: tournament_monitor_support at line 194
- `docs/developers/clubcloud-upload.en.md` — FIND-078: tournament_monitor_support at line 194

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bin/fix-docs-links.rb` — Pattern-based link fixer; handles language suffix removal and path prefix fixes automatically
- `bin/check-docs-links.rb` — Verification tool; exit code 1 when broken links found
- `bin/check-docs-coderef.rb` — Verification tool; exit code 1 when stale refs found

### Established Patterns
- Ruby scripts in `bin/` for doc tooling (class-based, ANSI colors, --help flags)
- Audit findings are structured JSON with id, category, action, severity, file, line, phase fields
- `mkdocs build --strict` as CI-ready verification via `rake mkdocs:check`

### Integration Points
- `docs/audit.json` is the handoff artifact from Phase 28 — parseable for automated fix targeting
- `mkdocs.yml` nav structure defines "active" vs "archive" scope for verification
- Fix scripts can read audit.json to target specific files and lines

</code_context>

<specifics>
## Specific Ideas

- The audit.json already classifies each finding with an action (FIX/DELETE/UPDATE) — the executor can use this to route fixes
- Phase 29 is pure structural repair: fixing links and updating class names. No content rewriting (that's Phase 30)
- The 75 broken links likely cluster around a few common patterns — automation should handle a large percentage

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 29-break-fix*
*Context gathered: 2026-04-12*
