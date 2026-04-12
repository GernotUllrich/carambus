# Phase 20: Characterization - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-11
**Phase:** 20-characterization
**Areas discussed:** Test organization, PartyMonitor scope, League scope

---

## Test Organization

| Option | Description | Selected |
|--------|-------------|----------|
| One file per model | Clean separation | |
| By behavior cluster | More granular | |
| You decide | Claude picks based on complexity | ✓ |

**User's choice:** Claude's discretion

---

## PartyMonitor Scope

| Option | Description | Selected |
|--------|-------------|----------|
| All AASM + sequencing + lock | Full characterization: all 8 states, do_placement, report_result, rounds | ✓ |
| AASM + report_result only | Focus on state machine and critical lock | |
| You decide | Claude assesses risk | |

**User's choice:** Full characterization

---

## League Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Standings + game plan + scraping | All three major clusters | ✓ |
| Standings + game plan only | Skip scraping (covered by syncers) | |
| You decide | Claude assesses coverage | |

**User's choice:** All three clusters

---

## Claude's Discretion

- Test file organization
- VCR cassette strategy
- Fixture design for PartyMonitor
- Reek baseline measurement
