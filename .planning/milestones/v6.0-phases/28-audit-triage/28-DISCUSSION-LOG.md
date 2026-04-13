# Phase 28: Audit & Triage - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 28-Audit & Triage
**Areas discussed:** Inventory format, Stale identifier scope, Archive indexing

---

## Inventory Format

| Option | Description | Selected |
|--------|-------------|----------|
| Single markdown report | Human-readable only | |
| Structured JSON + summary | audit.json (machine) + DOCS-AUDIT-REPORT.md (human) | ✓ |
| You decide | Claude picks | |

**User's choice:** Structured JSON + summary

---

## Stale Identifier Scope

| Option | Description | Selected |
|--------|-------------|----------|
| V1-V5 targets only | Known deleted names from PROJECT.md | |
| Comprehensive git diff | Diff all deleted/renamed files across git tags | ✓ |
| Known list + grep check | Two-pass: known names then grep for missing classes | |

**User's choice:** Comprehensive git diff

---

## Archive Indexing

| Option | Description | Selected |
|--------|-------------|----------|
| Fix in Phase 28 | Add exclude_docs to mkdocs.yml now | ✓ |
| Defer to Phase 32 | Note in report, fix during nav cleanup | |

**User's choice:** Fix in Phase 28
