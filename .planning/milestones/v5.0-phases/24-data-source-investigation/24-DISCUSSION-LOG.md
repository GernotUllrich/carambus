# Phase 24: Data Source Investigation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-12
**Phase:** 24-Data Source Investigation
**Areas discussed:** Investigation method, Findings document format, Go/no-go criteria, Probing depth

---

## Investigation Method

| Option | Description | Selected |
|--------|-------------|----------|
| Ruby probe scripts | Write throwaway Ruby scripts using Net::HTTP + Nokogiri to systematically probe endpoints | |
| Manual browser + document | Open browser dev tools, inspect Network tab, manually document findings | |
| You decide | Claude picks the best approach per source | ✓ |

**User's choice:** You decide
**Notes:** Claude has discretion to pick the best investigation method per source

---

## Findings Document Format

| Option | Description | Selected |
|--------|-------------|----------|
| Structured comparison | Matrix: Source x Data Type with availability, format, reliability per cell | |
| Per-source deep dive | One section per source with full technical details, sample responses, and verdict | ✓ |
| Decision-focused | Skip raw details — just go/no-go decisions with evidence | |

**User's choice:** Per-source deep dive
**Notes:** None

---

## Go/No-Go Criteria

| Option | Description | Selected |
|--------|-------------|----------|
| Structured + complete | Must provide structured data AND cover >=80% of current UMB scraping | |
| Structured is enough | If it returns structured data at all, build an adapter — even subset | ✓ |
| Better than HTML | Any source more reliable than current HTML scraping | |

**User's choice:** Structured is enough
**Notes:** Even partial structured data is worth building an adapter for; fill gaps from UMB HTML

---

## Probing Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Discovery + samples | Find endpoints, document format, get 2-3 sample responses | |
| Full characterization | Discovery + pagination, rate limits, auth, error responses, data freshness | |
| Existence check only | Just confirm: structured endpoint exists or not? Leave deep analysis to Phase 25+ | ✓ |

**User's choice:** Existence check only
**Notes:** 1-2 sample responses where endpoint found, but no exhaustive testing

---

## Claude's Discretion

- Investigation method choice per source
- Order of source investigation
- Whether to use WebFetch or throwaway scripts
- How to handle authenticated sources
