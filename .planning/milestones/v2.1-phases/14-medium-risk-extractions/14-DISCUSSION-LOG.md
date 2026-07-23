# Phase 14: Medium-Risk Extractions - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-10
**Phase:** 14-medium-risk-extractions
**Areas discussed:** Scraping extraction scope, RankingResolver design

---

## Scraping Extraction Scope

### DB Write Strategy
| Option | Description | Selected |
|--------|-------------|----------|
| Service writes directly | Receives tournament, creates records directly | |
| Return data, model writes | Parse HTML, return data, model does DB writes | |
| Service writes (Recommended) | Faithful extraction with @tournament reference | ✓ |

### Method Scope
| Option | Description | Selected |
|--------|-------------|----------|
| Move everything | All scraping methods to service (~700+ lines) | |
| Keep parse_table_td on model | Complex state machine logic stays | |
| You decide | Claude determines cleanest boundary | ✓ |

---

## RankingResolver Design

### Dependency Access
| Option | Description | Selected |
|--------|-------------|----------|
| Inject tournament_monitor | Service receives TM instance | |
| Inject data + tournament | Decoupled, but changes signatures | |
| Inject TM (Recommended) | Faithful extraction, group_rank calls PlayerGroupDistributor directly | ✓ |

---

## Claude's Discretion

- Exact extraction boundary for PublicCcScraper
- Internal organization of service files
- self → @tournament conversion details
