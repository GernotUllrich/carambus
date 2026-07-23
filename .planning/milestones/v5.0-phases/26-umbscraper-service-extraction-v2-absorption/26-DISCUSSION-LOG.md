# Phase 26: UmbScraper Service Extraction + V2 Absorption - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 26-UmbScraper Service Extraction + V2 Absorption
**Areas discussed:** Service boundaries, V2 deprecation strategy, PDF parsing scope, Extraction order

---

## Service Boundaries

| Option | Description | Selected |
|--------|-------------|----------|
| Single PdfParser | One class handles all PDF types | |
| Split by PDF type | Separate classes per PDF format | |
| You decide | Claude picks based on complexity | ✓ |

**User's choice:** You decide

---

## V2 Deprecation Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Delete entirely | Remove V2 and its char test completely | ✓ |
| Keep as thin facade | Delegate to Umb:: services | |
| Delete file, keep tests | Adapt char tests to new services | |

**User's choice:** Delete entirely

---

## PDF Parsing Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Player + group only | Absorb V2's working parsers only | |
| All three PDF types | Include ranking parsing (implement V2 stub) | ✓ |
| Player + group + stub | Working parsers + carry ranking stub | |

**User's choice:** All three PDF types — pulls RANK-01 into Phase 26 scope

---

## Extraction Order

| Option | Description | Selected |
|--------|-------------|----------|
| Keep bottom-up | Same planned order | |
| PDF first | PdfParser first (most valuable for video) | |
| You decide | Claude picks optimal order | ✓ |

**User's choice:** You decide
