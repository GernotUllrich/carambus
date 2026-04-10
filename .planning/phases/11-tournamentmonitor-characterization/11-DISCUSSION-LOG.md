# Phase 11: TournamentMonitor Characterization - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-10
**Phase:** 11-tournamentmonitor-characterization
**Areas discussed:** Test scope strategy, Test organization, ApiProtector verification, Reek baseline scope

---

## Test Scope Strategy

### Tournament Plan Types
| Option | Description | Selected |
|--------|-------------|----------|
| T04 + T06 + KO (Recommended) | Round-robin, with-finals, and knockout — covers the three main flow paths | ✓ |
| T04 + T06 only | KO already has 14 tests — focus on untested paths | |
| All plan types in DB | Exhaustive coverage of every TournamentPlan variant | |

**User's choice:** T04 + T06 + KO
**Notes:** User specifically requested T04 ("jeder gegen jeden") and T06 ("mit Finalrunde") as key scenarios.

### Critical Paths
| Option | Description | Selected |
|--------|-------------|----------|
| All critical paths | AASM, populate_tables, distribution, result pipeline, reset — for each plan type | ✓ |
| Focus by plan type | Different paths per plan type | |
| You decide | Claude picks highest-value paths | |

**User's choice:** All critical paths for each plan type.

### Test Data Setup
| Option | Description | Selected |
|--------|-------------|----------|
| Programmatic helpers | Create helpers similar to KoTournamentTestHelper | |
| Fixture plans from DB | Export real T04/T06 plans from production DB as fixtures | ✓ |
| Both approaches | Fixtures for plans, helpers for tournaments | |

**User's choice:** Fixture plans from DB — real-world data.

---

## Test Organization

### File Location
| Option | Description | Selected |
|--------|-------------|----------|
| test/characterization/ | Follow v1.0 convention | |
| test/models/ | Keep alongside existing KO test | ✓ |
| Split by concern | Separate files per concern area | |

**User's choice:** test/models/ — all TM tests in one place.

### File Organization
| Option | Description | Selected |
|--------|-------------|----------|
| By plan type (Recommended) | tournament_monitor_t04_test.rb, tournament_monitor_t06_test.rb | ✓ |
| By concern | tournament_monitor_aasm_test.rb, etc. | |
| Single file | One large char test file | |

**User's choice:** By plan type.

---

## ApiProtector Verification

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit save test (Recommended) | Create local TM, save, assert persisted? | ✓ |
| Assert in setup | Add assertion in every TM test setup | |
| You decide | Claude picks approach | |

**User's choice:** Explicit save test.

---

## Reek Baseline Scope

| Option | Description | Selected |
|--------|-------------|----------|
| All 3 files (Recommended) | Model + both lib modules — full 2099-line surface | ✓ |
| Model only | Just tournament_monitor.rb (499 lines) | |
| Skip Reek baseline | Focus on tests instead | |

**User's choice:** All 3 files.

---

## Claude's Discretion

- Test method grouping within files
- Specific AASM transitions to prioritize per plan type
- Shared test helpers across plan-type files
- cattr_accessor teardown strategy
