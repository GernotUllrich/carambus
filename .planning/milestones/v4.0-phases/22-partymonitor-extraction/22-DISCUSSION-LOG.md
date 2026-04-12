# Phase 22: PartyMonitor Extraction - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-11
**Phase:** 22-partymonitor-extraction
**Areas discussed:** Extraction scope & ordering, Service style & naming, Result pipeline complexity, Placement & init grouping

---

## Extraction Scope & Ordering

| Option | Description | Selected |
|--------|-------------|----------|
| Result processing + placement | ResultProcessor (~281 LOC) + TablePopulator (~123 LOC). ~404 lines, ~67% reduction. | ✓ |
| Result processing only | ~281 LOC, ~46% reduction. Defer placement. | |
| Everything extractable | ~425 lines, ~70% reduction including data lookups. | |

**User's choice:** Result processing + placement (Recommended)

### Ordering Sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Easiest first | Placement+init first, then result processing. | ✓ |
| Biggest impact first | Result processing first (~281 LOC). | |

**User's choice:** Easiest first (Recommended)

---

## Service Style & Naming

| Option | Description | Selected |
|--------|-------------|----------|
| PORO like TournamentMonitor | Plain Ruby objects, initialize(party_monitor), multiple public methods. | ✓ |
| ApplicationService like League | Inherit ApplicationService, .call(kwargs) pattern. | |
| Mixed | ResultProcessor as ApplicationService, Placement as PORO. | |

**User's choice:** PORO like TournamentMonitor (Recommended)

### Namespace Sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| PartyMonitor:: namespace | app/services/party_monitor/. Matches TournamentMonitor:: pattern. | ✓ |
| Flat naming | app/services/party_monitor_result_processor.rb. | |

**User's choice:** PartyMonitor:: namespace (Recommended)

---

## Result Pipeline Complexity

| Option | Description | Selected |
|--------|-------------|----------|
| Lock stays in model | Model keeps with_lock + AASM events, delegates data work to service. | ✓ |
| Lock moves to service | Service owns entire flow including lock. | |
| Split lock and processing | Model acquires lock, calls service, fires events based on return. | |

**User's choice:** Lock stays in model (Recommended)

### AASM Sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Stay in model | All AASM transitions in PartyMonitor. Services never fire events. | ✓ |
| Service triggers events | Service calls party_monitor.fire_event! for state changes. | |

**User's choice:** Stay in model (Recommended)

---

## Placement & Init Grouping

| Option | Description | Selected |
|--------|-------------|----------|
| One service: TablePopulator | do_placement + initialize_table_monitors in one class. | ✓ |
| Two separate services | GamePlacer + TableInitializer. | |
| Fold init into ResultProcessor | initialize_table_monitors goes to ResultProcessor. | |

**User's choice:** One service: TablePopulator (Recommended)

---

## Claude's Discretion

- Internal method decomposition within services
- Test file organization
- Missing helper method implementation strategy
- Instance variable state handling during extraction

## Deferred Ideas

None — discussion stayed within phase scope.
