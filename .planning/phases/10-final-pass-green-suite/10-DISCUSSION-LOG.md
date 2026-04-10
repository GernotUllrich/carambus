# Phase 10: Final Pass & Green Suite - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-10
**Phase:** 10-final-pass-green-suite
**Areas discussed:** Green suite strategy, Skip resolution, ApiProtector TODO

---

## Green Suite Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Fix everything possible | Attempt to resolve all 106 failures/errors | ✓ |
| Fix fixture issues only | Add missing fixtures, leave complex failures | |
| Document and accept | Define 'green' as no new failures | |

**User's choice:** Fix everything possible

---

## Skip Resolution

| Option | Description | Selected |
|--------|-------------|----------|
| Try to record cassettes | Use NBV dev credentials to record VCR cassettes | ✓ |
| Accept with documentation | Document as legitimate skips per STANDARDS.md | |

**User's choice:** Try to record cassettes

---

## ApiProtector TODO

| Option | Description | Selected |
|--------|-------------|----------|
| Fix now | Add ApiProtectorTestOverride to test_helper.rb | ✓ |
| Defer | Document as known issue | |

**User's choice:** Fix now

---

## Claude's Discretion

- Fixture data values, PG violation fix approach, controller auth setup, VCR recording, fix order

## Deferred Ideas

None — final phase.
