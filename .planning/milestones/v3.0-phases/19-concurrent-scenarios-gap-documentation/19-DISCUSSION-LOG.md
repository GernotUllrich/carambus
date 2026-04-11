# Phase 19: Concurrent Scenarios & Gap Documentation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-11
**Phase:** 19-concurrent-scenarios-gap-documentation
**Areas discussed:** Concurrency approach, Third session setup, Gap report format

---

## Concurrency Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Sequential perform_now loop | 5-10 transitions in quick succession. Simple, deterministic. | |
| Alternating TM transitions | Alternate TM-A and TM-B rapidly. More realistic. | |
| You decide | Claude picks best approach for race condition scenario | ✓ |

**User's choice:** Claude's discretion

---

## Third Session Setup

| Option | Description | Selected |
|--------|-------------|----------|
| Add fixture | table_monitors(:three) and tables(:three). Consistent with existing pattern. | |
| Create inline | Build third TM/Table in test setup. Avoids fixture bloat. | |
| You decide | Claude picks based on tradeoffs | ✓ |

**User's choice:** Claude's discretion

---

## Gap Report Format

| Option | Description | Selected |
|--------|-------------|----------|
| Clean report with test summary | Tests run, results, deferred fix references | |
| Include known risks | Same + architectural risks even if no failures observed | |
| You decide | Claude picks most useful format | ✓ |

**User's choice:** Claude's discretion

---

## Claude's Discretion

- Rapid-fire simulation approach
- Number of transitions per test
- Third TM fixture approach
- Test file organization
- Gap report content and structure
- Timing/latency metrics in gap report
