---
status: complete
phase: 18-core-isolation-tests
source: [18-01-SUMMARY.md, 18-02-SUMMARY.md]
started: 2026-04-11T18:05:00Z
updated: 2026-04-11T18:10:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Morph path isolation (ISOL-01)
expected: Two-session test passes: Scoreboard A DOM unchanged when TM-B state changes, Scoreboard B updates to "Frei". 7 assertions, 0 failures.
result: pass

### 2. score:update dispatch isolation (ISOL-02)
expected: Two-session test passes: score:update dispatch events correctly filtered per-table. JS marker approach verifies events arrive at correct session.
result: pass

### 3. table_scores overview isolation (ISOL-03)
expected: table_scores overview page rejects full_screen broadcasts, accepts table_scores broadcasts. Per-table state correct.
result: pass

### 4. Console.warn filter proof (ISOL-04)
expected: `window._mixupPreventedCount > 0` proves the JS filter ran and emitted console.warn on rejected broadcasts (combined with ISOL-01 test).
result: pass

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
