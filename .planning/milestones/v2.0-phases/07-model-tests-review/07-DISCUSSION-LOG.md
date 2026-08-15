# Phase 7: Model Tests Review - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-10
**Phase:** 07-model-tests-review
**Areas discussed:** Empty stub handling, Weak assertion fixes, Large file structure, frozen_string_literal sweep

---

## Empty Stub Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Delete them | Remove empty stubs — false confidence, recreate if needed later | ✓ |
| Keep with TODO | Replace scaffold with TODO comment | |
| Add minimal smoke test | One basic test per file | |

**User's choice:** Delete them
**Notes:** 10 files affected. Coverage expansion is a future milestone.

---

## Weak Assertion Fixes

| Option | Description | Selected |
|--------|-------------|----------|
| Fix sole-assertion cases only | Only fix where assert_nothing_raised/assert_not_nil is the ONLY assertion | ✓ |
| Strengthen all flagged | Replace every flagged instance with specific value checks | |
| Conservative — flag only | Document but don't change | |

**User's choice:** Fix sole-assertion cases only
**Notes:** Precondition checks followed by stronger assertions are acceptable.

---

## Large File Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Clean up in place | Fix issues within existing structure, don't split | ✓ |
| Split by concern | Break into smaller files by feature area | |
| Assess case by case | Read each and decide individually | |

**User's choice:** Clean up in place
**Notes:** Files are legitimately large — complex features justify the size.

---

## frozen_string_literal Sweep

| Option | Description | Selected |
|--------|-------------|----------|
| Add during each phase | Add to model tests in Phase 7, service in 8, etc. | ✓ |
| Defer to Phase 10 | Single sweep in final pass | |
| Skip entirely | Style issue, not test quality | |

**User's choice:** Add during each phase
**Notes:** Natural touchpoint since files are being edited anyway.

---

## Claude's Discretion

- Exact post-condition assertions for each weak-assertion fix
- File processing order
- Whether to add frozen_string_literal to files being deleted

## Deferred Ideas

None — discussion stayed within phase scope.
