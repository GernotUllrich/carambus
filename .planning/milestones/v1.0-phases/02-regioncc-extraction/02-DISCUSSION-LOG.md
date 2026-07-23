# Phase 2: RegionCc Extraction - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the discussion.

**Date:** 2026-04-09
**Phase:** 02-regioncc-extraction
**Mode:** discuss (interactive)
**Areas discussed:** HTTP client design, Syncer service granularity, Delegation pattern, VCR cassette strategy

## Questions & Answers

### HTTP Client Design

| Question | Options Presented | Selected |
|----------|-------------------|----------|
| How should ClubCloudClient handle HTTP transport? | Thin Net::HTTP wrapper, Faraday-based client, You decide | **Thin Net::HTTP wrapper** |
| Should ClubCloudClient manage its own login/session state? | Self-contained sessions, Injected session, You decide | **Self-contained sessions** |

### Syncer Service Granularity

| Question | Options Presented | Selected |
|----------|-------------------|----------|
| How should the 25+ sync methods be grouped? | 3 main syncers, Fine-grained (7-8), 2 services only | **Fine-grained (7-8 services)** |
| Should syncers inherit ApplicationService? | ApplicationService.call pattern, Namespaced module, You decide | **ApplicationService.call pattern** |

### Delegation Pattern

| Question | Options Presented | Selected |
|----------|-------------------|----------|
| How should RegionCc delegate to new services? | Thin wrappers preserving API, Remove methods + update callers, Deprecation wrappers | **Thin wrappers preserving public API** |

### VCR Cassette Strategy

| Question | Options Presented | Selected |
|----------|-------------------|----------|
| How should VCR cassettes be handled? | Reuse existing, Re-record all, Split per service | **Reuse existing cassettes** |

## Corrections Made

No corrections — all initial recommendations accepted except syncer granularity (user chose fine-grained over recommended 3-service grouping).

## Notable Decision

User diverged from recommendation on syncer granularity — chose fine-grained (7-8 services) over the recommended 3-service grouping. This means more service files but each with a tighter focus. Planning should account for the higher file count.
