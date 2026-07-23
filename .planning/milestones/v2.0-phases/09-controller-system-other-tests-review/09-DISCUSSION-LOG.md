# Phase 9: Controller, System & Other Tests Review - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-10
**Phase:** 09-controller-system-other-tests-review
**Areas discussed:** Targeted fixes, Characterization tests, Scope approach

---

## Targeted Fixes

| Option | Description | Selected |
|--------|-------------|----------|
| Fix all 6 | Delete optimistic_updates, fix assert true, fix helper structure, strengthen source_handler, replace CSRF regex, remove sleep | ✓ |
| Fix critical only | Only delete and fix assert true | |
| Assess each individually | Ask about each one | |

**User's choice:** Fix all 6

---

## Characterization Tests

| Option | Description | Selected |
|--------|-------------|----------|
| Leave as-is | Exempt per STANDARDS.md, only add frozen_string_literal if missing | ✓ |
| Light fixes | Fix 2 weak assertions in region_cc_char_test.rb | |

**User's choice:** Leave as-is

---

## Scope Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Batch sweep + targeted fixes | One plan for bulk frozen_string_literal, one for 6 logic fixes | ✓ |
| Per-category plans | Separate plans for controllers, system, other | |

**User's choice:** Batch sweep + targeted fixes

---

## Claude's Discretion

- CSRF replacement approach, assert true fix-or-delete, Capybara wait mechanism, helper test restructuring

## Deferred Ideas

None — discussion stayed within phase scope.
