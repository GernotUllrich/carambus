# Phase 8: Service Tests Review - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-10
**Phase:** 08-service-tests-review
**Areas discussed:** Syncer assertion strategy, ClubCloud client tests, TableMonitor service tests

---

## Syncer Assertion Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Add post-conditions | Keep assert_nothing_raised + add 1-2 outcome assertions | ✓ |
| Leave as characterization | No-crash guarantee is valuable, don't risk VCR breakage | |
| Replace assert_nothing_raised | Remove entirely, pure outcome assertions | |

**User's choice:** Add post-conditions
**Notes:** ~15 cases across 8 files. Keep the no-crash baseline, augment with value checks.

---

## ClubCloud Client Tests

| Option | Description | Selected |
|--------|-------------|----------|
| Strengthen response checks | Check status/body/keys instead of just assert_not_nil | ✓ |
| Minimal fixes only | Remove PATH_MAP test, leave response nil-checks | |
| You decide | Claude assesses each case | |

**User's choice:** Strengthen response checks
**Notes:** Remove useless PATH_MAP constant test.

---

## TableMonitor Service Tests

| Option | Description | Selected |
|--------|-------------|----------|
| Fix sole-assertion cases only | Same as Phase 7 approach | ✓ |
| Thorough review | Strengthen all weak assertions | |
| Leave untouched | v1.0-validated, don't risk regressions | |

**User's choice:** Fix sole-assertion cases only
**Notes:** 3 specific cases across 2 files.

---

## Claude's Discretion

- Exact post-condition assertions for each syncer
- assert_difference vs explicit before/after counts
- Processing order

## Deferred Ideas

None — discussion stayed within phase scope.
