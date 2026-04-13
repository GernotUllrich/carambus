# Phase 30: Content Updates - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-13
**Phase:** 30-content-updates
**Areas discussed:** Umb doc rewrite depth, Bilingual creation strategy, Developer guide services format, Commit strategy

---

## Umb Doc Rewrite Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Structural rewrite | Replace UmbScraperV2 with Umb:: architecture: service list, data flow, entry points. No deep examples. | ✓ |
| Minimal swap | Just swap class names, keep existing prose structure | |
| Full documentation | Complete rewrite with examples, config, troubleshooting | |

**User's choice:** Structural rewrite
**Notes:** Middle ground — enough to be accurate without over-scoping

---

## Bilingual Creation Strategy

### Language Priority

| Option | Description | Selected |
|--------|-------------|----------|
| German primary, translate to EN | Write DE first (existing docs are German), translate to EN | ✓ |
| English primary, translate to DE | Write EN first, translate to DE | |
| Write both independently | Each language optimized separately | |

**User's choice:** German primary, translate to EN
**Notes:** Consistent with project default locale (:de)

### Translation Method

| Option | Description | Selected |
|--------|-------------|----------|
| AI-assisted | Use Claude to translate during execution | ✓ |
| Manual only | Write both versions manually | |

**User's choice:** AI-assisted
**Notes:** Fast, consistent terminology in one pass

---

## Developer Guide Services Format

### Presentation

| Option | Description | Selected |
|--------|-------------|----------|
| Table by namespace | One table per namespace (7 tables), columns: class, path, description | ✓ |
| Flat alphabetical list | Single sorted list of all services | |
| Expandable sections | Collapsible sections per namespace using admonitions | |

**User's choice:** Table by namespace

### Detail Level

| Option | Description | Selected |
|--------|-------------|----------|
| One-liner description | Class + path + single sentence | ✓ |
| Brief paragraph | 2-3 sentences per service | |
| Name and path only | Minimal index | |

**User's choice:** One-liner description
**Notes:** Enough to find the right service; detailed pages can come later

---

## Commit Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| One commit per doc pair | DE+EN committed together per doc | ✓ |
| One commit per task | All files from a task in one commit | |
| Single commit | Everything in one commit | |

**User's choice:** One commit per doc pair
**Notes:** Clear traceability, satisfies success criterion #4

---

## Claude's Discretion

- Prose structure, section order, heading design
- Data flow presentation format
- Service one-liner wording
- Cross-references between umb docs

## Deferred Ideas

None — discussion stayed within phase scope
