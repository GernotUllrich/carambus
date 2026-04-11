# Phase 18: Core Isolation Tests - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-11
**Phase:** 18-core-isolation-tests
**Areas discussed:** Isolation test structure, score:update dispatch testing, console.warn capture

---

## Isolation Test Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Single test file | One file with test methods for each path. Shared setup, less duplication. | |
| One file per path | Separate files per path. More isolated but duplicated setup. | |
| You decide | Claude picks best organization | ✓ |

**User's choice:** Claude's discretion

---

## Positive/Negative Assertion Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| DOM unchanged check | Assert DOM element text hasn't changed after other table's broadcast | |
| Console.warn + DOM | Assert both: DOM unchanged AND console.warn fired | |
| You decide | Claude picks based on Selenium reliability | ✓ |

**User's choice:** Claude's discretion

---

## score:update Dispatch Testing

| Option | Description | Selected |
|--------|-------------|----------|
| DOM side-effect check | Check DOM elements didn't change in other session. Indirect but Capybara-testable. | |
| Console log capture | Capture console output to verify event filtered. More direct proof. | |
| You decide | Claude picks most reliable approach | ✓ |

**User's choice:** Claude's discretion

---

## Console.warn Capture (ISOL-04)

| Option | Description | Selected |
|--------|-------------|----------|
| Selenium logs API | Standard Selenium API, needs Chrome logging prefs | |
| DOM marker | Modify JS to write rejection info to hidden DOM element | |
| You decide | Claude picks most reliable approach | ✓ |

**User's choice:** Claude's discretion

---

## Claude's Discretion

- Test file organization
- Positive/negative assertion strategy
- score:update dispatch verification approach
- console.warn capture mechanism
- AASM transitions for different operation types
- Fixture setup sharing
- tournament_scores context coverage
