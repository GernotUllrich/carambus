# Phase 27: Video Cross-Referencing - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 27-Video Cross-Referencing
**Areas discussed:** Matching confidence, SoopLive integration, Batch vs incremental, MetadataExtractor

---

## Matching Confidence

| Option | Description | Selected |
|--------|-------------|----------|
| Weighted formula | date(0.3) + player(0.4) + title(0.3), auto above 0.75, review 0.5-0.75 | |
| Binary gates | Must pass date AND (player OR title) | |
| You decide | Claude designs scoring model | ✓ |

**User's choice:** You decide

---

## SoopLive Integration

| Option | Description | Selected |
|--------|-------------|----------|
| Full adapter | All endpoints, store in DB, reusable | |
| VOD linking only | Minimal: fetch matches, extract replay_no | |
| Adapter + daily sync | Full adapter wired into DailyInternationalScrapeJob | ✓ |

**User's choice:** Adapter + daily sync

---

## Batch vs Incremental

| Option | Description | Selected |
|--------|-------------|----------|
| Both | Rake backfill + incremental in daily job | ✓ |
| Incremental only | Only match new videos per daily job | |
| Backfill first | Rake task first, daily wiring later | |

**User's choice:** Both

---

## MetadataExtractor

| Option | Description | Selected |
|--------|-------------|----------|
| Regex first, AI fallback | Regex for known patterns, AiSearchService for unmatched | ✓ |
| AI for everything | GPT-4 for all titles | |
| Regex only | No AI dependency | |

**User's choice:** Regex first, AI fallback
