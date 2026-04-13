# Phase 29: Break-Fix - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 29-break-fix
**Areas discussed:** Fix strategy, Stale ref handling, Verification approach, File deletion policy

---

## Fix Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Automation first | Run bin/fix-docs-links.rb first for pattern-based fixes, then manually fix remaining | ✓ |
| All manual | Fix each broken link individually by reading doc and deciding target | |
| Batch by pattern | Group by error pattern, write a fix script per pattern | |

**User's choice:** Automation first
**Notes:** Minimizes manual work — let existing tooling handle the common patterns

### Missing Target Sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Remove the link | Delete link markup, keep surrounding text, note for Phase 31 if important | ✓ |
| Replace with stub page | Create placeholder .md at target path | |
| Comment out the link | HTML comment to preserve but not break build | |

**User's choice:** Remove the link
**Notes:** Clean removal preferred over stubs or comments

---

## Stale Ref Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Update to current names | Replace stale class names with current equivalents | ✓ |
| Delete the stale references | Remove lines/paragraphs containing stale names | |
| Rewrite affected sections | Full section rewrite to reflect current architecture | |

**User's choice:** Update to current names
**Notes:** Preserves documentation context while fixing the references

---

## Verification Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Verify after each batch | Run check scripts after automation, then after manual fixes | ✓ |
| Fix everything, verify once | All fixes first, verification at end | |
| Continuous verification | Verify after every single file edit | |

**User's choice:** Verify after each batch
**Notes:** Catches regressions from cascading link changes

### Strict Mode Sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Fix link warnings only | Non-link warnings out of scope, tracked for later phases | ✓ |
| Fix all strict warnings | Clear all mkdocs --strict warnings | |
| You decide | Claude's discretion on opportunistic fixes | |

**User's choice:** Fix link warnings only
**Notes:** Phase 29 scope is structural link repair, not full build cleanup

---

## File Deletion Policy

| Option | Description | Selected |
|--------|-------------|----------|
| Grep before every delete | Run grep across active docs before removing, log in commit message | ✓ |
| Batch grep at end | Delete as needed, verify no dangling refs afterward | |
| No file deletions | Defer all deletions to later phase | |

**User's choice:** Grep before every delete
**Notes:** Directly satisfies success criterion #3 ("preceded by an inbound-link grep")

---

## Claude's Discretion

- Fix ordering within manual batch
- Commit granularity for manual fixes
- Whether to update audit.json post-fixes

## Deferred Ideas

None — discussion stayed within phase scope
