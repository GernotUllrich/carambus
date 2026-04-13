# Phase 31: New Documentation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-13
**Phase:** 31-new-documentation
**Areas discussed:** Namespace page depth, Umb:: page overlap, Video:: page scope, File organization

---

## Namespace Page Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Architecture + public interface | Role, services, public signatures, data contracts. ~200-400 lines. | ✓ |
| Architecture overview only | Role, service list, one-liners. ~100-150 lines. | |
| Full reference docs | Architecture + signatures + config + examples + errors. ~500-800 lines. | |

**User's choice:** Architecture + public interface
**Notes:** Enough for developer orientation without becoming reference docs

---

## Umb:: Page Overlap with Phase 30

| Option | Description | Selected |
|--------|-------------|----------|
| Summary page linking to existing | Brief overview linking to umb-scraping-implementation + methods | ✓ |
| Skip Umb:: entirely | Count Phase 30 docs as coverage | |
| New standalone page | Independent page, duplicating content | |

**User's choice:** Summary page linking to existing
**Notes:** Satisfies "8 namespace pages" criterion without duplication

---

## Video:: Page Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Follow SC-2 strictly | TournamentMatcher scoring, MetadataExtractor regex+AI, SoopliveBilliardsClient, operational workflow | ✓ |
| Broader video system | SC-2 plus YouTube pipeline, video model associations, UI | |
| You decide | Claude's discretion on broader context | |

**User's choice:** Follow SC-2 strictly
**Notes:** Focused and verifiable against the success criterion

---

## File Organization

### Location

| Option | Description | Selected |
|--------|-------------|----------|
| docs/developers/services/ subdirectory | New subdirectory, grouped namespace docs | ✓ |
| Flat in docs/developers/ | Direct in existing directory | |
| docs/architecture/services/ | New top-level section | |

### Naming

| Option | Description | Selected |
|--------|-------------|----------|
| Namespace as kebab-case | table-monitor.de.md, region-cc.de.md, etc. | ✓ |
| services- prefix | services-table-monitor.de.md | |
| namespace- prefix | namespace-table-monitor.de.md | |

**User's choice:** docs/developers/services/ + kebab-case naming
**Notes:** Clean separation, matches existing naming patterns

---

## Claude's Discretion

- Internal page structure (headings, sections)
- Data contract presentation format
- Whether to create services/ index page
- mkdocs.yml nav updates

## Deferred Ideas

None — discussion stayed within phase scope
